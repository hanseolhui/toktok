import Cocoa
import ApplicationServices

/// 맨 앞 창을 화면 반 · 4분할 · 가득 · 다음 모니터로 (손쉬운 사용 API 로 직접 이동)
enum WindowTiler {
    enum Mode { case left, right, fill, center, topLeft, topRight, bottomLeft, bottomRight, nextScreen }

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
        let screens = NSScreen.screens
        let index = screens.firstIndex { axRect($0.frame).contains(center) } ?? 0
        guard !screens.isEmpty else { return }
        var area = axRect(screens[index].visibleFrame)

        var target = area
        let halfW = (area.width / 2).rounded(), halfH = (area.height / 2).rounded()
        switch mode {
        case .left:  target.size.width = halfW
        case .right: target.size.width = halfW; target.origin.x = area.maxX - halfW
        case .fill:  break
        case .center:
            // 가로 2/3 · 세로 3/4 크기로 화면 가운데
            let w = (area.width * 2 / 3).rounded(), h = (area.height * 3 / 4).rounded()
            target = CGRect(x: (area.midX - w / 2).rounded(), y: (area.midY - h / 2).rounded(), width: w, height: h)
        case .topLeft:     target.size = CGSize(width: halfW, height: halfH)
        case .topRight:    target = CGRect(x: area.maxX - halfW, y: area.minY, width: halfW, height: halfH)
        case .bottomLeft:  target = CGRect(x: area.minX, y: area.maxY - halfH, width: halfW, height: halfH)
        case .bottomRight: target = CGRect(x: area.maxX - halfW, y: area.maxY - halfH, width: halfW, height: halfH)
        case .nextScreen:
            // 다음 모니터의 같은 비율 위치로 (크기는 그 화면에 맞게)
            guard screens.count > 1 else { return }
            let next = axRect(screens[(index + 1) % screens.count].visibleFrame)
            let rx = (frame.minX - area.minX) / area.width, ry = (frame.minY - area.minY) / area.height
            let w = min(frame.width, next.width), h = min(frame.height, next.height)
            target = CGRect(x: min(next.minX + rx * next.width, next.maxX - w),
                            y: min(next.minY + ry * next.height, next.maxY - h), width: w, height: h)
            area = next
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
