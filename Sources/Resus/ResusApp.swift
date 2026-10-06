import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: StudyStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store, !store.loadFailed else { return .terminateNow }
        Task {
            let saved = await store.flush()
            sender.reply(toApplicationShouldTerminate: saved)
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct ResusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: StudyStore
    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let custom = arguments.firstIndex(of: "--library-path").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let url = custom.map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Resus/library.json")
        _store = StateObject(wrappedValue: StudyStore(url: url, isolated: custom != nil))
    }
    var body: some Scene {
        Window("Resus", id: "workspace") {
            WorkspaceView().environmentObject(store).preferredColorScheme(.light).onAppear { delegate.store = store }
        }.defaultSize(width: 1360, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New note") { store.addNote() }.keyboardShortcut("n")
                Button("Import note…") { store.importNote() }.keyboardShortcut("i", modifiers: [.command, .shift])
                Divider()
                Button("Export backup…") { store.exportBackup() }
                Button("Restore backup…") { store.importBackup() }
            }
        }
        Settings { SettingsView().environmentObject(store).preferredColorScheme(.light) }
    }
}
