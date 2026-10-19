import Foundation
import ServiceManagement
import Testing
@testable import GlossCore

private let installed = URL(filePath: "/Applications/Gloss.app")
private let buildFolder = URL(filePath: "/Users/me/src/gloss/build/Gloss.app")

struct LaunchAtLoginStateTests {
    @Test(arguments: [
        (SMAppService.Status.enabled, LaunchAtLoginState.enabled),
        (.requiresApproval, .requiresApproval),
        (.notRegistered, .disabled),
        (.notFound, .disabled),
    ])
    func mapsStatusForInstalledApp(status: SMAppService.Status, expected: LaunchAtLoginState) {
        #expect(LaunchAtLoginState(status: status, bundleURL: installed) == expected)
    }

    @Test(arguments: [
        SMAppService.Status.enabled, .requiresApproval, .notRegistered, .notFound,
    ])
    func isUnavailableOutsideApplications(status: SMAppService.Status) {
        #expect(LaunchAtLoginState(status: status, bundleURL: buildFolder) == .unavailable)
    }

    @Test(arguments: [
        ("/Applications/Gloss.app", true),
        ("/Applications/Tools/Gloss.app", true),
        ("/Applications/../Users/me/Gloss.app", false),
        ("/Users/me/Applications/Gloss.app", false),
        ("/Applications", false),
        ("/ApplicationsBackup/Gloss.app", false),
    ])
    func detectsInstalledBundle(path: String, expected: Bool) {
        #expect(LaunchAtLoginState.isInstalled(URL(filePath: path)) == expected)
    }

    @Test func toggleIsOnWhileRegistered() {
        #expect(LaunchAtLoginState.enabled.isOn)
        #expect(LaunchAtLoginState.requiresApproval.isOn)
        #expect(!LaunchAtLoginState.disabled.isOn)
        #expect(!LaunchAtLoginState.unavailable.isOn)
    }
}
