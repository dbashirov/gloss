import Testing
@testable import GlossCore

struct ProviderErrorTests {
    @Test(arguments: ProviderError.allCases)
    func mappingKeepsProviderError(error: ProviderError) {
        #expect(ProviderError(mapping: error) == error)
    }

    @Test func mappingTurnsOtherErrorsIntoInvalidResponse() {
        #expect(ProviderError(mapping: UnexpectedError()) == .invalidResponse)
        #expect(ProviderError(mapping: CancellationError()) == .invalidResponse)
    }
}
