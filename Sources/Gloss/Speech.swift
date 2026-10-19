import AVFoundation
import GlossCore

/// Speech pronounces words with a system voice for their language.
@MainActor
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: Language) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.voiceCode)
        synthesizer.speak(utterance)
    }
}
