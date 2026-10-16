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
    /// Why the last screen area gave no text; shown instead of the translation state.
    var screenTextError: ScreenTextError?
}

/// PanelResizePhase is a step of resizing the panel by its corner grip.
enum PanelResizePhase {
    case changed
    case ended
}

/// PanelActions are the commands the panel content sends to its controller.
struct PanelActions {
    let togglePin: () -> Void
    let close: () -> Void
    let copy: (String) -> Void
    let perform: (ErrorAction) -> Void
    let resize: (PanelResizePhase) -> Void
    /// Returns the panel to the size of its content.
    let resetSize: () -> Void
}
