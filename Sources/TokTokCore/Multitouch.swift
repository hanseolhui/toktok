import Foundation
import IOKit
import CMultitouch

/// Connects to every trackpad through MultitouchSupport.framework (private, loaded with dlsym)
/// and feeds raw touch frames to one `GestureDetector` per device.
///
/// Also watches IOKit for trackpads being connected or removed (e.g. a Magic Trackpad over
/// Bluetooth) and rescans automatically. Magic Mouse surfaces are ignored.
///
/// Keep a strong reference to the instance for as long as you want gestures (e.g. a property
/// on your app delegate); touches stop when it is deallocated.
public final class Multitouch {
    private typealias CreateList = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias Register = @convention(c) (MTDeviceRef?, MTContactCallbackFunction?) -> Void
    private typealias StartDevice = @convention(c) (MTDeviceRef?, Int32) -> Void
    private typealias StopDevice = @convention(c) (MTDeviceRef?) -> Void
    private typealias FamilyID = @convention(c) (MTDeviceRef?, UnsafeMutablePointer<Int32>?) -> Int32

    private let createList: CreateList
    private let register: Register
    private let unregister: Register
    private let start: StartDevice
    private let stop: StopDevice
    private let familyID: FamilyID?

    private var devices: [MTDeviceRef] = []
    private var retained: [AnyObject] = []
    public var deviceCount: Int { devices.count }

    /// Called with each recognized gesture (on the multitouch callback thread).
    public var onEvent: ((GestureEvent) -> Void)? {
        get { GestureDetector.handler }
        set { GestureDetector.handler = newValue }
    }

    private static let callback: MTContactCallbackFunction = { device, touches, count, timestamp, _ in
        GestureDetector.detector(for: device).process(touches, count: Int(count), time: timestamp)
        return 0
    }

    public init?() {
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
        start = unsafeBitCast(s, to: StartDevice.self)
        stop = unsafeBitCast(st, to: StopDevice.self)
        familyID = dlsym(h, "MTDeviceGetFamilyID").map { unsafeBitCast($0, to: FamilyID.self) }
    }

    /// (Re)discover trackpads and start receiving touches.
    public func restart() {
        for d in devices { unregister(d, Multitouch.callback); stop(d) }
        devices = []
        GestureDetector.resetDevices()
        guard let list = createList()?.takeRetainedValue() as? [AnyObject] else { return }
        for obj in list {
            let d = Unmanaged.passUnretained(obj).toOpaque()
            if isMouse(d) { continue }
            register(d, Multitouch.callback)
            start(d, 0)
            devices.append(d)
        }
        retained = list
    }

    /// Magic Mouse reports family ID 112 / 113.
    private func isMouse(_ d: MTDeviceRef) -> Bool {
        var family: Int32 = 0
        _ = familyID?(d, &family)
        return family == 112 || family == 113
    }

    deinit {
        for d in devices { unregister(d, Multitouch.callback); stop(d) }
        for it in iterators { IOObjectRelease(it) }
        if let notifyPort { IONotificationPortDestroy(notifyPort) }
        pending?.cancel(); retry?.cancel()
    }

    // MARK: Hot-plug

    private var notifyPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var pending: DispatchWorkItem?
    private var retry: DispatchWorkItem?

    /// Rescan shortly after a multitouch device is connected or removed.
    public func watchDevices() {
        guard notifyPort == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        let me = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            while case let o = IOIteratorNext(iterator), o != 0 { IOObjectRelease(o) }
            guard let refcon else { return }
            Unmanaged<Multitouch>.fromOpaque(refcon).takeUnretainedValue().scheduleRestart()
        }
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var it: io_iterator_t = 0
            IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"), callback, me, &it)
            while case let o = IOIteratorNext(it), o != 0 { IOObjectRelease(o) }
            iterators.append(it)
        }
    }

    private func scheduleRestart() {
        pending?.cancel(); retry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restart() }
        let again = DispatchWorkItem { [weak self] in self?.restart() }
        pending = work; retry = again
        // Give the driver a moment; Bluetooth trackpads can be slow to become ready.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: again)
    }
}
