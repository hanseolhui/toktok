import Foundation
import CMultitouch

// MARK: - Gestures

/// Gestures recognized by TokTok's free engine.
public enum Gesture: String, CaseIterable, Sendable {
    /// Rest 1 / 2 / 3 fingers, tap with a finger to the left or right of them.
    case tipTapLeft, tipTapRight
    case twoFixTapLeft, twoFixTapRight, twoFixTapMiddle
    case threeFixTapLeft, threeFixTapRight
    /// Tap with several fingers at once.
    case threeFingerTap, fourFingerTap, fiveFingerTap
    /// One-finger tap in a corner or at the top-center edge.
    case cornerTopLeft, cornerTopRight, cornerBottomLeft, cornerBottomRight, edgeTopCenter
    /// Swipe from the bottom-right corner toward the center.
    case swipeInBottomRight
}

/// Trackpad edges usable as sliders.
public enum EdgeSide: String, CaseIterable, Sendable {
    case left, right, top, bottom
    /// Top and bottom edges slide sideways; left and right slide up and down.
    public var horizontal: Bool { self == .top || self == .bottom }
}

public enum GestureEvent: Sendable {
    case gesture(Gesture)
    /// One step on an edge slider (`up` = up or to the right).
    case slider(EdgeSide, up: Bool)
}

// MARK: - Tuning

/// Thresholds, in seconds and normalized trackpad units (width = 1.0).
public enum Tuning {
    public static var tapMaxDuration = 0.30
    public static var tapMaxMove: Float = 0.04
    /// The resting finger must land this much earlier — separates rest-and-tap from a two-finger tap (right click).
    public static var anchorMinLead = 0.12
    public static var anchorMaxMove: Float = 0.04
    public static var multiTapLandWindow = 0.12
    public static var multiTapMaxDuration = 0.35
    public static var cornerMaxDuration = 0.25
    public static var cornerX: Float = 0.15
    public static var cornerY: Float = 0.2
    public static var edgeCenterHalfWidth: Float = 0.15
    public static var minInterval = 0.08
    public static var edgeWidth: Float = 0.07
    public static var edgeHeight: Float = 0.09
    public static var sliderStep: Float = 0.05
    public static var sliderStepX: Float = 0.035
    public static var sliderMaxSideMove: Float = 0.08
    public static var sliderStart: Float = 0.012
    public static var swipeInMin: Float = 0.12
    public static var swipeInMaxDuration = 0.6
}

// MARK: - Detector

/// Turns raw multitouch frames from one trackpad into `GestureEvent`s.
/// One instance per device so fingers on different trackpads never mix.
public final class GestureDetector {
    // Shared configuration — read by the multitouch thread, written by the app: guarded by a lock.
    private static let configLock = NSLock()
    private static var _handler: ((GestureEvent) -> Void)?
    private static var _sliders: Set<EdgeSide> = []
    private static var _swipeIn = true
    private static func locked<T>(_ body: () -> T) -> T { configLock.lock(); defer { configLock.unlock() }; return body() }

    static var handler: ((GestureEvent) -> Void)? {
        get { locked { _handler } }
        set { locked { _handler = newValue } }
    }
    /// Edges that act as sliders (empty = off).
    public static var sliders: Set<EdgeSide> {
        get { locked { _sliders } }
        set { locked { _sliders = newValue } }
    }
    public static var swipeInEnabled: Bool {
        get { locked { _swipeIn } }
        set { locked { _swipeIn = newValue } }
    }

    private static let lock = NSLock()
    private static var perDevice: [Int: GestureDetector] = [:]

    static func detector(for device: UnsafeMutableRawPointer?) -> GestureDetector {
        let key = Int(bitPattern: device)
        lock.lock(); defer { lock.unlock() }
        if let d = perDevice[key] { return d }
        let d = GestureDetector(); perDevice[key] = d
        return d
    }
    static func resetDevices() { lock.lock(); perDevice = [:]; lock.unlock() }

    private struct Finger {
        let startTime: Double
        let startX: Float, startY: Float
        var x: Float, y: Float
        var maxConcurrent: Int
        /// Fingers already down when this one landed.
        var anchors: [Int32: (x: Float, y: Float, startTime: Double)]
        var moved: Float { hypot(x - startX, y - startY) }
    }

