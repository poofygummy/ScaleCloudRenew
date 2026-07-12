//
//  SecureEnclaveManager.swift
//  ScaleCloudRenew
//
//  Secure Enclave key generation and ECIES decryption
//

import Foundation
import Security

/// Manages Secure Enclave cryptographic operations for credential handoff
public enum SecureEnclaveManager {
    
    // MARK: - Keychain label for persisted injection keypair
    private static let injectionKeyLabel = "com.scalecloud.injection.eckey"

    // MARK: - Key Generation

    /* generateKeyPair() replaced by loadOrGenerateKeyPair() for the two-phase injection protocol.
       Kept here for reference — it created a transient (non-persistent) keypair.
    public static func generateKeyPair() throws -> (publicKeyBytes: Data, privateKeyRef: SecKey) {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: false,
                kSecAttrAccessControl: try createAccessControl()
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SecureEnclaveError.keyGenerationFailed(error?.takeRetainedValue() as Error?)
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExtractionFailed
        }
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw SecureEnclaveError.publicKeyExportFailed(error?.takeRetainedValue() as Error?)
        }
        print("[SecureEnclave] Generated key pair: public key \(publicKeyData.count) bytes")
        return (publicKeyBytes: publicKeyData, privateKeyRef: privateKey)
    }
    */

    // MARK: - Persistent keypair for two-phase injection protocol

    /// Load the persisted injection keypair from the Keychain, or generate and persist a new one.
    /// Phase 1: generate + persist, advertise public key, block until iloader kills the process.
    /// Phase 2: load the same private key to decrypt the payload delivered via launch args.
    public static func loadOrGenerateKeyPair() throws -> (publicKeyBytes: Data, privateKeyRef: SecKey) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrLabel: injectionKeyLabel as CFString,
            kSecReturnRef: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let privateKey = item as! SecKey? {
            guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
                throw SecureEnclaveError.publicKeyExtractionFailed
            }
            var cfError: Unmanaged<CFError>?
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &cfError) as Data? else {
                throw SecureEnclaveError.publicKeyExportFailed(cfError?.takeRetainedValue() as Error?)
            }
            print("[SecureEnclave] Loaded persisted injection keypair: public key \(publicKeyData.count) bytes")
            return (publicKeyBytes: publicKeyData, privateKeyRef: privateKey)
        }

        // None found — generate and persist
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrLabel: injectionKeyLabel as CFString,
                kSecAttrAccessControl: try createAccessControl()
            ] as [CFString: Any]
        ]
        var cfError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &cfError) else {
            throw SecureEnclaveError.keyGenerationFailed(cfError?.takeRetainedValue() as Error?)
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExtractionFailed
        }
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &cfError) as Data? else {
            throw SecureEnclaveError.publicKeyExportFailed(cfError?.takeRetainedValue() as Error?)
        }
        print("[SecureEnclave] Generated and persisted injection keypair: public key \(publicKeyData.count) bytes")
        return (publicKeyBytes: publicKeyData, privateKeyRef: privateKey)
    }

    /// Delete the persisted injection keypair. Called after Phase 2 completes successfully.
    public static func deleteStoredKeyPair() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrLabel: injectionKeyLabel as CFString
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("[SecureEnclave] Deleted persisted injection keypair")
        } else {
            print("[SecureEnclave] Warning: failed to delete injection keypair, status=\(status)")
        }
    }
    
    // MARK: - Decryption
    
    /// Decrypt data using Secure Enclave private key with ECIES
    /// The decryption happens inside the Secure Enclave chip - private key never exposed
    /// - Parameters:
    ///   - encryptedData: Encrypted blob from computer (ECIES ciphertext)
    ///   - privateKey: Reference to Secure Enclave private key
    /// - Returns: Decrypted plaintext data
    /// - Throws: SecureEnclaveError if decryption fails
    public static func decrypt(encryptedData: Data, using privateKey: SecKey) throws -> Data {
        // Use ECIES with X963 SHA256 key derivation and AES-GCM encryption
        let algorithm = SecKeyAlgorithm.eciesEncryptionStandardVariableIVX963SHA256AESGCM
        
        // Verify algorithm is supported
        guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            throw SecureEnclaveError.algorithmNotSupported
        }
        
        var error: Unmanaged<CFError>?
        guard let plaintext = SecKeyCreateDecryptedData(privateKey, algorithm, encryptedData as CFData, &error) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw SecureEnclaveError.decryptionFailed(error as Error)
            }
            throw SecureEnclaveError.decryptionFailed(nil)
        }
        
        print("[SecureEnclave] Decrypted \(encryptedData.count) bytes → \(plaintext.count) bytes")
        return plaintext
    }
    
    // MARK: - Access Control
    
    /// Create access control flags for Secure Enclave key
    /// Allows key usage without biometric/passcode prompt (device presence only)
    private static func createAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleAfterFirstUnlock,  // Key available after device first unlocked
            [],  // No additional constraints (no biometric/passcode required)
            &error
        ) else {
            if let error = error?.takeRetainedValue() {
                throw SecureEnclaveError.accessControlCreationFailed(error as Error)
            }
            throw SecureEnclaveError.accessControlCreationFailed(nil)
        }
        return access
    }
}

// MARK: - Error Types

public enum SecureEnclaveError: LocalizedError {
    case keyGenerationFailed(Error?)
    case publicKeyExtractionFailed
    case publicKeyExportFailed(Error?)
    case algorithmNotSupported
    case decryptionFailed(Error?)
    case accessControlCreationFailed(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let error):
            return "Failed to generate Secure Enclave key pair" + (error.map { ": \($0.localizedDescription)" } ?? "")
        case .publicKeyExtractionFailed:
            return "Failed to extract public key from private key"
        case .publicKeyExportFailed(let error):
            return "Failed to export public key bytes" + (error.map { ": \($0.localizedDescription)" } ?? "")
        case .algorithmNotSupported:
            return "ECIES algorithm not supported on this device"
        case .decryptionFailed(let error):
            return "Failed to decrypt data" + (error.map { ": \($0.localizedDescription)" } ?? "")
        case .accessControlCreationFailed(let error):
            return "Failed to create access control" + (error.map { ": \($0.localizedDescription)" } ?? "")
        }
    }
}
