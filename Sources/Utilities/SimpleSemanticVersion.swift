//
//  SimpleSemanticVersion.swift
//  ScaleCloudRenew
//
//  Simple semantic version parser to replace the problematic SemanticVersion package
//  that has module name collision issues with BUILD_LIBRARY_FOR_DISTRIBUTION enabled.
//

import Foundation

/// Simple semantic version structure supporting major.minor.patch[-prerelease][+build] format
public struct SimpleSemanticVersion: Comparable, Equatable, Hashable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let preRelease: String?
    public let build: String?
    
    /// Initialize from a semantic version string (e.g., "1.2.3", "1.2.3-beta", "1.2.3-beta+123")
    public init?(_ versionString: String) {
        // Split on + for build metadata
        let buildComponents = versionString.split(separator: "+", maxSplits: 1)
        let versionAndPreRelease = String(buildComponents[0])
        self.build = buildComponents.count > 1 ? String(buildComponents[1]) : nil
        
        // Split on - for pre-release
        let preReleaseComponents = versionAndPreRelease.split(separator: "-", maxSplits: 1)
        let versionPart = String(preReleaseComponents[0])
        self.preRelease = preReleaseComponents.count > 1 ? String(preReleaseComponents[1]) : nil
        
        // Parse major.minor.patch
        let versionNumbers = versionPart.split(separator: ".").compactMap { Int($0) }
        guard versionNumbers.count >= 3 else { return nil }
        
        self.major = versionNumbers[0]
        self.minor = versionNumbers[1]
        self.patch = versionNumbers[2]
    }
    
    /// Initialize with explicit components
    public init(major: Int, minor: Int, patch: Int, preRelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.build = build
    }
    
    // MARK: - Comparable
    
    public static func < (lhs: SimpleSemanticVersion, rhs: SimpleSemanticVersion) -> Bool {
        // Compare major.minor.patch numerically
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        
        // Per semver spec: stable version (no prerelease) > any prerelease version
        // e.g., 1.0.0 > 1.0.0-beta
        if lhs.preRelease == nil && rhs.preRelease != nil { return false }
        if lhs.preRelease != nil && rhs.preRelease == nil { return true }
        
        // Both have prerelease or both don't - compare lexicographically
        if let lhsPre = lhs.preRelease, let rhsPre = rhs.preRelease {
            if lhsPre != rhsPre { return lhsPre < rhsPre }
        }
        
        // Build metadata doesn't affect precedence per semver spec, but compare anyway
        if let lhsBuild = lhs.build, let rhsBuild = rhs.build {
            return lhsBuild < rhsBuild
        }
        
        return false
    }
    
    public static func == (lhs: SimpleSemanticVersion, rhs: SimpleSemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.preRelease == rhs.preRelease &&
               lhs.build == rhs.build
    }
}

/// Compatibility typealias for existing code
public typealias SemanticVersion = SimpleSemanticVersion
