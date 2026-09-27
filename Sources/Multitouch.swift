import Foundation
import IOKit

// MARK: - MultitouchSupport 연결 (비공개 프레임워크를 dlsym 으로 사용)

final class Multitouch {
    /// 앱에서 쓰는 인스턴스 (설정 창의 문제 해결에서 사용)
    static weak var current: Multitouch?
    private typealias CreateList = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias Register = @convention(c) (MTDeviceRef?, MTContactCallbackFunction?) -> Void
    private typealias StartStop = @convention(c) (MTDeviceRef?, Int32) -> Void
    private typealias Stop = @convention(c) (MTDeviceRef?) -> Void

    private let createList: CreateList
    private let register: Register
    private let unregister: Register
    private let start: StartStop
    private let stop: Stop
    private var devices: [MTDeviceRef] = []

    private static let callback: MTContactCallbackFunction = { _, touches, count, timestamp, _ in
        GestureDetector.shared.process(touches, count: Int(count), time: timestamp)
        return 0
    }

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW),
              let c = dlsym(h, "MTDeviceCreateList"),
              let r = dlsym(h, "MTRegisterContactFrameCallback"),
              let u = dlsym(h, "MTUnregisterContactFrameCallback"),
              let s = dlsym(h, "MTDeviceStart"),
              let st = dlsym(h, "MTDeviceStop") else { return nil }
        createList = unsafeBitCast(c, to: CreateList.self)
        register = unsafeBitCast(r, to: Register.self)
        unregister = unsafeBitCast(u, to: Register.self)
        start = unsafeBitCast(s, to: StartStop.self)
        stop = unsafeBitCast(st, to: Stop.self)
    }

    /// 연결된 트랙패드를 다시 찾아 감지를 시작 (잠자기 해제·기기 연결 후 호출)
    func restart() {
        for d in devices { unregister(d, Multitouch.callback); stop(d) }
        devices = []
        guard let list = createList()?.takeRetainedValue() as? [AnyObject] else { return }
        for obj in list {
            let d = Unmanaged.passUnretained(obj).toOpaque()
            register(d, Multitouch.callback)
            start(d, 0)
            devices.append(d)
        }
        retained = list // 기기 목록을 살려 둠
        Log.write("트랙패드 \(devices.count)개 감지 시작")
    }
    private var retained: [AnyObject] = []

    var deviceCount: Int { devices.count }

    // MARK: 트랙패드 연결·해제 감지 (매직 트랙패드를 나중에 연결해도 바로 인식)

    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var pending: DispatchWorkItem?

    /// 트랙패드가 연결되거나 빠지면 잠시 뒤 다시 찾기
    func watchDevices() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        let me = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            // 알림을 다시 받으려면 목록을 끝까지 비워야 함
            while case let o = IOIteratorNext(iterator), o != 0 { IOObjectRelease(o) }
            guard let refcon else { return }
            Unmanaged<Multitouch>.fromOpaque(refcon).takeUnretainedValue().scheduleRestart()
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var it: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"), callback, me, &it)
            while case let o = IOIteratorNext(it), o != 0 { IOObjectRelease(o) }   // 이미 있는 기기는 건너뜀
            iterators.append(it)
        }
    }

    private func scheduleRestart() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.restart()
            Log.write("트랙패드 연결 변경 → 다시 찾기")
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)   // 드라이버가 준비될 시간
    }
}

