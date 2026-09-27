import Foundation
import CoreGraphics

// MARK: - 제스처 종류

enum Gesture: String, CaseIterable, Codable, Identifiable {
    case tipTapLeft, tipTapRight
    case twoFixTapLeft, twoFixTapRight
    case threeFingerTap, fourFingerTap, fiveFingerTap
    case cornerTopLeft, cornerTopRight, cornerBottomLeft, cornerBottomRight
    case edgeTopCenter
    /// 오른쪽 아래 모서리에서 안쪽으로 쓸기
    case swipeInBottomRight
    /// 투탭 (Pro): 모서리·위쪽 가운데를 두 번 톡
    case doubleTopLeft, doubleTopRight, doubleBottomLeft, doubleBottomRight, doubleTopCenter
    case doubleThreeFinger, doubleFourFinger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tipTapLeft:        return t("한 손가락 대고 왼쪽 톡", "One finger rest, tap left")
        case .tipTapRight:       return t("한 손가락 대고 오른쪽 톡", "One finger rest, tap right")
        case .twoFixTapLeft:     return t("두 손가락 대고 왼쪽 톡", "Two fingers rest, tap left")
        case .twoFixTapRight:    return t("두 손가락 대고 오른쪽 톡", "Two fingers rest, tap right")
        case .threeFingerTap:    return t("세 손가락 탭", "Three-finger tap")
        case .fourFingerTap:     return t("네 손가락 탭", "Four-finger tap")
        case .fiveFingerTap:     return t("다섯 손가락 탭", "Five-finger tap")
        case .cornerTopLeft:     return t("왼쪽 위 모서리 톡", "Top-left corner tap")
        case .cornerTopRight:    return t("오른쪽 위 모서리 톡", "Top-right corner tap")
        case .cornerBottomLeft:  return t("왼쪽 아래 모서리 톡", "Bottom-left corner tap")
        case .cornerBottomRight: return t("오른쪽 아래 모서리 톡", "Bottom-right corner tap")
        case .edgeTopCenter:     return t("위쪽 가운데 톡", "Top-center tap")
        case .swipeInBottomRight: return t("오른쪽 아래에서 안쪽으로 쓸기", "Swipe in from bottom-right")
        case .doubleTopLeft:     return t("왼쪽 위 모서리 투탭", "Top-left corner double tap")
        case .doubleTopRight:    return t("오른쪽 위 모서리 투탭", "Top-right corner double tap")
        case .doubleBottomLeft:  return t("왼쪽 아래 모서리 투탭", "Bottom-left corner double tap")
        case .doubleBottomRight: return t("오른쪽 아래 모서리 투탭", "Bottom-right corner double tap")
        case .doubleTopCenter:   return t("위쪽 가운데 투탭", "Top-center double tap")
        case .doubleThreeFinger: return t("세 손가락 투탭", "Three-finger double tap")
        case .doubleFourFinger:  return t("네 손가락 투탭", "Four-finger double tap")
        }
    }

    var hint: String {
        switch self {
        case .tipTapLeft:     return t("오른손 중지를 대고 검지를 톡", "Rest right middle finger, tap index")
        case .tipTapRight:    return t("오른손 검지를 대고 중지를 톡", "Rest right index finger, tap middle")
        case .twoFixTapLeft:  return t("중지·약지를 대고 검지를 톡", "Rest middle + ring, tap index")
        case .twoFixTapRight: return t("검지·중지를 대고 약지를 톡", "Rest index + middle, tap ring")
        case .threeFingerTap: return t("세 손가락으로 동시에 톡", "Tap with three fingers at once")
        case .fourFingerTap:  return t("네 손가락으로 동시에 톡", "Tap with four fingers at once")
        case .fiveFingerTap:  return t("다섯 손가락으로 동시에 톡", "Tap with five fingers at once")
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return t("한 손가락으로 모서리를 톡 (탭하여 클릭을 켜 두면 클릭도 함께 돼요)", "Tap a corner with one finger (also clicks if Tap to click is on)")
        case .edgeTopCenter:
            return t("한 손가락으로 트랙패드 위쪽 가운데를 톡", "Tap the top-center edge of the trackpad with one finger")
        case .swipeInBottomRight:
            return t("오른쪽 아래 모서리에 대고 가운데 쪽으로 쓱", "Start at the bottom-right corner and swipe toward the center")
        case .doubleTopLeft, .doubleTopRight, .doubleBottomLeft, .doubleBottomRight, .doubleTopCenter, .doubleThreeFinger, .doubleFourFinger:
            return t("같은 곳을 빠르게 두 번 톡 (켜면 그 자리 한 번 톡은 조금 늦게 실행돼요)",
                     "Tap the same spot twice quickly (single tap there runs slightly later)")
        }
    }

    /// Pro 전용 제스처
    var isPro: Bool { group == .double }

    /// 투탭 제스처의 한 번 톡 짝
    var doubleTap: Gesture? {
        switch self {
        case .cornerTopLeft:     return .doubleTopLeft
        case .cornerTopRight:    return .doubleTopRight
        case .cornerBottomLeft:  return .doubleBottomLeft
        case .cornerBottomRight: return .doubleBottomRight
        case .edgeTopCenter:     return .doubleTopCenter
        case .threeFingerTap:    return .doubleThreeFinger
        case .fourFingerTap:     return .doubleFourFinger
        default: return nil
        }
    }

    enum Group: String, CaseIterable {
        case tipTap, tap, corner, double
        var title: String {
            switch self {
            case .tipTap: return t("대고 톡", "Rest & tap")
            case .tap:    return t("여러 손가락 탭", "Multi-finger tap")
            case .corner: return t("모서리·가장자리", "Corners & edges")
            case .double: return t("⭐ 투탭 (Pro)", "⭐ Double tap (Pro)")
            }
        }
    }
    var group: Group {
        switch self {
        case .tipTapLeft, .tipTapRight, .twoFixTapLeft, .twoFixTapRight: return .tipTap
        case .threeFingerTap, .fourFingerTap, .fiveFingerTap: return .tap
        case .doubleTopLeft, .doubleTopRight, .doubleBottomLeft, .doubleBottomRight, .doubleTopCenter,
             .doubleThreeFinger, .doubleFourFinger: return .double
        default: return .corner
        }
    }

    /// 기본 설정 (기본으로 켜 두는 건 실수로 눌러도 부담 없는 것만)
    var defaultSetting: GestureSetting {
        switch self {
        case .tipTapLeft:        return .init(enabled: true,  action: .preset(.back))
        case .tipTapRight:       return .init(enabled: true,  action: .preset(.forward))
        case .twoFixTapLeft:     return .init(enabled: false, action: .preset(.prevTab))
        case .twoFixTapRight:    return .init(enabled: false, action: .preset(.nextTab))
        case .threeFingerTap:    return .init(enabled: true,  action: .preset(.middleClick))
        case .fourFingerTap:     return .init(enabled: false, action: .preset(.closeTab))
        case .fiveFingerTap:     return .init(enabled: false, action: .preset(.missionControl))
        case .cornerTopLeft:     return .init(enabled: false, action: .preset(.windowLeft))
        case .cornerTopRight:    return .init(enabled: false, action: .preset(.windowRight))
        case .cornerBottomLeft:  return .init(enabled: false, action: .preset(.missionControl))
        case .cornerBottomRight: return .init(enabled: false, action: .preset(.windowFill))
        case .edgeTopCenter:     return .init(enabled: false, action: .preset(.windowFill))
        case .swipeInBottomRight: return .init(enabled: false, action: .preset(.newNote))
        case .doubleTopLeft:     return .init(enabled: false, action: .preset(.quarterTopLeft))
        case .doubleTopRight:    return .init(enabled: false, action: .preset(.quarterTopRight))
        case .doubleBottomLeft:  return .init(enabled: false, action: .preset(.quarterBottomLeft))
        case .doubleBottomRight: return .init(enabled: false, action: .preset(.quarterBottomRight))
        case .doubleTopCenter:   return .init(enabled: false, action: .preset(.windowNextScreen))
        case .doubleThreeFinger: return .init(enabled: false, action: .preset(.screenshot))
        case .doubleFourFinger:  return .init(enabled: false, action: .preset(.newTab))
        }
    }
}

