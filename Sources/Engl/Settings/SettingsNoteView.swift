import EnglCore
import SwiftUI

/// SettingsNoteView shows the outcome of the last action, if any.
struct SettingsNoteView: View {
    let note: SettingsNote?

    var body: some View {
        if let note {
            Label(note.text, systemImage: note.isError ? "exclamationmark.triangle" : "checkmark")
                .font(.caption)
                .foregroundStyle(note.isError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
