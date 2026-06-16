//
//  DebuggerUtils.swift
//  ScaleCloudRenew
//
//  Utilities for detecting debugger attachment
//

import Foundation

/// Utilities for detecting debugger connection
public enum DebuggerUtils {
    
    /// Check if a debugger is currently attached to this process
    /// Returns true if running under Xcode debugger, lldb, or debugserver
    /// Uses sysctl with P_TRACED flag to detect ptrace attachment
    public static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else {
            print("[DebuggerUtils] sysctl failed with error: \(errno)")
            return false
        }
        
        // P_TRACED flag indicates process is being traced by debugger
        let isTraced = (info.kp_proc.p_flag & P_TRACED) != 0
        
        print("[DebuggerUtils] Debugger attached: \(isTraced)")
        return isTraced
    }
}
