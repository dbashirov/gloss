import Testing
@testable import EnglCore

struct LanguagePackDownloadTests {
    @Test func isIdleInitially() {
        let download = LanguagePackDownload()

        #expect(!download.isActive)
        #expect(download.configuration == nil)
    }

    @Test func startSetsEnRuConfiguration() throws {
        var download = LanguagePackDownload()

        download.start()

        let configuration = try #require(download.configuration)
        #expect(download.isActive)
        #expect(configuration.source == Language.en.locale)
        #expect(configuration.target == Language.ru.locale)
    }

    @Test func normalFinishEndsDownload() {
        var download = LanguagePackDownload()
        download.start()

        let finished = download.finish(requestID: download.requestID)

        #expect(finished)
        #expect(!download.isActive)
        #expect(download.configuration == nil)
    }

    @Test func secondRequestWhileDownloadingRestartsTask() throws {
        var download = LanguagePackDownload()
        download.start()
        let first = try #require(download.configuration)
        let firstID = download.requestID

        download.start()

        let second = try #require(download.configuration)
        #expect(download.requestID != firstID)
        #expect(second != first)
        #expect(second.source == first.source)
        #expect(second.target == first.target)

        let staleFinished = download.finish(requestID: firstID)
        #expect(!staleFinished)
        #expect(download.configuration == second)

        let currentFinished = download.finish(requestID: download.requestID)
        #expect(currentFinished)
        #expect(!download.isActive)
    }

    @Test func lateStaleFinishKeepsNewerDownload() throws {
        var download = LanguagePackDownload()
        download.start()
        let staleID = download.requestID
        _ = download.finish(requestID: staleID)
        download.start()
        let current = try #require(download.configuration)

        let finished = download.finish(requestID: staleID)

        #expect(!finished)
        #expect(download.configuration == current)
    }

    @Test func finishWithoutDownloadIsIgnored() {
        var download = LanguagePackDownload()

        let finished = download.finish(requestID: download.requestID)

        #expect(!finished)
        #expect(!download.isActive)
    }

    @Test func repeatedFinishIsIgnored() {
        var download = LanguagePackDownload()
        download.start()
        let requestID = download.requestID
        _ = download.finish(requestID: requestID)

        let finished = download.finish(requestID: requestID)

        #expect(!finished)
    }
}
