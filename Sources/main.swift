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
        GestureDetector.shared.onSlider = { side, up in
            DispatchQueue.main.async { Settings.shared.handleSlider(side, up: up) }
        }
        GestureDetector.shared.onAppSwitch = { step in
            DispatchQueue.main.async { Settings.shared.handleAppSwitch(step) }
        }
        Settings.shared.syncDetector()
        PointerLock.install()
        // 손쉬운 사용 권한을 나중에 허용해도 포인터 잠금이 켜지게
        if !PointerLock.installed {
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
                PointerLock.install()
                if PointerLock.installed { timer.invalidate() }
            }
        }

        // 타자 중 잘못 실행 방지: 다른 앱에서 키를 누른 시각 기록 (톡톡이 보낸 키는 제외)
        let me = Int64(ProcessInfo.processInfo.processIdentifier)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { e in
            if e.cgEvent?.getIntegerValueField(.eventSourceUnixProcessID) != me { Settings.shared.lastKeyTime = Date() }
        }

        installEditMenu()

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
            alert(t("트랙패드에 연결할 수 없어요", "Can’t connect to the trackpad"), t("이 macOS 버전에서는 톡톡이 동작하지 않을 수 있어요.", "TokTok may not work on this version of macOS."))
            return
        }
        multitouch = mt
        Multitouch.current = mt
        mt.restart()
        mt.watchDevices()
        mt.startWatchdog()

        // 새 버전이 있는지 조용히 확인 (있으면 메뉴·설정에 표시)
        Task { await Updater.shared.check(silent: true) }

        // --settings: 실행하자마자 설정 창 열기 (스크린샷·테스트용)
        if CommandLine.arguments.contains("--settings") { openSettings() }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.multitouch?.restart() }
        }
    }

    /// 메뉴바 앱은 편집 메뉴가 없어 설정 창에서 ⌘C/⌘V 가 안 먹힘 → 보이지 않는 편집 메뉴 추가
    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(withTitle: "창 닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = main
    }

    // 메뉴는 열 때마다 새로 그림
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: t("톡톡", "TokTok") + " " + Updater.current, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(item(settings.enabled ? t("켜짐", "On") : t("꺼짐", "Off"), #selector(toggleEnabled), checked: settings.enabled))
        menu.addItem(item(t("설정…", "Settings…"), #selector(openSettings), key: ","))
        menu.addItem(item(t("사용 설명서", "User guide"), #selector(openGuide)))
        if let v = Updater.shared.availableVersion {
            menu.addItem(item(t("🔔 새 버전 \(v) 설치…", "🔔 Install version \(v)…"), #selector(openSettings)))
        }
        menu.addItem(.separator())

        if !AXIsProcessTrusted() {
            menu.addItem(item(t("⚠️ 손쉬운 사용 권한 허용하기…", "⚠️ Allow Accessibility access…"), #selector(openAccessibility)))
        }
        menu.addItem(item(t("트랙패드 다시 찾기 (\(multitouch?.deviceCount ?? 0)개 연결됨)", "Rescan trackpads (\(multitouch?.deviceCount ?? 0) connected)"), #selector(rescan)))
        menu.addItem(.separator())
        menu.addItem(item(t("톡톡 종료", "Quit TokTok"), #selector(quit), key: "q"))
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
            w.title = t("톡톡 설정", "TokTok Settings")
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        settingsWindow?.title = t("톡톡 설정", "TokTok Settings")
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }


    @objc private func openGuide() { NSWorkspace.shared.open(Store.guideURL) }
    @objc private func rescan() { multitouch?.restart() }
    @objc private func openAccessibility() { requestAccessibility() }
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
