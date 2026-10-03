/// SettingsNote is a one-line outcome shown under a settings control.
public struct SettingsNote: Equatable, Sendable {
    public let text: String
    public let isError: Bool

    public static func success(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: false)
    }

    public static func failure(_ text: String) -> SettingsNote {
        SettingsNote(text: text, isError: true)
    }
}
