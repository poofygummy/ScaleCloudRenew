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
    
    // MARK: - Key Generation
    
    /// Generate an ECIES key pair in the Secure Enclave
    /// Returns the public key bytes (for transmission to computer) and a reference to the private key (stays in Secure Enclave)
    /// - Returns: Tuple of (publicKeyBytes: Data, privateKeyRef: SecKey)
    /// - Throws: SecureEnclaveError if key generation or export fails
    public static func generateKeyPair() throws -> (publicKeyBytes: Data, privateKeyRef: SecKey) {
        // Define key attributes: P-256 elliptic curve, stored in Secure Enclave
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: false,  // Transient key - never persisted
                kSecAttrAccessControl: try createAccessControl()
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw SecureEnclaveError.keyGenerationFailed(error as Error)
            }
            throw SecureEnclaveError.keyGenerationFailed(nil)
        }
        
        // Extract public key from private key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExtractionFailed
        }
        
        // Export public key as raw bytes (X9.63 format)
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw SecureEnclaveError.publicKeyExportFailed(error as Error)
            }
            throw SecureEnclaveError.publicKeyExportFailed(nil)
        }
        
        print("[SecureEnclave] Generated key pair: public key \(publicKeyData.count) bytes")
        return (publicKeyBytes: publicKeyData, privateKeyRef: privateKey)
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
