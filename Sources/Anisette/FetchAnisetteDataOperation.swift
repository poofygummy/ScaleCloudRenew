//
//  FetchAnisetteDataOperation.swift
//  AltStore
//
//  Created by Riley Testut on 1/7/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import CommonCrypto
import Starscream
import ScaleCloudKit
import ScaleCloudSign

class ANISETTE_VERBOSITY: Operation {} // dummy tag iface

@objc(FetchAnisetteDataOperation)
final class FetchAnisetteDataOperation: ResultOperation<ALTAnisetteData>, WebSocketDelegate
{
    let context: OperationContext
    var socket: WebSocket!
    // Fallback URLSessionWebSocketTask (proxy-aware) used when Starscream path doesn't connect
    var urlSessionWebSocketTask: URLSessionWebSocketTask?
    
    var url: URL?
    var startProvisioningURL: URL?
    var endProvisioningURL: URL?
    
    var clientInfo: String?
    var userAgent: String?
    
    var mdLu: String?
    var deviceId: String?
    
    init(context: OperationContext)
    {
        self.context = context
    }
    
    override func main()
    {
        super.main()
        
        if let error = self.context.error
        {
            self.finish(.failure(error))
            return
        }
        
        // UI removed - headless operation
        
        getAnisetteServerUrl(){ url, error in
            guard let urlString = url else {
                self.finish(.failure(error!))
                return
            }

            // set as preferred
            UserDefaults.standard.menuAnisetteURL = urlString
            let url = URL(string: urlString)
            self.url = url
            self.printOut("Anisette URL: \(self.url!.absoluteString)")

            if let identifier = Keychain.shared.identifier,
               let adiPb = Keychain.shared.adiPb {
                nkLog(debug: "[Signing] Anisette: have cached identifier + adi.pb, going V3")
                self.fetchAnisetteV3(identifier, adiPb)
            } else {
                nkLog(debug: "[Signing] Anisette: no cached adi.pb, need provisioning")
                self.provision()
            }
        }
    }
    

    func getAnisetteServerUrl(completion: @escaping (String?, Error?) -> Void) {
        var serverUrls = UserDefaults.standard.menuAnisetteServersList
        let currentServer = UserDefaults.standard.menuAnisetteURL

        nkLog(debug: "[Signing] Anisette server list (\(serverUrls.count)): \(serverUrls.joined(separator: ", "))")
        nkLog(debug: "[Signing] Current anisette URL: \(currentServer.isEmpty ? "(none)" : currentServer)")

        if serverUrls.isEmpty {
            nkLog(error: "[Signing] menuAnisetteServersList is empty — anisette URL was never saved by setup")
        }

        // Prioritize the current server by moving it to the top of the list
        if let currentServerIndex = serverUrls.firstIndex(of: currentServer) {
            serverUrls.remove(at: currentServerIndex)
            serverUrls.insert(currentServer, at: 0)
        }
        
        tryNextServer(from: serverUrls, currentIndex: 0, completion: completion)
    }
    
    private func logMessage(_ message: String){
        print("[Anisette] \(message)")
    }

    private func tryNextServer(from serverUrls: [String], currentIndex: Int, completion: @escaping (String?, Error?) -> Void) {
        // Check if all URLs have been exhausted
        guard currentIndex < serverUrls.count else {
            nkLog(error: "[Signing] Anisette: all servers exhausted, no valid server found")
            let error = NSError(domain: "AnisetteError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No valid server found."])
            completion(nil, error)
            return
        }

        let currentServerUrlString = serverUrls[currentIndex]
        guard let url = URL(string: currentServerUrlString) else {
            nkLog(error: "[Signing] Anisette: skipping invalid URL: \(currentServerUrlString)")
            tryNextServer(from: serverUrls, currentIndex: currentIndex + 1, completion: completion)
            return
        }

