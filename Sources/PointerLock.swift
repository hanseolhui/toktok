import CoreGraphics
import Foundation

/// 가장자리 슬라이더를 쓰는 동안 포인터가 움직이지 않게
/// 뒤에서 도는 앱은 포인터를 입력과 끊을 수 없어서, 슬라이더로 확정되면 포인터를 숨기고
/// 처음 자리에 붙잡아 두었다가 손을 떼면 그 자리에서 다시 보여 줌 (모두 메인 스레드에서)
enum PointerLock {
    private static var locked = false
    private static var hidden = false
    private static var anchor: CGPoint?

    /// 가장자리에 손가락이 닿음: 포인터 자리를 기억 (멀티터치 콜백 스레드에서 호출)
    static func lock() {
        DispatchQueue.main.async {
            guard !locked else { return }
            anchor = CGEvent(source: nil)?.location
            locked = true
        }
    }

    /// 슬라이더로 확정되어 쓰는 중: 포인터를 숨기고 처음 자리에 붙잡아 둠
    static func hold() {
        DispatchQueue.main.async {
            guard locked, let a = anchor else { return }
            if !hidden { CGDisplayHideCursor(CGMainDisplayID()); hidden = true }
            if CGEvent(source: nil)?.location != a { CGWarpMouseCursorPosition(a) }
        }
    }

    /// 손을 뗌 · 슬라이더가 아님: 처음 자리에서 다시 보여 줌
    static func unlock() {
        DispatchQueue.main.async {
            guard locked else { return }
            if hidden {
                if let a = anchor { CGWarpMouseCursorPosition(a) }
                CGDisplayShowCursor(CGMainDisplayID()); hidden = false
            }
            locked = false; anchor = nil
        }
    }

    /// 앱 시작 때 한 번
    static func install() {
        // 포인터를 되돌린 뒤에도 마우스가 바로 반응하게
        CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0
        // 뒤에서 도는 앱도 포인터를 숨길 수 있게 (macOS 비공개 설정)
        typealias DefaultConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        let h = dlopen(nil, RTLD_NOW)
        if let c = dlsym(h, "_CGSDefaultConnection"), let s = dlsym(h, "CGSSetConnectionProperty") {
            let conn = unsafeBitCast(c, to: DefaultConnection.self)()
            _ = unsafeBitCast(s, to: SetProperty.self)(conn, conn, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        }
    }
}
