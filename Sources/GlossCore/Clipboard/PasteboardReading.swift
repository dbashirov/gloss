/// PasteboardReading is the read-only view of the general pasteboard that
/// `ClipboardWatcher` polls.
@MainActor
public protocol PasteboardReading: AnyObject {
    /// Grows by one on every change of the pasteboard contents.
    var changeCount: Int { get }
    /// UTI identifiers of the current contents.
    var types: [String] { get }
    /// Reads the current plain text; the system may ask the user for access.
    func string() -> String?
}

/// PasteboardType lists the UTI identifiers the watcher cares about.
public enum PasteboardType {
    public static let string = "public.utf8-plain-text"
    /// Marks contents that must not be read, e.g. a password copied from a manager.
    public static let concealed = "org.nspasteboard.ConcealedType"
    /// Marks short-lived contents that are not meant to be kept or processed.
    public static let transient = "org.nspasteboard.TransientType"
}
