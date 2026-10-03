import Foundation

extension UUID {
    /// Returns a time-ordered RFC 9562 version 7 UUID.
    static func v7(at date: Date = .now) -> UUID {
        let millis = UInt64(max(date.timeIntervalSince1970, 0) * 1000)
        var bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        for index in 0..<6 {
            bytes[index] = UInt8(truncatingIfNeeded: millis >> (8 * (5 - index)))
        }
        bytes[6] = 0x70 | (bytes[6] & 0x0F)
        bytes[8] = 0x80 | (bytes[8] & 0x3F)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
