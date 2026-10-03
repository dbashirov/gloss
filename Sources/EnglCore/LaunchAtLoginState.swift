import Foundation
import ServiceManagement

/// LaunchAtLoginState is what the settings show for the login item.
public enum LaunchAtLoginState: Sendable, Equatable {
    /// The app runs from outside /Applications: registering would point the login
    /// item at a build folder.
    case unavailable
    case disabled
    case enabled
    case requiresApproval

    public init(status: SMAppService.Status, bundleURL: URL) {
        guard Self.isInstalled(bundleURL) else {
            self = .unavailable
            return
        }
        switch status {
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notRegistered, .notFound:
            self = .disabled
        @unknown default:
            self = .disabled
        }
    }

    /// The toggle is on while the item is registered, even if it awaits approval.
    public var isOn: Bool {
        self == .enabled || self == .requiresApproval
    }

    static func isInstalled(_ bundleURL: URL) -> Bool {
        let components = bundleURL.standardizedFileURL.pathComponents
        return components.count > 2 && components[1] == "Applications"
    }
}