    /// From the first finger down until all fingers are up.
    private struct Session {
        var startTime = 0.0, lastLandTime = 0.0
        var fingerCount = 0, maxConcurrent = 0
        var maxMove: Float = 0
        var firstX: Float = 0, firstY: Float = 0, lastX: Float = 0, lastY: Float = 0
        var consumed = false
        var sliderCandidates: [EdgeSide] = []
        var sliderSide: EdgeSide?
        var sliderPos: Float = 0
    }

    private var fingers: [Int32: Finger] = [:]
    private var session: Session?
    private var lastFire = 0.0
    /// Handler snapshot for the current frame.
    private var emit: ((GestureEvent) -> Void)?

    func process(_ touches: UnsafeMutablePointer<MTTouch>?, count: Int, time: Double) {
        emit = Self.handler
        var current: [Int32: (x: Float, y: Float)] = [:]
        if let touches {
            for i in 0..<count {
                let t = touches[i]
                guard t.state == 3 || t.state == 4 else { continue }   // touching only
                current[Int32(t.identifier)] = (t.normalized.position.x, t.normalized.position.y)
            }
        }

        // New fingers
        for (id, p) in current where fingers[id] == nil {
            if session == nil {
                var s = Session(startTime: time, firstX: p.x, firstY: p.y)
                s.lastX = p.x; s.lastY = p.y
                let sl = Self.sliders
                if p.x < Tuning.edgeWidth, sl.contains(.left) { s.sliderCandidates.append(.left) }
                if p.x > 1 - Tuning.edgeWidth, sl.contains(.right) { s.sliderCandidates.append(.right) }
                if p.y > 1 - Tuning.edgeHeight, sl.contains(.top) { s.sliderCandidates.append(.top) }
                if p.y < Tuning.edgeHeight, sl.contains(.bottom) { s.sliderCandidates.append(.bottom) }
                session = s
            }
            var anchors: [Int32: (x: Float, y: Float, startTime: Double)] = [:]
            for (aid, a) in fingers where current[aid] != nil { anchors[aid] = (a.x, a.y, a.startTime) }
            fingers[id] = Finger(startTime: time, startX: p.x, startY: p.y, x: p.x, y: p.y,
                                 maxConcurrent: current.count, anchors: anchors)
            session?.fingerCount += 1
            session?.lastLandTime = time
        }

        // Positions
        for (id, p) in current {
            guard var f = fingers[id] else { continue }
            f.x = p.x; f.y = p.y
            f.maxConcurrent = max(f.maxConcurrent, current.count)
            fingers[id] = f
        }
        if var s = session {
            s.maxConcurrent = max(s.maxConcurrent, current.count)
            if current.count == 1, let p = current.values.first { s.lastX = p.x; s.lastY = p.y }
            session = s
        }

        trackSlider(current)

        // Lifted fingers
        let lifted = fingers.filter { current[$0.key] == nil }
        for id in lifted.keys { fingers[id] = nil }
        for (_, f) in lifted {
            if var s = session { s.maxMove = max(s.maxMove, f.moved); session = s }
            evaluateTipTap(f, time: time)
        }

        if fingers.isEmpty, let s = session {
            evaluateSession(s, time: time)
            session = nil
        }
    }

