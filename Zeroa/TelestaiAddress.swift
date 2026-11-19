import Foundation
import CryptoKit

/// Telestai base58check addresses (version byte 0x42), matching Halo's pubkey-to-address mapping.
enum TelestaiAddress {
    static func fromCompressedPublicKey(_ publicKey: Data) -> String? {
        let compressed = compressedPublicKey(publicKey)
        guard compressed.count == 33 else { return nil }
        let ripe = RIPEMD160.hash(Data(SHA256.hash(data: compressed)))
        var payload = Data([0x42])
        payload.append(ripe)
        let checksum = Data(SHA256.hash(data: Data(SHA256.hash(data: payload)))).prefix(4)
        payload.append(checksum)
        return Base58.encode(payload)
    }

    /// Accept compressed (33), uncompressed (65), or raw x||y (64) SEC1 public keys.
    static func compressedPublicKey(_ publicKey: Data) -> Data {
        if publicKey.count == 33, publicKey.first == 0x02 || publicKey.first == 0x03 {
            return publicKey
        }
        let raw: Data
        if publicKey.count == 65, publicKey.first == 0x04 {
            raw = publicKey.dropFirst()
        } else if publicKey.count == 64 {
            raw = publicKey
        } else {
            return publicKey
        }
        let x = raw.prefix(32)
        let yLast = raw.last ?? 0
        var out = Data([yLast % 2 == 0 ? 0x02 : 0x03])
        out.append(x)
        return out
    }
}

enum RIPEMD160 {
    static func hash(_ message: Data) -> Data {
        Data(digest(Array(message)))
    }

    private static func digest(_ message: [UInt8]) -> [UInt8] {
        var data = message
        let bitLength = UInt64(message.count) * 8
        data.append(0x80)
        while (data.count % 64) != 56 {
            data.append(0)
        }
        var length = bitLength.littleEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }

        var h: [UInt32] = [
            0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
        ]
        var offset = 0
        while offset < data.count {
            var block = [UInt32](repeating: 0, count: 16)
            for i in 0..<16 {
                let start = offset + i * 4
                block[i] = UInt32(data[start])
                    | (UInt32(data[start + 1]) << 8)
                    | (UInt32(data[start + 2]) << 16)
                    | (UInt32(data[start + 3]) << 24)
            }
            h = compress(h, block)
            offset += 64
        }

        var out = [UInt8]()
        out.reserveCapacity(20)
        for value in h {
            out.append(UInt8(value & 0xff))
            out.append(UInt8((value >> 8) & 0xff))
            out.append(UInt8((value >> 16) & 0xff))
            out.append(UInt8((value >> 24) & 0xff))
        }
        return out
    }

    private static func compress(_ h: [UInt32], _ x: [UInt32]) -> [UInt32] {
        var al = h[0], bl = h[1], cl = h[2], dl = h[3], el = h[4]
        var ar = h[0], br = h[1], cr = h[2], dr = h[3], er = h[4]

        for j in 0..<80 {
            var t = rol(al &+ f(j, bl, cl, dl) &+ x[rLeft[j]] &+ kLeft(j), sLeft[j]) &+ el
            al = el; el = dl; dl = rol(cl, 10); cl = bl; bl = t
            t = rol(ar &+ f(79 - j, br, cr, dr) &+ x[rRight[j]] &+ kRight(j), sRight[j]) &+ er
            ar = er; er = dr; dr = rol(cr, 10); cr = br; br = t
        }

        let t = h[1] &+ cl &+ dr
        return [
            t,
            h[2] &+ dl &+ er,
            h[3] &+ el &+ ar,
            h[4] &+ al &+ br,
            h[0] &+ bl &+ cr
        ]
    }

    private static func f(_ j: Int, _ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        switch j {
        case 0..<16: return x ^ y ^ z
        case 16..<32: return (x & y) | (~x & z)
        case 32..<48: return (x | ~y) ^ z
        case 48..<64: return (x & z) | (y & ~z)
        default: return x ^ (y | ~z)
        }
    }

    private static func kLeft(_ j: Int) -> UInt32 {
        switch j {
        case 0..<16: return 0
        case 16..<32: return 0x5A827999
        case 32..<48: return 0x6ED9EBA1
        case 48..<64: return 0x8F1BBCDC
        default: return 0xA953FD4E
        }
    }

    private static func kRight(_ j: Int) -> UInt32 {
        switch j {
        case 0..<16: return 0x50A28BE6
        case 16..<32: return 0x5C4DD124
        case 32..<48: return 0x6D703EF3
        case 48..<64: return 0x7A6D76E9
        default: return 0
        }
    }

    private static func rol(_ x: UInt32, _ n: Int) -> UInt32 {
        (x << n) | (x >> (32 - n))
    }

    private static let rLeft = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13
    ]
    private static let rRight = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11
    ]
    private static let sLeft = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6
    ]
    private static let sRight = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11
    ]
}
