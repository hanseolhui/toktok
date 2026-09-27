// 로고 PNG 만들기: d=$(mktemp -d); cp tools/make-logo.swift $d/main.swift; swiftc Sources/Icon.swift $d/main.swift -o $d/mk && $d/mk assets
import Cocoa

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets"
let accent = NSColor(srgbRed: 0xd9/255, green: 0x48/255, blue: 0x0f/255, alpha: 1)
let accent2 = NSColor(srgbRed: 0xff/255, green: 0x8a/255, blue: 0x3d/255, alpha: 1)
let cream = NSColor(srgbRed: 0xf6/255, green: 0xf1/255, blue: 0xe8/255, alpha: 1)

func png(_ w: Int, _ h: Int, _ name: String, _ body: (NSRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    body(NSRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}

/// 주황 둥근 사각형 + 흰 V 손
func badge(_ r: NSRect) {
    let bg = NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225)
    NSGradient(starting: accent2, ending: accent)!.draw(in: bg, angle: -90)
    let side = r.width * 0.64
    NSGraphicsContext.current!.cgContext.saveGState()
    NSGraphicsContext.current!.cgContext.translateBy(x: r.midX - side / 2, y: r.minY + r.height * 0.15)
    Icon.draw(side: side, active: true, color: .white)
    NSGraphicsContext.current!.cgContext.restoreGState()
}

// 1) 정사각 로고 (Gumroad 썸네일 · 앱 아이콘용)
png(1024, 1024, "logo-1024.png") { r in badge(r.insetBy(dx: 40, dy: 40)) }

// 2) 가로 커버 1280x720 (Gumroad 커버)
png(1280, 720, "cover-1280x720.png") { r in
    cream.setFill(); r.fill()
    badge(NSRect(x: 120, y: 190, width: 340, height: 340))
    let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 110, weight: .heavy), .foregroundColor: NSColor(white: 0.1, alpha: 1)]
    let sub: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 44, weight: .semibold), .foregroundColor: accent]
    let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 34, weight: .medium), .foregroundColor: NSColor(white: 0.35, alpha: 1)]
    ("톡톡 Pro" as NSString).draw(at: NSPoint(x: 530, y: 400), withAttributes: title)
    ("맥 트랙패드 제스처" as NSString).draw(at: NSPoint(x: 536, y: 330), withAttributes: sub)
    ("평생 이용 · 맥 3대 · 나만의 단축키" as NSString).draw(at: NSPoint(x: 536, y: 262), withAttributes: small)
}