/// 가장자리 슬라이더 (왼쪽·오른쪽 끝은 위아래로, 위쪽·아래쪽 끝은 좌우로 쓸기)
enum EdgeSide: String, CaseIterable, Codable, Identifiable {
    case left, right, top, bottom
    var id: String { rawValue }
    /// 좌우로 쓰는 가장자리 (위쪽·아래쪽)
    var horizontal: Bool { self == .top || self == .bottom }
    var title: String {
        switch self {
        case .left:   return t("왼쪽 끝 (위아래로)", "Left edge (up/down)")
        case .right:  return t("오른쪽 끝 (위아래로)", "Right edge (up/down)")
        case .top:    return t("위쪽 끝 (좌우로)", "Top edge (sideways)")
        case .bottom: return t("아래쪽 끝 (좌우로)", "Bottom edge (sideways)")
        }
    }
}

/// 슬라이더로 조절할 것 (가로 스크롤·확대/축소·직접 입력은 Pro)
enum SliderMode: Codable, Equatable {
    case volume, brightness, hScroll, zoom
    /// 위로 / 아래로 쓸 때 누를 단축키
    case custom(up: [Shortcut], down: [Shortcut])

    static let presets: [SliderMode] = [.volume, .brightness, .hScroll, .zoom]

    var isPro: Bool { switch self { case .volume, .brightness: return false; default: return true } }

