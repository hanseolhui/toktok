import CoreGraphics
import Foundation

/// 가장자리 슬라이더를 쓰는 동안 포인터가 움직이지 않게 (포인터 이동 이벤트를 잠시 버림)
enum PointerLock {
    /// 켜져 있으면 포인터 이동을 막음 (멀티터치 콜백 스레드에서 켜고 끔)
    static var active = false
    private static var tap: CFMachPort?
    static var installed: Bool { tap != nil }

    /// 앱 시작 때 한 번 (손쉬운 사용 권한 필요)
    static func install() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = PointerLock.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            return PointerLock.active ? nil : Unmanaged.passUnretained(event)
        }, userInfo: nil)
        guard let tap else { Log.write("포인터 잠금 설치 실패 (손쉬운 사용 권한 확인)"); return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
