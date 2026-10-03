import AppKit
import SwiftUI

/// PanelHostingView reports changes of the SwiftUI content size so the panel can be
/// resized and re-positioned.
final class PanelHostingView<Content: View>: NSHostingView<Content> {
    var onContentSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }
}