    var title: String {
        switch self {
        case .volume:     return t("볼륨", "Volume")
        case .brightness: return t("화면 밝기", "Brightness")
        case .hScroll:    return t("가로 스크롤 (타임라인)", "Horizontal scroll (timelines)")
        case .zoom:       return t("확대 / 축소  ⌘+ ⌘−", "Zoom in / out  ⌘+ ⌘−")
        case .custom(let u, let d):
            return t("단축키  ", "Shortcut  ") + "↑ " + u.map(\.display).joined(separator: " → ") + "  ↓ " + d.map(\.display).joined(separator: " → ")
        }
    }

    /// 한 칸 (up: 위로 · 오른쪽으로 쓸기)
    func step(up: Bool) {
        switch self {
        case .volume:     Keys.mediaKey(up ? Keys.soundUp : Keys.soundDown)
        case .brightness: Keys.mediaKey(up ? Keys.brightnessUp : Keys.brightnessDown)
        case .hScroll:    Keys.scrollHorizontally(up ? 60 : -60)
        case .zoom:       Keys.press(up ? Keys.equal : Keys.minus, [.maskCommand])
        case .custom(let u, let d): Action.keys(up ? u : d).perform()
        }
    }
}

struct SliderSetting: Codable, Equatable {
    var enabled: Bool
    var mode: SliderMode
    static func `default`(_ side: EdgeSide) -> SliderSetting {
        .init(enabled: false, mode: side == .left || side == .bottom ? .brightness : .volume)
    }
}

// MARK: - 인식 기준

enum Tuning {
    /// 톡 치는 손가락이 닿아 있는 최대 시간(초)
    static let tapMaxDuration = 0.30
    /// 톡 치는 손가락이 움직여도 되는 최대 거리 (트랙패드 폭 = 1.0)
    static let tapMaxMove: Float = 0.04
    /// 대고 있는 손가락이 톡 치는 손가락보다 최소 이만큼 먼저 닿아 있어야 함(초) — 두 손가락 탭(우클릭)과 구분
    static let anchorMinLead = 0.12
    /// 톡 치는 동안 대고 있는 손가락이 움직여도 되는 최대 거리 — 스크롤·드래그와 구분
    static let anchorMaxMove: Float = 0.04
    /// 여러 손가락 탭: 첫 손가락과 마지막 손가락이 닿는 시간 차 최대(초)
    static let multiTapLandWindow = 0.12
    /// 여러 손가락 탭 / 모서리 톡: 전체가 끝나기까지 최대 시간(초)
    static let multiTapMaxDuration = 0.35
    static let cornerMaxDuration = 0.25
    /// 모서리로 볼 범위 (가로, 세로 비율)
    static let cornerX: Float = 0.15
    static let cornerY: Float = 0.2
    /// 위쪽 가운데로 볼 가로 범위 (가운데에서 좌우로)
    static let edgeCenterHalfWidth: Float = 0.15
    /// 연속 입력 사이 최소 간격(초)
    static let minInterval = 0.08
    /// 투탭: 두 번째 톡을 기다리는 시간(초) · 두 톡 사이 허용 거리
    static let doubleTapWindow = 0.28
    static let doubleTapMaxDistance: Float = 0.12
    /// 가장자리 슬라이더: 가장자리 폭 · 한 칸 이동 거리 · 옆으로 벗어나도 되는 거리
    static let edgeWidth: Float = 0.07
    static let edgeHeight: Float = 0.09
    /// 좌우로 쓰는 슬라이더의 한 칸 (트랙패드가 가로로 길어서 조금 작게)
    static let sliderStepX: Float = 0.035
    static let sliderStep: Float = 0.05
    static let sliderMaxSideMove: Float = 0.08
    /// 이만큼 위아래로 움직이면 슬라이더로 보고 포인터를 붙잡음
    static let sliderHoldStart: Float = 0.012
    /// 안쪽으로 쓸기: 최소 이동 거리(가로·세로 각각) · 최대 시간
    static let swipeInMin: Float = 0.12
    static let swipeInMaxDuration = 0.6
    /// 스와이프 앱 전환: 한 칸 이동 거리
    static let appSwitchStep: Float = 0.08
}

