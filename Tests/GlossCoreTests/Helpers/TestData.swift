import CoreGraphics
@testable import GlossCore

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

/// Lays paragraphs out top to bottom like body text: lines 0.05 high and 0.01 apart,
/// paragraphs a line height apart.
func layOut(_ paragraphs: [[String]]) -> [RecognizedLine] {
    let lineHeight = 0.05
    var top = 1.0
    var lines: [RecognizedLine] = []
    for (index, paragraph) in paragraphs.enumerated() {
        if index > 0 {
            top -= lineHeight
        }
        for text in paragraph {
            let bounds = CGRect(x: 0.1, y: top - lineHeight, width: 0.8, height: lineHeight)
            lines.append(RecognizedLine(text: text, bounds: bounds))
            top -= lineHeight + 0.01
        }
    }
    return lines
}