    // One finger along an edge: one step per `sliderStep` of travel.
    private func trackSlider(_ current: [Int32: (x: Float, y: Float)]) {
        guard var s = session, !s.sliderCandidates.isEmpty else { return }
        guard s.fingerCount == 1, current.count == 1, let p = current.values.first else {
            if current.count > 1 { s.sliderCandidates = []; session = s }
            return
        }
        let mx = abs(p.x - s.firstX), my = abs(p.y - s.firstY)
        if s.sliderSide == nil {
            guard max(mx, my) >= Tuning.sliderStart else { return }
            // In a corner both edges qualify — the direction of movement decides.
            let vertical = my > mx
            guard let side = s.sliderCandidates.first(where: { $0.horizontal != vertical }) else {
                s.sliderCandidates = []; session = s; return
            }
            s.sliderSide = side
            s.sliderPos = side.horizontal ? s.firstX : s.firstY
        }
        guard let side = s.sliderSide else { return }
        guard (side.horizontal ? my : mx) <= Tuning.sliderMaxSideMove else {
            s.sliderCandidates = []; s.sliderSide = nil; session = s; return
        }
        let value = side.horizontal ? p.x : p.y
        let step = side.horizontal ? Tuning.sliderStepX : Tuning.sliderStep
        var d = value - s.sliderPos
        while abs(d) >= step {
            let up = d > 0
            s.sliderPos += up ? step : -step
            d = value - s.sliderPos
            s.consumed = true
            emit?(.slider(side, up: up))
        }
        session = s
    }

    // Rest 1–3 fingers and tap beside (or between) them.
    private func evaluateTipTap(_ f: Finger, time: Double) {
        guard (1...3).contains(f.anchors.count) else { return }
        guard time - f.startTime <= Tuning.tapMaxDuration, f.moved <= Tuning.tapMaxMove,
              f.maxConcurrent == f.anchors.count + 1,
              Set(fingers.keys) == Set(f.anchors.keys) else { return }
        for (aid, a) in f.anchors {
            guard f.startTime - a.startTime >= Tuning.anchorMinLead,
                  let now = fingers[aid], hypot(now.x - a.x, now.y - a.y) <= Tuning.anchorMaxMove else { return }
        }
        let xs = f.anchors.values.map(\.x)
        let g: Gesture
        if f.startX < xs.min()! { g = [.tipTapLeft, .twoFixTapLeft, .threeFixTapLeft][f.anchors.count - 1] }
        else if f.startX > xs.max()! { g = [.tipTapRight, .twoFixTapRight, .threeFixTapRight][f.anchors.count - 1] }
        else if f.anchors.count == 2 { g = .twoFixTapMiddle }
        else { return }
        session?.consumed = true
        fire(g, time: time)
    }

    // After all fingers lift: multi-finger taps, corner taps, swipe-in.
    private func evaluateSession(_ s: Session, time: Double) {
        guard !s.consumed else { return }
        let duration = time - s.startTime
        let n = s.fingerCount

        if n == 1, Self.swipeInEnabled, duration <= Tuning.swipeInMaxDuration,
           s.firstX > 1 - Tuning.cornerX, s.firstY < Tuning.cornerY,
           s.firstX - s.lastX >= Tuning.swipeInMin, s.lastY - s.firstY >= Tuning.swipeInMin {
            return fire(.swipeInBottomRight, time: time)
        }

        guard n == s.maxConcurrent, s.maxMove <= Tuning.tapMaxMove else { return }
        if n >= 3 {
            guard duration <= Tuning.multiTapMaxDuration,
                  s.lastLandTime - s.startTime <= Tuning.multiTapLandWindow else { return }
            if n == 3 { fire(.threeFingerTap, time: time) }
            if n == 4 { fire(.fourFingerTap, time: time) }
            if n == 5 { fire(.fiveFingerTap, time: time) }
        } else if n == 1, duration <= Tuning.cornerMaxDuration {
            let left = s.firstX < Tuning.cornerX, right = s.firstX > 1 - Tuning.cornerX
            let bottom = s.firstY < Tuning.cornerY, top = s.firstY > 1 - Tuning.cornerY
            switch (left, right, top, bottom) {
            case (true, _, true, _):  fire(.cornerTopLeft, time: time)
            case (_, true, true, _):  fire(.cornerTopRight, time: time)
            case (true, _, _, true):  fire(.cornerBottomLeft, time: time)
            case (_, true, _, true):  fire(.cornerBottomRight, time: time)
            case (false, false, true, _) where abs(s.firstX - 0.5) <= Tuning.edgeCenterHalfWidth:
                fire(.edgeTopCenter, time: time)
            default: break
            }
        }
    }

    private func fire(_ g: Gesture, time: Double) {
        guard time - lastFire >= Tuning.minInterval else { return }
        lastFire = time
        emit?(.gesture(g))
    }
}
