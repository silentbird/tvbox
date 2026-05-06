import CommonCrypto
import CryptoKit
import Foundation

/// Crypto helpers shared by WebsiteBundle native spiders.
/// Matches the CryptoJS / Node crypto behavior used inside `cat/index.js`
/// so iOS ports can round-trip bytes exactly.
enum WebsiteBundleCrypto {
    static func md5Hex(_ string: String) -> String {
        md5Hex(Data(string.utf8))
    }

    static func md5Hex(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func md5HexUpper(_ string: String) -> String {
        md5Hex(string).uppercased()
    }

    /// AES-CBC/PKCS7 encryption.
    /// `key` / `iv` are raw bytes exactly as the bundle feeds them in
    /// (`Buffer.from(str)` = UTF-8 bytes of the string).
    static func aesCbcEncrypt(_ plaintext: Data, key: Data, iv: Data) -> Data? {
        aes(operation: CCOperation(kCCEncrypt), mode: .cbc, input: plaintext, key: key, iv: iv)
    }

    static func aesCbcDecrypt(_ cipher: Data, key: Data, iv: Data) -> Data? {
        aes(operation: CCOperation(kCCDecrypt), mode: .cbc, input: cipher, key: key, iv: iv)
    }

    static func aesEcbEncrypt(_ plaintext: Data, key: Data) -> Data? {
        aes(operation: CCOperation(kCCEncrypt), mode: .ecb, input: plaintext, key: key, iv: Data())
    }

    static func aesEcbDecrypt(_ cipher: Data, key: Data) -> Data? {
        aes(operation: CCOperation(kCCDecrypt), mode: .ecb, input: cipher, key: key, iv: Data())
    }

    enum AESMode {
        case cbc, ecb
    }

    private static func aes(
        operation: CCOperation,
        mode: AESMode,
        input: Data,
        key: Data,
        iv: Data
    ) -> Data? {
        let blockSize = kCCBlockSizeAES128
        var options: CCOptions = CCOptions(kCCOptionPKCS7Padding)
        if mode == .ecb {
            options |= CCOptions(kCCOptionECBMode)
        }

        var output = Data(count: input.count + blockSize)
        var moved = 0

        let status = input.withUnsafeBytes { srcBytes -> CCCryptorStatus in
            key.withUnsafeBytes { keyBytes -> CCCryptorStatus in
                iv.withUnsafeBytes { ivBytes -> CCCryptorStatus in
                    output.withUnsafeMutableBytes { dstBytes -> CCCryptorStatus in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            options,
                            keyBytes.baseAddress,
                            keyBytes.count,
                            mode == .cbc ? ivBytes.baseAddress : nil,
                            srcBytes.baseAddress,
                            srcBytes.count,
                            dstBytes.baseAddress,
                            dstBytes.count,
                            &moved
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        output.count = moved
        return output
    }
}

extension String {
    /// Convert URL-safe base64 → standard base64 (bundle uses `.` as padding).
    var websiteBundleStandardBase64: String {
        var normalized = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: ".", with: "=")
        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        return normalized
    }
}

extension Data {
    /// Base64-url without padding (`+→-`, `/→_`, drop `=`).
    var websiteBundleBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
