import CoreGraphics
@testable import EnglCore

/// Test data shared by the suites: the word "run" and a sentence with it.
let runQuery = Query(text: "run", source: .en, target: .ru, kind: .dictionary)
let sentenceQuery = Query(text: "I run every day", source: .en, target: .ru, kind: .sentence)

let runCard = TranslationResult.dictionary(DictionaryEntry(
    word: "run",
    transcription: "rʌn",
    groups: [PartOfSpeechGroup(partOfSpeech: "verb", translations: [Sense(text: "бежать")])]
))
let runText = TranslationResult.text(TextTranslation(source: "run", translation: "бежать"))

/// UnexpectedError is an error no provider maps: it must not be taken for a `ProviderError`.
struct UnexpectedError: Error {}

/// A blank 1×1 image for fakes that only pass an image along.
let blankImage: CGImage = {
    let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    return context!.makeImage()!
}()
