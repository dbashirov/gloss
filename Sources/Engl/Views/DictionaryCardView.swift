import EnglCore
import SwiftUI

/// DictionaryCardView shows a dictionary entry: the word with its transcription and
/// translations grouped by part of speech.
struct DictionaryCardView: View {
    let entry: DictionaryEntry
    let onSpeak: () -> Void

    @Environment(\.typography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.word)
                    .font(.system(size: typography.title, weight: .semibold))
                if let transcription = entry.transcription, !transcription.isEmpty {
                    Text("[\(transcription)]")
                        .foregroundStyle(.secondary)
                }
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(.borderless)
                .help("Произнести")
            }
            ForEach(Array(entry.groups.enumerated()), id: \.offset) { _, group in
                GroupView(group: group)
            }
        }
        .textSelection(.enabled)
    }
}

private struct GroupView: View {
    let group: PartOfSpeechGroup

    @Environment(\.typography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let partOfSpeech = group.partOfSpeech, !partOfSpeech.isEmpty {
                Text(partOfSpeech)
                    .font(.system(size: typography.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            ForEach(Array(group.translations.enumerated()), id: \.offset) { index, sense in
                SenseView(number: index + 1, sense: sense)
            }
        }
    }
}

private struct SenseView: View {
    let number: Int
    let sense: Sense

    @Environment(\.typography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(Text("\(number). \(sense.text)").fontWeight(.medium))\(synonyms)")
            if !sense.meanings.isEmpty {
                Text("(\(sense.meanings.joined(separator: ", ")))")
                    .font(.system(size: typography.callout))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(sense.examples.enumerated()), id: \.offset) { _, example in
                Text(describe(example))
                    .font(.system(size: typography.callout))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var synonyms: Text {
        guard !sense.synonyms.isEmpty else {
            return Text(verbatim: "")
        }
        return Text(verbatim: ", " + sense.synonyms.joined(separator: ", "))
    }

    private func describe(_ example: Example) -> String {
        guard let translation = example.translation, !translation.isEmpty else {
            return example.source
        }
        return "\(example.source) — \(translation)"
    }
}
