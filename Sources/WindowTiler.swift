import Cocoa
import ApplicationServices

/// 맨 앞 창을 화면 왼쪽 반 / 오른쪽 반 / 가득으로 (손쉬운 사용 API 로 직접 이동)
enum WindowTiler {
    enum Mode { case left, right, fill }

    static func tile(_ mode: Mode) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            Log.write("창 정렬: 맨 앞 창을 찾지 못함 (\(app.localizedName ?? "?"))"); return
        }
        let window = ref as! AXUIElement

        // 창이 있는 화면 찾기 (손쉬운 사용 좌표는 주 화면 왼쪽 위가 원점)
        let frame = currentFrame(window) ?? .zero
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { axRect($0.frame).contains(center) } ?? NSScreen.main
        guard let screen else { return }
        let area = axRect(screen.visibleFrame)

        var target = area
        switch mode {
        case .left:  target.size.width = (area.width / 2).rounded()
        case .right: target.size.width = (area.width / 2).rounded(); target.origin.x = area.maxX - target.width
        case .fill:  break
        }
        // 크기 제한이 있는 앱을 위해 위치 → 크기 → 위치 순서로 적용
        set(window, position: target.origin)
        set(window, size: target.size)
        set(window, position: target.origin)
    }

    /// NSScreen 좌표(왼쪽 아래 원점) → 손쉬운 사용 좌표(주 화면 왼쪽 위 원점)
    private static func axRect(_ r: NSRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? r.height
        return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    private static func currentFrame(_ w: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &s) == .success,
              let p, let s else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private static func set(_ w: AXUIElement, position: CGPoint) {
        var p = position
        if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, v) }
    }

    private static func set(_ w: AXUIElement, size: CGSize) {
        var s = size
        if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, v) }
    }
}
