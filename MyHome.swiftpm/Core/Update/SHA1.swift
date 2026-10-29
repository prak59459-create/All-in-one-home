import Foundation

/// SHA-1（FIPS 180-4）。git と同じ方法でファイルの同一性を確かめるためだけに使う（暗号の安全性には使わない）。
/// Linux でもテストできるよう、CryptoKit を使わずに実装する。
enum SHA1 {
    static func hexDigest(_ data: Data) -> String {
        let words: [UInt32] = digest(Array(data))
        var text: String = ""
        for word in words {
            let hex: String = String(word, radix: 16)
            text += String(repeating: "0", count: 8 - hex.count) + hex
        }
        return text
    }

    /// git のブロブとしてのハッシュ（"blob <バイト数>\0" + 中身）。git ls-tree や GitHub の tree API の sha と同じ値になる。
    static func gitBlobHash(_ data: Data) -> String {
        var blob: Data = Data("blob \(data.count)".utf8)
        blob.append(0)
        blob.append(data)
        return hexDigest(blob)
    }

    private static func digest(_ message: [UInt8]) -> [UInt32] {
        var state: [UInt32] = [0x6745_2301, 0xEFCD_AB89, 0x98BA_DCFE, 0x1032_5476, 0xC3D2_E1F0]
        let padded: [UInt8] = pad(message)
        var chunk: Int = 0
        while chunk < padded.count {
            process(Array(padded[chunk..<(chunk + 64)]), into: &state)
            chunk += 64
        }
        return state
    }

    private static func pad(_ message: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = message
        let bitLength: UInt64 = UInt64(message.count) * 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 {
            bytes.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            let byte: UInt64 = (bitLength >> UInt64(shift)) & 0xFF
            bytes.append(UInt8(byte))
        }
        return bytes
    }

    private static func process(_ block: [UInt8], into state: inout [UInt32]) {
        var w: [UInt32] = Array(repeating: 0, count: 80)
        for index in 0..<16 {
            let base: Int = index * 4
            let b0: UInt32 = UInt32(block[base]) << 24
            let b1: UInt32 = UInt32(block[base + 1]) << 16
            let b2: UInt32 = UInt32(block[base + 2]) << 8
            let b3: UInt32 = UInt32(block[base + 3])
            w[index] = b0 | b1 | b2 | b3
        }
        for index in 16..<80 {
            let mixed: UInt32 = w[index - 3] ^ w[index - 8] ^ w[index - 14] ^ w[index - 16]
            w[index] = rotate(mixed, by: 1)
        }
        var a: UInt32 = state[0]
        var b: UInt32 = state[1]
        var c: UInt32 = state[2]
        var d: UInt32 = state[3]
        var e: UInt32 = state[4]
        for index in 0..<80 {
            let (f, k): (UInt32, UInt32) = roundValues(index: index, b: b, c: c, d: d)
            let temp: UInt32 = rotate(a, by: 5) &+ f &+ e &+ k &+ w[index]
            e = d
            d = c
            c = rotate(b, by: 30)
            b = a
            a = temp
        }
        state[0] = state[0] &+ a
        state[1] = state[1] &+ b
        state[2] = state[2] &+ c
        state[3] = state[3] &+ d
        state[4] = state[4] &+ e
    }

    private static func roundValues(index: Int, b: UInt32, c: UInt32, d: UInt32) -> (UInt32, UInt32) {
        switch index {
        case 0..<20:
            return ((b & c) | (~b & d), 0x5A82_7999)
        case 20..<40:
            return (b ^ c ^ d, 0x6ED9_EBA1)
        case 40..<60:
            return ((b & c) | (b & d) | (c & d), 0x8F1B_BCDC)
        default:
            return (b ^ c ^ d, 0xCA62_C1D6)
        }
    }

    private static func rotate(_ value: UInt32, by amount: UInt32) -> UInt32 {
        (value << amount) | (value >> (32 - amount))
    }
}
