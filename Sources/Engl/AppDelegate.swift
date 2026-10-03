import AppKit
import EnglCore
import Observation
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.dbashirov.engl", category: "app")
    private var environment: AppEnvironment?
    private var statusItem: StatusItemController?
    private var stateLog: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let environment = AppEnvironment()
        self.environment = environment

        environment.watcher.onDoubleCopy = { [weak environment] text in
            environment?.translator.translate(text)
        }
        statusItem = StatusItemController(
            settings: environment.settings,
            onManualInput: { [weak self] in
                self?.logger.info("manual input requested")
            },
            onDoubleCopyToggle: { [weak self] in
                self?.applyDoubleCopySettings()
            },
            onOpenSettings: { [weak self] in
                self?.logger.info("settings requested")
            }
        )
        applyDoubleCopySettings()
        logStates(of: environment.translator)
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.watcher.stop()
        stateLog?.cancel()
    }

    private func applyDoubleCopySettings() {
        guard let environment else {
            return
        }
        let settings = environment.settings
        let watcher = environment.watcher
        watcher.interval = .seconds(settings.doubleCopyInterval)
        guard settings.doubleCopyEnabled else {
            watcher.stop()
            return
        }
        watcher.start()
        if environment.pasteboard.accessBehavior == .alwaysDeny {
            logger.warning("""
                paste access denied: allow Engl in Privacy & Security → Paste from Other Apps
                """)
        }
    }

    // temporary until the panel shows results (Task 11)
    private func logStates(of translator: TranslationController) {
        let logger = logger
        stateLog = Task {
            for await state in Observations({ translator.state }) {
                logger.info("translation: \(Self.describe(state), privacy: .public)")
            }
        }
    }

    private static func describe(_ state: TranslationController.State) -> String {
        switch state {
        case .idle:
            "idle"
        case .loading(let query):
            "loading \(query.source.rawValue)→\(query.target.rawValue) \(query.text)"
        case .result(let routed):
            "[\(routed.providerID)] \(describe(routed.result))"
        case .failed(let text, let error):
            "failed \(text): \(error)"
        }
    }

    private static func describe(_ result: TranslationResult) -> String {
        switch result {
        case .dictionary(let entry):
            let senses = entry.groups.flatMap(\.translations).map(\.text)
            return "\(entry.word): \(senses.joined(separator: ", "))"
        case .text(let translation):
            return translation.translation
        }
    }
}
