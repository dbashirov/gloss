import Foundation
import Testing

/// Loads a Yandex JSON fixture from `Fixtures/`.
func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}
