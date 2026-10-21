/// CopiedText is what the pasteboard offers for translation.
public enum CopiedText: Equatable, Sendable {
    case text(String)
    /// Plain text the system did not let Gloss read, e.g. paste access is denied.
    case unreadable
    /// No text, blank text or contents that must not be read, such as a copied password.
    case empty
}

extension PasteboardReading {
    /// Reads the current contents for translation; the system may ask for paste access.
    public func copiedText() -> CopiedText {
        let types = types
        let isConcealed = types.contains(PasteboardType.concealed)
            || types.contains(PasteboardType.transient)
        guard !isConcealed, types.contains(PasteboardType.string) else {
            return .empty
        }
        guard let text = string() else {
            return .unreadable
        }
        return text.allSatisfy(\.isWhitespace) ? .empty : .text(text)
    }
}
