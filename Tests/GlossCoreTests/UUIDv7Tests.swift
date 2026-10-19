import Foundation
import Testing

struct UUIDv7Tests {
    @Test func setsVersionAndVariant() {
        let uuid = UUID.v7().uuid

        #expect(uuid.6 >> 4 == 0x7)
        #expect(uuid.8 >> 6 == 0b10)
    }

    @Test func encodesUnixMillisecondsInFirstSixBytes() {
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        let uuid = UUID.v7(at: date).uuid

        let prefix = [uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5]
        let millis = prefix.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        #expect(millis == 1_700_000_000_123)
    }

    @Test func ordersByTime() {
        let earlier = UUID.v7(at: Date(timeIntervalSince1970: 1_700_000_000))
        let later = UUID.v7(at: Date(timeIntervalSince1970: 1_700_000_001))

        #expect(earlier.uuidString < later.uuidString)
        #expect(earlier != UUID.v7(at: Date(timeIntervalSince1970: 1_700_000_000)))
    }
}