// MARK: - 제스처 감지 (멀티터치 콜백 스레드에서 실행)

final class GestureDetector {
    /// 설정·콜백을 가진 대표 인스턴스 (트랙패드마다 따로 만든 인식기가 이걸 봄)
    static let shared = GestureDetector()

    /// 트랙패드마다 따로 인식 (여러 트랙패드의 손가락이 섞이지 않게)
    private static let devicesLock = NSLock()
    private static var perDevice: [Int: GestureDetector] = [:]
    static func detector(for device: UnsafeMutableRawPointer?) -> GestureDetector {
        let key = Int(bitPattern: device)
        devicesLock.lock(); defer { devicesLock.unlock() }
        if let d = perDevice[key] { return d }
        let d = GestureDetector(); perDevice[key] = d
        return d
    }
    static func resetDevices() { devicesLock.lock(); perDevice = [:]; devicesLock.unlock(); PointerLock.unlock() }

    /// 인식된 제스처 (콜백 스레드에서 호출됨)
    var onGesture: ((Gesture) -> Void)?
    /// 가장자리 슬라이더 한 칸 (up: 위로)
    var onSlider: ((EdgeSide, Bool) -> Void)?
    /// 스와이프 앱 전환: +1 다음 앱 / -1 이전 앱, 0 은 끝 (⌘ 떼기)
    var onAppSwitch: ((Int) -> Void)?

    /// 켜져 있는 추가 제스처 (메인 스레드의 설정을 콜백 스레드에서 읽도록 복사해 둠)
    struct Config {
        var doubleTaps: Set<Gesture> = []
        var sliders: Set<EdgeSide> = []
        var swipeIn = false
        var appSwitch = false
    }
    private let lock = NSLock()
    private var _config = Config()
    /// 설정은 대표 인스턴스에 한 곳만
    var config: Config {
        get { let s = GestureDetector.shared; s.lock.lock(); defer { s.lock.unlock() }; return s._config }
        set { let s = GestureDetector.shared; s.lock.lock(); s._config = newValue; s.lock.unlock() }
    }
    private var hub: GestureDetector { GestureDetector.shared }

    private struct Finger {
        let startTime: Double
        let startX: Float, startY: Float
        var x: Float, y: Float
        /// 이 손가락이 닿아 있는 동안 동시에 닿았던 손가락 수의 최댓값
        var maxConcurrent: Int
        /// 이 손가락이 닿을 때 이미 닿아 있던 손가락들과 그 위치
        var anchors: [Int32: (x: Float, y: Float, startTime: Double)]
        var moved: Float { hypot(x - startX, y - startY) }
    }

    /// 손가락이 하나도 없다가 닿기 시작해서 모두 떨어질 때까지
    private struct Session {
        var startTime = 0.0
        var lastLandTime = 0.0
        var fingerCount = 0
        var maxConcurrent = 0
        var maxMove: Float = 0
        var firstX: Float = 0, firstY: Float = 0
        var lastX: Float = 0, lastY: Float = 0
        var consumed = false
        /// 가장자리 슬라이더: 마지막으로 한 칸 움직인 높이
        /// 시작한 곳의 가장자리 후보 (모서리면 둘) → 움직이는 방향으로 하나를 고름
        var sliderCandidates: [EdgeSide] = []
        var sliderSide: EdgeSide?
        var sliderY: Float = 0
        /// 스와이프 앱 전환 중: 기준 가로 위치
        var switchBaseX: Float?
        var switching = false
    }

