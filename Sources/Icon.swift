import Cocoa

// MARK: - 아이콘 (V자 두 손가락 + 톡 표시)

enum Icon {
    /// 크기 `side` 의 정사각형 안에 V자로 벌린 손과 (active 이면) 손끝의 톡 표시를 그림
    static func draw(side: CGFloat, active: Bool, color: NSColor) {
        let s = side / 18   // 18pt 기준 좌표
        color.setFill(); color.setStroke()

        /// (x, y) 에서 시작해 angle 도 기울어진 손가락 모양
        func capsule(x: CGFloat, y: CGFloat, width: CGFloat, length: CGFloat, angle: CGFloat) -> NSBezierPath {
            let p = NSBezierPath(roundedRect: NSRect(x: -width / 2 * s, y: 0, width: width * s, height: length * s),
                                 xRadius: width / 2 * s, yRadius: width / 2 * s)
            var t = AffineTransform(translationByX: x * s, byY: y * s)
            t.rotate(byDegrees: angle)
            p.transform(using: t)
            return p
        }
        let palm = NSBezierPath(roundedRect: NSRect(x: 5.0 * s, y: 0.4 * s, width: 8.0 * s, height: 7.6 * s),
                                xRadius: 2.2 * s, yRadius: 2.2 * s)
        let hand = [
            palm,
            capsule(x: 7.0, y: 5.6, width: 3.3, length: 9.4, angle: 21),    // 검지
            capsule(x: 11.0, y: 5.6, width: 3.3, length: 9.4, angle: -21),  // 중지
        ]
        hand.forEach { $0.fill() }
        guard active else { return }

        // 손끝 바깥의 톡 표시 (작은 호)
        for (cx, cy, start, end) in [(4.3, 12.6, 100.0, 195.0), (13.7, 12.6, -15.0, 80.0)]
                as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: cx * s, y: cy * s), radius: 3.4 * s,
                          startAngle: start, endAngle: end)
            arc.lineWidth = 1.1 * s; arc.lineCapStyle = .round
            arc.stroke()
        }
    }

    static func menuBar(active: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            draw(side: rect.width, active: active, color: .black); return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "톡톡"
        return img
    }
}

