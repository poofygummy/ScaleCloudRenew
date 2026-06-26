//
//  OSLog+SideStore.swift
//  SideStore
//
//  Created by Joseph Mattiello on 11/16/22.
//  Copyright © 2022 SideStore. All rights reserved.
//

import Foundation
import OSLog

let customLog = OSLog(subsystem: "org.sidestore.sidestore",
                      category: "ios")


// TODO: Add file,line,function to messages? -- @JoeMatt

/// Error logger convenience method for SideStore logging
/// - Parameters:
///   - message: String or format string
///   - args: optional args for format string
@inlinable
public func ELOG(_ message: StaticString, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ args: CVarArg...) {
    os_log(message, log: customLog, type: .error, args)
}

/// Info logger convenience method for SideStore logging
/// - Parameters:
///   - message: String or format string
///   - args: optional args for format string
@inlinable
public func ILOG(_ message: StaticString, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ args: CVarArg...) {
    os_log(message, log: customLog, type: .info, args)
}

/// Debug logger convenience method for SideStore logging
/// - Parameters:
///   - message: String or format string
///   - args: optional args for format string
@inlinable
public func DLOG(_ message: StaticString, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ args: CVarArg...) {
    os_log(message, log: customLog, type: .debug, args)
}

// mark: Helpers