    private var fingers: [Int32: Finger] = [:]
    private var session: Session?
    private var lastFire = 0.0
    /// 투탭: 첫 번째 톡 (두 번째를 기다리는 중)
    private var pendingTap: (gesture: Gesture, time: Double, x: Float, y: Float, token: Int, second: Bool)?
    private var tapToken = 0

    func process(_ touches: UnsafeMutablePointer<MTTouch>?, count: Int, time: Double) {
        var current: [Int32: (x: Float, y: Float)] = [:]
        if let touches {
            for i in 0..<count {
                let t = touches[i]
                guard t.state == 3 || t.state == 4 else { continue } // 실제로 닿아 있는 손가락만
                current[Int32(t.identifier)] = (t.normalized.position.x, t.normalized.position.y)
            }
        }
        let cfg = config

        // 새로 닿은 손가락
        for (id, p) in current where fingers[id] == nil {
            if session == nil {
                // 투탭 대기 중에 다시 닿으면 (두 번째 톡일 수 있음) 한 번 톡 실행을 미룸
                lock.lock()
                if let pt = pendingTap, time - pt.time <= Tuning.doubleTapWindow { pendingTap?.second = true }
                lock.unlock()
                var s = Session(startTime: time, firstX: p.x, firstY: p.y)
                s.lastX = p.x; s.lastY = p.y
                if p.x < Tuning.edgeWidth, cfg.sliders.contains(.left) { s.sliderCandidates.append(.left) }
                if p.x > 1 - Tuning.edgeWidth, cfg.sliders.contains(.right) { s.sliderCandidates.append(.right) }
                if p.y > 1 - Tuning.edgeHeight, cfg.sliders.contains(.top) { s.sliderCandidates.append(.top) }
                if p.y < Tuning.edgeHeight, cfg.sliders.contains(.bottom) { s.sliderCandidates.append(.bottom) }
                // 오른쪽 아래에서 쓸기(빠른 메모)가 켜져 있으면 그 모서리는 쓸기에 양보
                if cfg.swipeIn, p.x > 1 - Tuning.cornerX, p.y < Tuning.cornerY { s.sliderCandidates = [] }
                // 가장자리에 닿은 순간부터 포인터를 잠가 둠 (슬라이더가 아니면 바로 풂)
                if !s.sliderCandidates.isEmpty { PointerLock.lock() }
                session = s
            }
            var anchors: [Int32: (x: Float, y: Float, startTime: Double)] = [:]
            for (aid, a) in fingers where current[aid] != nil { anchors[aid] = (a.x, a.y, a.startTime) }
            fingers[id] = Finger(startTime: time, startX: p.x, startY: p.y, x: p.x, y: p.y,
                                 maxConcurrent: current.count, anchors: anchors)
            session?.fingerCount += 1
            session?.lastLandTime = time
        }

        // 위치 갱신
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
        if cfg.appSwitch { trackAppSwitch(current) }

        // 떨어진 손가락
        let lifted = fingers.filter { current[$0.key] == nil }
        for id in lifted.keys { fingers[id] = nil }
        for (_, f) in lifted {
            if var s = session { s.maxMove = max(s.maxMove, f.moved); session = s }
            evaluateTipTap(f, time: time)
        }

        if fingers.isEmpty, let s = session {
            if s.switching { hub.onAppSwitch?(0) }
            evaluateSession(s, time: time)
            session = nil
        }
    }

