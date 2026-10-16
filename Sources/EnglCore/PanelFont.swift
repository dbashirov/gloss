/// PanelFont is the typeface of the panel text: one of the system designs or an installed
/// font family.
public enum PanelFont: Hashable, Sendable {
    case system
    case rounded
    case serif
    case monospaced
    case family(String)

    private static let familyPrefix = "family:"

    /// The value kept in the settings.
    public var storageValue: String {
        switch self {
        case .system: "system"
        case .rounded: "rounded"
        case .serif: "serif"
        case .monospaced: "monospaced"
        case .family(let name): Self.familyPrefix + name
        }
    }

    /// Restores a stored font; `nil` for a value this version does not know.
    public init?(storageValue: String) {
        switch storageValue {
        case "system": self = .system
        case "rounded": self = .rounded
        case "serif": self = .serif
        case "monospaced": self = .monospaced
        default:
            guard storageValue.hasPrefix(Self.familyPrefix) else {
                return nil
            }
            let name = String(storageValue.dropFirst(Self.familyPrefix.count))
            guard !name.isEmpty else {
                return nil
            }
            self = .family(name)
        }
    }
}
