import EnglCore
import Observation

/// PanelModel holds the panel input shared between the controller and the SwiftUI view.
@MainActor
@Observable
final class PanelModel {
    var query = ""
    /// Incremented on every show to move the focus into the query field.
    var focusRequest = 0
    var isPasteAccessDenied = false
}

/// PanelActions are the commands the panel content sends to its controller.
struct PanelActions {
    let togglePin: () -> Void
    let close: () -> Void
    let copy: (String) -> Void
    let perform: (ErrorAction) -> Void
}