    // 가장자리 한 손가락을 쓸기: 한 칸씩 조절 (왼쪽·오른쪽 끝은 위아래, 위쪽·아래쪽 끝은 좌우)
    private func trackSlider(_ current: [Int32: (x: Float, y: Float)]) {
        guard var s = session, !s.sliderCandidates.isEmpty else { return }
        // 손가락이 더 닿으면 슬라이더가 아님
        guard s.fingerCount == 1, current.count == 1, let p = current.values.first else {
            if current.count > 1 { s.sliderCandidates = []; PointerLock.unlock(); session = s }
            return
        }
        let mx = abs(p.x - s.firstX), my = abs(p.y - s.firstY)

        // 어느 가장자리인지: 움직이기 시작한 방향으로 결정
        if s.sliderSide == nil {
            guard max(mx, my) >= Tuning.sliderHoldStart else { return }
            let vertical = my > mx
            guard let side = s.sliderCandidates.first(where: { $0.horizontal != vertical }) else {
                s.sliderCandidates = []; PointerLock.unlock(); session = s; return
            }
            s.sliderSide = side
            s.sliderY = side.horizontal ? s.firstX : s.firstY
        }
        guard let side = s.sliderSide else { return }

        // 쓰는 방향에서 옆으로 크게 벗어나면 슬라이더가 아님
        let across = side.horizontal ? my : mx
        guard across <= Tuning.sliderMaxSideMove else {
            s.sliderCandidates = []; s.sliderSide = nil; PointerLock.unlock()
            session = s; return
        }
        PointerLock.hold()
        let value = side.horizontal ? p.x : p.y
        let step = side.horizontal ? Tuning.sliderStepX : Tuning.sliderStep
        var d = value - s.sliderY
        while abs(d) >= step {
            let up = d > 0
            s.sliderY += up ? step : -step
            d = value - s.sliderY
            s.consumed = true
            hub.onSlider?(side, up)
        }
        session = s
    }

    // 한 손가락을 대고 두 손가락을 좌우로: 앱 전환 (⌘Tab)
    private func trackAppSwitch(_ current: [Int32: (x: Float, y: Float)]) {
        guard var s = session else { return }
        guard current.count == 3 else { return }
        // 가장 먼저 닿아 가만히 있는 손가락이 기준, 나머지 두 손가락이 움직임
        let ordered = current.keys.compactMap { id in fingers[id].map { (id, $0) } }.sorted { $0.1.startTime < $1.1.startTime }
        guard ordered.count == 3 else { return }
        let anchor = ordered[0].1, movers = ordered[1...].map(\.1)
        guard movers.allSatisfy({ $0.startTime - anchor.startTime >= Tuning.anchorMinLead }),
              anchor.moved <= Tuning.anchorMaxMove else { return }
        let x = movers.map(\.x).reduce(0, +) / 2
        guard let base = s.switchBaseX else { s.switchBaseX = x; session = s; return }
        let dx = x - base
        if abs(dx) >= Tuning.appSwitchStep {
            s.switchBaseX = base + (dx > 0 ? Tuning.appSwitchStep : -Tuning.appSwitchStep)
            s.switching = true; s.consumed = true
            hub.onAppSwitch?(dx > 0 ? 1 : -1)
        }
        session = s
    }

    // 한/두 손가락을 대고 옆을 톡
    private func evaluateTipTap(_ f: Finger, time: Double) {
        guard (1...2).contains(f.anchors.count), session?.switching != true else { return }
        let duration = time - f.startTime
        func reject(_ why: String) {
            Log.write(String(format: "대고 톡 무시(%@) 시간=%.2fs 이동=%.3f", why, duration, f.moved))
        }
        guard duration <= Tuning.tapMaxDuration else { return reject("길게 누름") }
        guard f.moved <= Tuning.tapMaxMove else { return reject("움직임") }
        guard f.maxConcurrent == f.anchors.count + 1 else { return reject("손가락 \(f.maxConcurrent)개") }
        guard Set(fingers.keys) == Set(f.anchors.keys) else { return reject("대고 있는 손가락이 바뀜") }
        for (aid, a) in f.anchors {
            guard f.startTime - a.startTime >= Tuning.anchorMinLead else { return reject("동시에 닿음") }
            guard let now = fingers[aid], hypot(now.x - a.x, now.y - a.y) <= Tuning.anchorMaxMove else {
                return reject("대고 있는 손가락 움직임")
            }
        }
        let xs = f.anchors.values.map(\.x)
        let left: Bool
        if f.startX < xs.min()! { left = true }
        else if f.startX > xs.max()! { left = false }
        else { return reject("가운데") }

        let g: Gesture = f.anchors.count == 1 ? (left ? .tipTapLeft : .tipTapRight)
                                              : (left ? .twoFixTapLeft : .twoFixTapRight)
        session?.consumed = true
        fire(g, time: time)
    }

