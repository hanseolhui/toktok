// 톡톡 (TokTok) — 트랙패드 제스처 메뉴바 앱
//
// 오른손 중지를 대고 검지를 톡 → 뒤로 (⌘[)
// 오른손 검지를 대고 중지를 톡 → 앞으로 (⌘])
// + 두 손가락 대고 톡, 세·네 손가락 탭, 모서리 톡 — 설정에서 켜고 동작을 바꿀 수 있어요.

import Cocoa
import SwiftUI
import ApplicationServices
import ServiceManagement

// MARK: - 로그

enum Log {
    static var enabled = UserDefaults.standard.bool(forKey: "debug")
        || CommandLine.arguments.contains("--debug")
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/TokTok.log")
    static let queue = DispatchQueue(label: "toktok.log")

    static func write(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message())\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - 메뉴바 앱

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var multitouch: Multitouch?
    private var settingsWindow: NSWindow?
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        GestureDetector.shared.onGesture = { g in
            DispatchQueue.main.async { Settings.shared.handle(g) }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        requestAccessibility()

        // 첫 실행 때 한 번만 로그인 시 자동 실행 등록 (이후엔 설정에서 끄고 켬)
        if !UserDefaults.standard.bool(forKey: "loginConfigured") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "loginConfigured")
        }

        guard let mt = Multitouch() else {
            alert("트랙패드에 연결할 수 없어요", "이 macOS 버전에서는 톡톡이 동작하지 않을 수 있어요.")
            return
        }
        multitouch = mt
        mt.restart()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.multitouch?.restart() }
        }
    }

    // 메뉴는 열 때마다 새로 그림
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "중지 대고 검지 톡: 뒤로 · 검지 대고 중지 톡: 앞으로", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(item(settings.enabled ? "켜짐" : "꺼짐", #selector(toggleEnabled), checked: settings.enabled))
        menu.addItem(item("설정…", #selector(openSettings), key: ","))
        menu.addItem(.separator())

        if !AXIsProcessTrusted() {
            menu.addItem(item("⚠️ 손쉬운 사용 권한 허용하기…", #selector(openAccessibility)))
        }
        menu.addItem(item("트랙패드 다시 찾기 (\(multitouch?.deviceCount ?? 0)개 연결됨)", #selector(rescan)))
        menu.addItem(item("디버그 로그 기록", #selector(toggleDebug), checked: Log.enabled))
        if Store.tipURL != nil {
            menu.addItem(.separator())
            menu.addItem(item("☕ 개발자에게 커피 사주기", #selector(tip)))
        }
        menu.addItem(.separator())
        menu.addItem(item("톡톡 종료", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self; i.state = checked ? .on : .off
        return i
    }

    private func updateIcon() {
        statusItem.button?.image = Icon.menuBar(active: settings.enabled)
        statusItem.button?.appearsDisabled = !settings.enabled
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        updateIcon()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "톡톡 설정"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleDebug() {
        Log.enabled.toggle()
        UserDefaults.standard.set(Log.enabled, forKey: "debug")
        if Log.enabled { NSWorkspace.shared.open(Log.url.deletingLastPathComponent()) }
    }

    @objc private func rescan() { multitouch?.restart() }
    @objc private func openAccessibility() { requestAccessibility() }
    @objc private func tip() { License.shared.openTip() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func alert(_ title: String, _ text: String) {
        let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
