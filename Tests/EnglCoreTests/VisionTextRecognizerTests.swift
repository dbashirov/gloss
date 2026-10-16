import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import EnglCore

/// Draws black lines of text on white at 2x, like a Retina screenshot.
private func render(_ lines: [String]) throws -> CGImage {
    let scale: CGFloat = 2
    let lineHeight = 20 * scale
    let size = CGSize(width: 420 * scale, height: lineHeight * CGFloat(lines.count) + 20 * scale)
    let context = try #require(CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(origin: .zero, size: size))
    let font = try #require(CTFontCreateUIFontForLanguage(.system, 14 * scale, nil))
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            CGColor(gray: 0, alpha: 1),
    ]
    for (index, line) in lines.enumerated() {
        let baseline = size.height - 10 * scale - lineHeight * CGFloat(index + 1) + 6 * scale
        context.textPosition = CGPoint(x: 10 * scale, y: baseline)
        let text = NSAttributedString(string: line, attributes: attributes)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }
    return try #require(context.makeImage())
}

struct VisionTextRecognizerTests {
    @Test(arguments: [
        ["serendipity"],
        ["The quick brown fox jumps over", "the lazy dog."],
        ["Съешь же ещё этих мягких", "французских булок, да выпей чаю."],
        ["Привет, how are you?"],
    ])
    func recognizesEnglishAndRussianLines(lines: [String]) async throws {
        let recognized = try await VisionTextRecognizer().recognizeLines(in: try render(lines))

        #expect(recognized == lines)
    }

    @Test func findsNothingOnBlankImage() async throws {
        #expect(try await VisionTextRecognizer().recognizeLines(in: blankImage).isEmpty)
    }
}
