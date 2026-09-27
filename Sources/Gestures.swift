import Foundation

// MARK: - 제스처 종류

enum Gesture: String, CaseIterable, Codable, Identifiable {
    case tipTapLeft, tipTapRight
    case twoFixTapLeft, twoFixTapRight
    case threeFingerTap, fourFingerTap
    case cornerTopLeft, cornerTopRight, cornerBottomLeft, cornerBottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tipTapLeft:        return t("한 손가락 대고 왼쪽 톡", "One finger rest, tap left")
        case .tipTapRight:       return t("한 손가락 대고 오른쪽 톡", "One finger rest, tap right")
        case .twoFixTapLeft:     return t("두 손가락 대고 왼쪽 톡", "Two fingers rest, tap left")
        case .twoFixTapRight:    return t("두 손가락 대고 오른쪽 톡", "Two fingers rest, tap right")
        case .threeFingerTap:    return t("세 손가락 탭", "Three-finger tap")
        case .fourFingerTap:     return t("네 손가락 탭", "Four-finger tap")
        case .cornerTopLeft:     return t("왼쪽 위 모서리 톡", "Top-left corner tap")
        case .cornerTopRight:    return t("오른쪽 위 모서리 톡", "Top-right corner tap")
        case .cornerBottomLeft:  return t("왼쪽 아래 모서리 톡", "Bottom-left corner tap")
        case .cornerBottomRight: return t("오른쪽 아래 모서리 톡", "Bottom-right corner tap")
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
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return t("한 손가락으로 모서리를 톡 (탭하여 클릭을 켜 두면 클릭도 함께 돼요)", "Tap a corner with one finger (also clicks if Tap to click is on)")
        }
    }

    enum Group: String, CaseIterable {
        case tipTap, tap, corner
        var title: String {
            switch self {
            case .tipTap: return t("대고 톡", "Rest & tap")
            case .tap:    return t("여러 손가락 탭", "Multi-finger tap")
            case .corner: return t("모서리 톡", "Corner tap")
            }
        }
    }
    var group: Group {
        switch self {
        case .tipTapLeft, .tipTapRight, .twoFixTapLeft, .twoFixTapRight: return .tipTap
        case .threeFingerTap, .fourFingerTap: return .tap
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
        case .cornerTopLeft:     return .init(enabled: false, action: .preset(.windowLeft))
        case .cornerTopRight:    return .init(enabled: false, action: .preset(.windowRight))
        case .cornerBottomLeft:  return .init(enabled: false, action: .preset(.missionControl))
        case .cornerBottomRight: return .init(enabled: false, action: .preset(.windowFill))
        }
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
    /// 연속 입력 사이 최소 간격(초)
    static let minInterval = 0.08
}

// MARK: - 제스처 감지 (멀티터치 콜백 스레드에서 실행)

final class GestureDetector {
    static let shared = GestureDetector()

    /// 인식된 제스처 (콜백 스레드에서 호출됨)
    var onGesture: ((Gesture) -> Void)?

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
        var consumed = false
    }

    private var fingers: [Int32: Finger] = [:]
    private var session: Session?
    private var lastFire = 0.0

    func process(_ touches: UnsafeMutablePointer<MTTouch>?, count: Int, time: Double) {
        var current: [Int32: (x: Float, y: Float)] = [:]
        if let touches {
            for i in 0..<count {
                let t = touches[i]
                guard t.state == 3 || t.state == 4 else { continue } // 실제로 닿아 있는 손가락만
                current[Int32(t.identifier)] = (t.normalized.position.x, t.normalized.position.y)
            }
        }

        // 새로 닿은 손가락
        for (id, p) in current where fingers[id] == nil {
            if session == nil { session = Session(startTime: time, firstX: p.x, firstY: p.y) }
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
        if var s = session { s.maxConcurrent = max(s.maxConcurrent, current.count); session = s }

        // 떨어진 손가락
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

    // 한/두 손가락을 대고 옆을 톡
    private func evaluateTipTap(_ f: Finger, time: Double) {
        guard (1...2).contains(f.anchors.count) else { return }
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

    // 모든 손가락이 떨어진 뒤: 여러 손가락 탭, 모서리 톡
    private func evaluateSession(_ s: Session, time: Double) {
        guard !s.consumed else { return }
        let duration = time - s.startTime
        let n = s.fingerCount
        guard n == s.maxConcurrent, s.maxMove <= Tuning.tapMaxMove else { return }

        if n >= 3 {
            guard duration <= Tuning.multiTapMaxDuration,
                  s.lastLandTime - s.startTime <= Tuning.multiTapLandWindow else { return }
            if n == 3 { fire(.threeFingerTap, time: time) }
            if n == 4 { fire(.fourFingerTap, time: time) }
        } else if n == 1, duration <= Tuning.cornerMaxDuration {
            let left = s.firstX < Tuning.cornerX, right = s.firstX > 1 - Tuning.cornerX
            let bottom = s.firstY < Tuning.cornerY, top = s.firstY > 1 - Tuning.cornerY
            switch (left, right, top, bottom) {
            case (true, _, true, _):  fire(.cornerTopLeft, time: time)
            case (_, true, true, _):  fire(.cornerTopRight, time: time)
            case (true, _, _, true):  fire(.cornerBottomLeft, time: time)
            case (_, true, _, true):  fire(.cornerBottomRight, time: time)
            default: break
            }
        }
    }

    private func fire(_ g: Gesture, time: Double) {
        guard time - lastFire >= Tuning.minInterval else { return }
        lastFire = time
        Log.write("✅ \(g.title)")
        onGesture?(g)
    }
}
