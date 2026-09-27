import Foundation

// MARK: - MultitouchSupport 연결 (비공개 프레임워크를 dlsym 으로 사용)

final class Multitouch {
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
}