    // 모든 손가락이 떨어진 뒤: 여러 손가락 탭, 모서리 톡, 안쪽으로 쓸기
    private func evaluateSession(_ s: Session, time: Double) {
        PointerLock.unlock()
        guard !s.consumed else { return }
        let duration = time - s.startTime
        let n = s.fingerCount

        // 오른쪽 아래 모서리에서 안쪽(왼쪽 위)으로 쓸기
        if n == 1, config.swipeIn, duration <= Tuning.swipeInMaxDuration,
           s.firstX > 1 - Tuning.cornerX, s.firstY < Tuning.cornerY,
           s.firstX - s.lastX >= Tuning.swipeInMin, s.lastY - s.firstY >= Tuning.swipeInMin {
            return fire(.swipeInBottomRight, time: time)
        }

        guard n == s.maxConcurrent, s.maxMove <= Tuning.tapMaxMove else { return }

        if n >= 3 {
            guard duration <= Tuning.multiTapMaxDuration,
                  s.lastLandTime - s.startTime <= Tuning.multiTapLandWindow else { return }
            if n == 3 { zoneTap(.threeFingerTap, time: time, x: 0, y: 0) }
            if n == 4 { zoneTap(.fourFingerTap, time: time, x: 0, y: 0) }
            if n == 5 { fire(.fiveFingerTap, time: time) }
        } else if n == 1, duration <= Tuning.cornerMaxDuration {
            let left = s.firstX < Tuning.cornerX, right = s.firstX > 1 - Tuning.cornerX
            let bottom = s.firstY < Tuning.cornerY, top = s.firstY > 1 - Tuning.cornerY
            let g: Gesture?
            switch (left, right, top, bottom) {
            case (true, _, true, _):  g = .cornerTopLeft
            case (_, true, true, _):  g = .cornerTopRight
            case (true, _, _, true):  g = .cornerBottomLeft
            case (_, true, _, true):  g = .cornerBottomRight
            case (false, false, true, _) where abs(s.firstX - 0.5) <= Tuning.edgeCenterHalfWidth: g = .edgeTopCenter
            default: g = nil
            }
            guard let g else { return }
            zoneTap(g, time: time, x: s.firstX, y: s.firstY)
        }
    }

    /// 모서리·가장자리 톡: 투탭이 켜져 있으면 두 번째 톡을 잠깐 기다림
    private func zoneTap(_ g: Gesture, time: Double, x: Float, y: Float) {
        guard let double = g.doubleTap, config.doubleTaps.contains(double) else { return fire(g, time: time) }
        lock.lock()
        if let p = pendingTap, p.gesture == g, p.second, time - p.time <= Tuning.doubleTapWindow + Tuning.cornerMaxDuration,
           hypot(x - p.x, y - p.y) <= Tuning.doubleTapMaxDistance {
            pendingTap = nil; tapToken += 1
            lock.unlock()
            return fire(double, time: time)
        }
        tapToken += 1
        let token = tapToken
        let previous = pendingTap
        pendingTap = (g, time, x, y, token, false)
        lock.unlock()
        // 기다리던 다른 톡이 있었으면 그건 한 번 톡으로 실행
        if let previous, previous.second { Log.write("✅ \(previous.gesture.title)"); hub.onGesture?(previous.gesture) }
        // 두 번째 톡이 오지 않으면 한 번 톡으로 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + Tuning.doubleTapWindow) { [weak self] in self?.flushPending(token) }
    }

    /// 기다린 뒤에도 두 번째 톡이 없으면 한 번 톡으로 실행 (두 번째 손가락이 닿았으면 그 결과를 조금 더 기다림)
    private func flushPending(_ token: Int, retry: Int = 0) {
        lock.lock()
        guard let p = pendingTap, p.token == token else { lock.unlock(); return }
        if p.second, retry < 3 {
            lock.unlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in self?.flushPending(token, retry: retry + 1) }
            return
        }
        pendingTap = nil
        lock.unlock()
        Log.write("✅ \(p.gesture.title)")
        GestureDetector.shared.onGesture?(p.gesture)
    }

    private func fire(_ g: Gesture, time: Double) {
        guard time - lastFire >= Tuning.minInterval else { return }
        lastFire = time
        Log.write("✅ \(g.title)")
        hub.onGesture?(g)
    }
}