        // Attempt to ping the current URL
        nkLog(debug: "[Signing] Anisette: pinging server \(url.absoluteString)...")
        pingServer(url) { success, error in
            if success {
                nkLog(debug: "[Signing] Anisette: server reachable \(url.absoluteString)")
                completion(url.absoluteString, nil)
            } else {
                nkLog(error: "[Signing] Anisette: server unreachable \(url.absoluteString): \(error?.localizedDescription ?? "unknown")")
                self.tryNextServer(from: serverUrls, currentIndex: currentIndex + 1, completion: completion)
            }
        }
    }

    func pingServer(_ url: URL, completion: @escaping (Bool, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10 // Timeout after 10 seconds
        let session = createProxySession()
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(false, error)
                return
            }
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode
            
            guard let statusCode = statusCode,
                  (200...299).contains(statusCode) else {
                let serverError = OperationError.anisetteV3Error(message: "Server unreachable or invalid response: \(String(describing: statusCode ?? nil))")
                completion(false, serverError)
                return
            }
            
            completion(true, nil)
        }
        
        task.resume()
    }
    
    
    // MARK: - COMMON
    
    func extractAnisetteData(_ data: Data, _ response: HTTPURLResponse?, v3: Bool) throws {
        // make sure this JSON is in the format we expect
        // convert data to json
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
            if v3 {
                if json["result"] == "GetHeadersError" {
                    let message = json["message"]
                    self.printOut("Error getting V3 headers: \(message ?? "no message")")
                    if let message = message,
                       message.contains("-45061") {
                        self.printOut("Error message contains -45061 (not provisioned), resetting adi.pb and retrying")
                        Keychain.shared.adiPb = nil
                        return provision()
                    } else { throw OperationError.anisetteV3Error(message: message ?? "Unknown error") }
                }
            }
            
            // try to read out a dictionary
            // for some reason serial number isn't needed but it doesn't work unless it has a value
            var formattedJSON: [String: String] = ["deviceSerialNumber": "0"]
            if let machineID = json["X-Apple-I-MD-M"] { formattedJSON["machineID"] = machineID }
            if let oneTimePassword = json["X-Apple-I-MD"] { formattedJSON["oneTimePassword"] = oneTimePassword }
            if let routingInfo = json["X-Apple-I-MD-RINFO"] { formattedJSON["routingInfo"] = routingInfo }
            
            if v3 {
                formattedJSON["deviceDescription"] = self.clientInfo!
                formattedJSON["localUserID"] = self.mdLu!
                formattedJSON["deviceUniqueIdentifier"] = self.deviceId!
                
                // Generate date stuff on client
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                let dateString = formatter.string(from: Date())
                formattedJSON["date"] = dateString
                formattedJSON["locale"] = Locale.current.identifier
                formattedJSON["timeZone"] = TimeZone.current.abbreviation()
            } else {
                if let deviceDescription = json["X-MMe-Client-Info"] { formattedJSON["deviceDescription"] = deviceDescription }
                if let localUserID = json["X-Apple-I-MD-LU"] { formattedJSON["localUserID"] = localUserID }
                if let deviceUniqueIdentifier = json["X-Mme-Device-Id"] { formattedJSON["deviceUniqueIdentifier"] = deviceUniqueIdentifier }
                
                if let date = json["X-Apple-I-Client-Time"] { formattedJSON["date"] = date }
                if let locale = json["X-Apple-Locale"] { formattedJSON["locale"] = locale }
                if let timeZone = json["X-Apple-I-TimeZone"] { formattedJSON["timeZone"] = timeZone }
            }
            
            if let response = response,
               let version = response.value(forHTTPHeaderField: "Implementation-Version") {
                self.printOut("Implementation-Version: \(version)")
            } else { self.printOut("No Implementation-Version header") }
            
            self.printOut("Anisette used: \(formattedJSON)")
            self.printOut("Original JSON: \(json)")
            if let anisette = ALTAnisetteData(json: formattedJSON) {
                nkLog(debug: "[Signing] Anisette: data valid, finishing operation")
                self.finish(.success(anisette))
            } else {
                nkLog(error: "[Signing] Anisette: data is invalid (missing required fields)")
                if v3 {
                    throw OperationError.anisetteV3Error(message: "Invalid anisette (the returned data may not have all the required fields)")
                } else {
                    throw OperationError.anisetteV1Error(message: "Invalid anisette (the returned data may not have all the required fields)")
                }
            }
        } else {
            if v3 {
                throw OperationError.anisetteV3Error(message: "Invalid anisette (the returned data may not be in JSON)")
            } else {
                throw OperationError.anisetteV1Error(message: "Invalid anisette (the returned data may not be in JSON)")
            }
        }
    }
    
    // MARK: - V1
    
    func handleV1() {
        self.printOut("Server is V1")
        
        if UserDefaults.shared.trustedServerURL == AnisetteManager.currentURLString {
            self.printOut("Server has already been trusted, fetching anisette")
            return self.fetchAnisetteV1()
        }
        
        self.printOut("WARNING: Outdated V1 server - auto-accepting")
        UserDefaults.shared.trustedServerURL = AnisetteManager.currentURLString
        self.fetchAnisetteV1()
    }
    
    func fetchAnisetteV1() {
        self.printOut("Fetching anisette V1")
        let session = createProxySession()
        session.dataTask(with: self.url!) { data, response, error in
            do {
                guard let data = data, error == nil else { throw OperationError.anisetteV1Error(message: "Unable to fetch data\(error != nil ? " (\(error!.localizedDescription))" : "")") }
                
                try self.extractAnisetteData(data, response as? HTTPURLResponse, v3: false)
            } catch let error as NSError {
                self.printOut("Failed to load: \(error.localizedDescription)")
                self.finish(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - V3: PROVISIONING
    
    func provision() {
        nkLog(debug: "[Signing] Anisette: starting provisioning (no cached adi.pb)")
        fetchClientInfo {
            nkLog(debug: "[Signing] Anisette: fetching provisioning URLs from gsa.apple.com")
            var request = self.buildAppleRequest(url: URL(string: "https://gsa.apple.com/grandslam/GsService2/lookup")!)
            request.httpMethod = "GET"
            let session = self.createProxySession()
            session.dataTask(with: request) { data, response, error in
                if let networkError = error {
                    nkLog(error: "[Signing] Anisette: provisioning URL fetch error: \(networkError.localizedDescription)")
                    self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid URLs", message: networkError.localizedDescription)))
                    return
                }
                if let data = data,
                   let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                   let startProvisioningString = plist["urls"]?["midStartProvisioning"] as? String,
                   let startProvisioningURL = URL(string: startProvisioningString),
                   let endProvisioningString = plist["urls"]?["midFinishProvisioning"] as? String,
                   let endProvisioningURL = URL(string: endProvisioningString) {
                    self.startProvisioningURL = startProvisioningURL
                    self.endProvisioningURL = endProvisioningURL
                    nkLog(debug: "[Signing] Anisette: got provisioning URLs, starting WS session")
                    self.startProvisioningSession()
                } else {
                    let body = String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8"
                    nkLog(error: "[Signing] Anisette: Apple gave invalid provisioning URLs. Response: \(body)")
                    self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid URLs. Please try again later", message: nil)))
                }
            }.resume()
        }
    }
    
    func startProvisioningSession() {
        let provisioningSessionURL = self.url!.appendingPathComponent("v3").appendingPathComponent("provisioning_session")

        // WebSocket provisioning for Anisette V3 requires ws:// or wss:// scheme.
        var wsComponents = URLComponents(url: provisioningSessionURL, resolvingAgainstBaseURL: false)
        if let scheme = wsComponents?.scheme?.lowercased() {
            switch scheme {
            case "https": wsComponents?.scheme = "wss"
            case "http":  wsComponents?.scheme = "ws"
            default: break
            }
        }

        guard let wsURL = wsComponents?.url else {
            nkLog(error: "[Signing] Anisette: invalid provisioning session URL")
            self.finish(.failure(OperationError.provisioningError(result: "Invalid provisioning session URL", message: nil)))
            return
        }

        nkLog(debug: "[Signing] Anisette: connecting to provisioning session via proxy-aware URLSession WebSocket: \(wsURL.absoluteString)")
        let tsLogs = SCKSession.getTsnetLogs()
        nkLog(debug: "[Signing] Anisette: tsnet logs:\n\(tsLogs)")

        // Use proxy-aware URLSession (goes through Tailscale) instead of raw Starscream WebSocket
        let session = createProxySession()
        var wsRequest = URLRequest(url: wsURL)
        wsRequest.timeoutInterval = 30
        let task = session.webSocketTask(with: wsRequest)
        self.urlSessionWebSocketTask = task
        task.resume()
        receiveNextWebSocketMessage(task: task)
    }

    private func receiveNextWebSocketMessage(task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                let nsError = error as NSError
                // Code 57 = socket not connected (closed cleanly after ProvisioningSuccess)
                if nsError.code == 57 {
                    nkLog(debug: "[Signing] Anisette: WebSocket closed cleanly")
                } else {
                    nkLog(error: "[Signing] Anisette: WebSocket error: \(error.localizedDescription)")
                    self.finish(.failure(OperationError.provisioningError(result: "WebSocket error", message: error.localizedDescription)))
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    nkLog(debug: "[Signing] Anisette: WebSocket received text: \(text)")
                    self.handleWebSocketText(text, send: { [weak task] dict in
                        guard let task = task else { return }
                        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
                        task.send(.string(String(data: data, encoding: .utf8)!)) { err in
                            if let err = err { nkLog(error: "[Signing] Anisette: WebSocket send error: \(err.localizedDescription)") }
                        }
                    }, disconnect: { [weak task] in
                        task?.cancel(with: .normalClosure, reason: nil)
                    })
                    self.receiveNextWebSocketMessage(task: task)
                case .data(let data):
                    nkLog(debug: "[Signing] Anisette: WebSocket received data (\(data.count) bytes), ignoring")
                    self.receiveNextWebSocketMessage(task: task)
                @unknown default:
                    self.receiveNextWebSocketMessage(task: task)
                }
            }
        }
    }

    private func handleWebSocketText(_ string: String, send: @escaping ([String: String]) -> Void, disconnect: @escaping () -> Void) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: []) as? [String: Any],
                  let result = json["result"] as? String else {
                nkLog(error: "[Signing] Anisette: WebSocket message missing result field")
                disconnect()
                self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us a result", message: nil)))
                return
            }
            nkLog(debug: "[Signing] Anisette: WebSocket result=\(result)")
            switch result {
            case "GiveIdentifier":
                send(["identifier": Keychain.shared.identifier!])

            case "GiveStartProvisioningData":
                let body = ["Header": [String: Any](), "Request": [String: Any]()]
                var request = self.buildAppleRequest(url: self.startProvisioningURL!)
                request.httpMethod = "POST"
                request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                let session = self.createProxySession()
                session.dataTask(with: request) { data, response, error in
                    if let data = data,
                       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                       let spim = plist["Response"]?["spim"] as? String {
                        send(["spim": spim])
                    } else {
                        let body = String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8"
                        nkLog(error: "[Signing] Anisette: Apple didn't give valid start provisioning data: \(body)")
                        disconnect()
                        self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid start provisioning data", message: nil)))
                    }
                }.resume()

            case "GiveEndProvisioningData":
                guard let cpim = json["cpim"] as? String else {
                    nkLog(error: "[Signing] Anisette: no cpim in GiveEndProvisioningData")
                    disconnect()
                    self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us a cpim", message: nil)))
                    return
                }
                let body = ["Header": [String: Any](), "Request": ["cpim": cpim]]
                var request = self.buildAppleRequest(url: self.endProvisioningURL!)
                request.httpMethod = "POST"
                request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                let session = self.createProxySession()
                session.dataTask(with: request) { data, response, error in
                    if let data = data,
                       let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                       let ptm = plist["Response"]?["ptm"] as? String,
                       let tk  = plist["Response"]?["tk"]  as? String {
                        send(["ptm": ptm, "tk": tk])
                    } else {
                        let body = String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8"
                        nkLog(error: "[Signing] Anisette: Apple didn't give valid end provisioning data: \(body)")
                        disconnect()
                        self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid end provisioning data", message: nil)))
                    }
                }.resume()

            case "ProvisioningSuccess":
                disconnect()
                guard let adiPb = json["adi_pb"] as? String else {
                    nkLog(error: "[Signing] Anisette: no adi_pb in ProvisioningSuccess")
                    self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us an adi.pb file", message: nil)))
                    return
                }
                nkLog(debug: "[Signing] Anisette: provisioning succeeded, caching adi.pb")
                Keychain.shared.adiPb = adiPb
                self.fetchAnisetteV3(Keychain.shared.identifier!, Keychain.shared.adiPb!)

            default:
                if result.contains("Error") || result.contains("Invalid") || result == "ClosingPerRequest" || result == "Timeout" || result == "TextOnly" {
                    nkLog(error: "[Signing] Anisette: provisioning failed with result: \(result)")
                    disconnect()
                    self.finish(.failure(OperationError.provisioningError(result: result, message: json["message"] as? String)))
                }
            }
        } catch {
            nkLog(error: "[Signing] Anisette: failed to handle WebSocket text: \(error.localizedDescription)")
            disconnect()
            self.finish(.failure(OperationError.provisioningError(result: error.localizedDescription, message: nil)))
        }
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .text(let string):
            nkLog(debug: "[Signing] Anisette: WebSocket received text: \(string)")
            do {
                if let json = try JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: []) as? [String: Any] {
                    guard let result = json["result"] as? String else {
                        nkLog(error: "[Signing] Anisette: WebSocket message missing result field")
                        self.printOut("The server didn't give us a result")
                        client.disconnect(closeCode: 0)
                        self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us a result", message: nil)))
                        return
                    }
                    nkLog(debug: "[Signing] Anisette: WebSocket result=\(result)")
                    self.printOut("Received result: \(result)")
                    switch result {
                    case "GiveIdentifier":
                        self.printOut("Giving identifier")
                        client.json(["identifier": Keychain.shared.identifier!])
                        
                    case "GiveStartProvisioningData":
                        self.printOut("Getting start provisioning data")
                        let body = [
                            "Header": [String: Any](),
                            "Request": [String: Any](),
                        ]
                        var request = self.buildAppleRequest(url: self.startProvisioningURL!)
                        request.httpMethod = "POST"
                        request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                        let session = self.createProxySession()
                        session.dataTask(with: request) { data, response, error in
                            if let data = data,
                               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                               let spim = plist["Response"]?["spim"] as? String {
                                self.printOut("Giving start provisioning data")
                                client.json(["spim": spim])
                            } else {
                                self.printOut("Apple didn't give valid start provisioning data! Got response: \(String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8")")
                                client.disconnect(closeCode: 0)
                                self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid start provisioning data. Please try again later", message: nil)))
                            }
                        }.resume()
                        
                    case "GiveEndProvisioningData":
                        self.printOut("Getting end provisioning data")
                        guard let cpim = json["cpim"] as? String else {
                            self.printOut("The server didn't give us a cpim")
                            client.disconnect(closeCode: 0)
                            self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us a cpim", message: nil)))
                            return
                        }
                        let body = [
                            "Header": [String: Any](),
                            "Request": [
                                "cpim": cpim,
                            ],
                        ]
                        var request = self.buildAppleRequest(url: self.endProvisioningURL!)
                        request.httpMethod = "POST"
                        request.httpBody = try! PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                        let session = self.createProxySession()
                        session.dataTask(with: request) { data, response, error in
                            if let data = data,
                               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? Dictionary<String, Dictionary<String, Any>>,
                               let ptm = plist["Response"]?["ptm"] as? String,
                               let tk = plist["Response"]?["tk"] as? String {
                                self.printOut("Giving end provisioning data")
                                client.json(["ptm": ptm, "tk": tk])
                            } else {
                                self.printOut("Apple didn't give valid end provisioning data! Got response: \(String(data: data ?? Data("nothing".utf8), encoding: .utf8) ?? "not utf8")")
                                client.disconnect(closeCode: 0)
                                self.finish(.failure(OperationError.provisioningError(result: "Apple didn't give valid end provisioning data. Please try again later", message: nil)))
                            }
                        }.resume()
                        
                    case "ProvisioningSuccess":
                        self.printOut("Provisioning succeeded!")
                        client.disconnect(closeCode: 0)
                        guard let adiPb = json["adi_pb"] as? String else {
                            self.printOut("The server didn't give us an adi.pb file")
                            self.finish(.failure(OperationError.provisioningError(result: "The server didn't give us an adi.pb file", message: nil)))
                            return
                        }
                        Keychain.shared.adiPb = adiPb
                        self.fetchAnisetteV3(Keychain.shared.identifier!, Keychain.shared.adiPb!)
                        
                    default:
                        if result.contains("Error") || result.contains("Invalid") || result == "ClosingPerRequest" || result == "Timeout" || result == "TextOnly" {
                            self.printOut("Failing because of \(result)")
                            self.finish(.failure(OperationError.provisioningError(result: result, message: json["message"] as? String)))
                        }
                    }
                }
            } catch let error as NSError {
                self.printOut("Failed to handle text: \(error.localizedDescription)")
                self.finish(.failure(OperationError.provisioningError(result: error.localizedDescription, message: nil)))
            }
            
        case .connected:
            nkLog(debug: "[Signing] Anisette: Starscream WebSocket connected (legacy path)")

        case .disconnected(let string, let code):
            nkLog(debug: "[Signing] Anisette: Starscream WebSocket disconnected: code=\(code) msg=\(string)")

        case .error(let error):
            nkLog(error: "[Signing] Anisette: Starscream WebSocket error: \(String(describing: error))")

        default:
            break
        }
    }
    
    func buildAppleRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(self.clientInfo!, forHTTPHeaderField: "X-Mme-Client-Info")
        request.setValue(self.userAgent!, forHTTPHeaderField: "User-Agent")
        request.setValue("text/x-xml-plist", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        request.setValue(self.mdLu!, forHTTPHeaderField: "X-Apple-I-MD-LU")
        request.setValue(self.deviceId!, forHTTPHeaderField: "X-Mme-Device-Id")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        let dateString = formatter.string(from: Date())
        request.setValue(dateString, forHTTPHeaderField: "X-Apple-I-Client-Time")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "X-Apple-Locale")
        request.setValue(TimeZone.current.abbreviation(), forHTTPHeaderField: "X-Apple-I-TimeZone")
        return request
    }
    
    // MARK: - V3: FETCHING
    
    func fetchClientInfo(_ callback: @escaping () -> Void) {
        if  self.clientInfo != nil &&
                self.userAgent != nil &&
                self.mdLu != nil &&
                self.deviceId != nil &&
                Keychain.shared.identifier != nil {
            nkLog(debug: "[Signing] Anisette: client_info already cached, skipping fetch")
            return callback()
        }
        nkLog(debug: "[Signing] Anisette: fetching client_info from server")
        let clientInfoURL = self.url!.appendingPathComponent("v3").appendingPathComponent("client_info")
        let session = createProxySession()
        session.dataTask(with: clientInfoURL) { data, response, error in
            do {
                                guard let data = data, error == nil else {
                    let errMsg = error?.localizedDescription ?? "no data"
                    nkLog(error: "[Signing] Anisette: client_info fetch failed: \(errMsg)")
                    return self.finish(.failure(OperationError.anisetteV3Error(message: "Couldn't fetch client info. The server may be down (\(errMsg))")))
                }
                
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    if let clientInfo = json["client_info"] {
                        nkLog(debug: "[Signing] Anisette: server is V3")
                        self.clientInfo = clientInfo
                        self.userAgent = json["user_agent"]!
                        
                        if Keychain.shared.identifier == nil {
                            nkLog(debug: "[Signing] Anisette: generating new device identifier")
                            var bytes = [Int8](repeating: 0, count: 16)
                            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
                            
                            if status != errSecSuccess {
                                nkLog(error: "[Signing] Anisette: failed to generate identifier, status: \(status)")
                                return self.finish(.failure(OperationError.provisioningError(result: "Couldn't generate identifier", message: nil)))
                            }
                            
                            Keychain.shared.identifier = Data(bytes: &bytes, count: bytes.count).base64EncodedString()
                        }
                        
                        let decoded = Data(base64Encoded: Keychain.shared.identifier!)!
                        self.mdLu = decoded.sha256().hexEncodedString()
                        let uuid: UUID = decoded.object()
                        self.deviceId = uuid.uuidString.uppercased()
                        nkLog(debug: "[Signing] Anisette: client_info ready, calling back")
                        callback()
                    } else {
                        nkLog(warning: "[Signing] Anisette: no client_info key — falling back to V1")
                        self.handleV1()
                    }
                } else {
                    nkLog(error: "[Signing] Anisette: client_info response is not JSON")
                    self.finish(.failure(OperationError.anisetteV3Error(message: "Couldn't fetch client info. The returned data may not be in JSON")))
                }
            } catch let error as NSError {
                nkLog(error: "[Signing] Anisette: client_info fetch threw: \(error.localizedDescription) — falling back to V1")
                self.handleV1()
            }
        }.resume()
    }
    
    func fetchAnisetteV3(_ identifier: String, _ adiPb: String) {
        nkLog(debug: "[Signing] Anisette: fetchAnisetteV3 called (has cached adi.pb)")
        fetchClientInfo {
            nkLog(debug: "[Signing] Anisette: sending V3 get_headers request")
            var request = URLRequest(url: self.url!.appendingPathComponent("v3").appendingPathComponent("get_headers"))
            request.httpMethod = "POST"
            request.httpBody = try! JSONSerialization.data(withJSONObject: [
                "identifier": identifier,
                "adi_pb": adiPb
            ], options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let session = self.createProxySession()
            session.dataTask(with: request) { data, response, error in
                do {
                    guard let data = data, error == nil else {
                        let errMsg = error?.localizedDescription ?? "no data"
                        nkLog(error: "[Signing] Anisette: V3 get_headers failed: \(errMsg)")
                        throw OperationError.anisetteV3Error(message: "Couldn't fetch anisette: \(errMsg)")
                    }
                    nkLog(debug: "[Signing] Anisette: V3 get_headers response received, extracting data")
                    try self.extractAnisetteData(data, response as? HTTPURLResponse, v3: true)
                } catch let error as NSError {
                    nkLog(error: "[Signing] Anisette: V3 extraction failed: \(error.localizedDescription)")
                    self.finish(.failure(error))
                }
            }.resume()
        }
    }
    
    
    private func printOut(_ text: String?){
        let isInternalLoggingEnabled = OperationsLoggingControl.getFromDatabase(for: ANISETTE_VERBOSITY.self)
        if(isInternalLoggingEnabled){
            // logging enabled, so log it
            text.map{ _ in print(text!) } ?? print()
        }
    }
    
    private func createProxySession() -> URLSession {
        let config = URLSessionConfiguration.default
        // Use shared proxy lifecycle from ScaleCloudKit
        config.connectionProxyDictionary = SCKSession.applyProxySettings()
        let session = URLSession(configuration: config)
        SCKSession.registerSession(session)
        return session
    }
}

extension WebSocketClient {
    func json(_ dictionary: [String: String]) {
        let data = try! JSONSerialization.data(withJSONObject: dictionary, options: [])
        self.write(string: String(data: data, encoding: .utf8)!)
    }
}

extension Data {
    // https://stackoverflow.com/a/25391020
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
    
    // https://stackoverflow.com/a/40089462
    func hexEncodedString() -> String {
        return self.map { String(format: "%02hhX", $0) }.joined()
    }
    
    // https://stackoverflow.com/a/59127761
    func object<T>() -> T { self.withUnsafeBytes { $0.load(as: T.self) } }
}
