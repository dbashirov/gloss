import CoreGraphics
import Foundation
import Vision

/// VisionTextRecognizer recognizes English and Russian text on the device with Vision.
public struct VisionTextRecognizer: TextRecognizing {
    private static let languages = [
        Locale.Language(identifier: "en-US"),
        Locale.Language(identifier: "ru-RU"),
    ]

    public init() {}

    public func recognizeLines(in image: CGImage) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = Self.languages
        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            observation.topCandidates(1).first.map { candidate in
                RecognizedLine(text: candidate.string, bounds: observation.boundingBox.cgRect)
            }
        }
    }
}
