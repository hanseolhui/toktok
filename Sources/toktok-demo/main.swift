// toktok-demo — prints the gestures TokTokCore recognizes on your trackpad.
//
//   swift run toktok-demo
//
// Try: rest your middle finger and tap with your index (tipTapLeft),
// tap with three fingers, tap a corner, or slide along the right edge.
import Foundation
import TokTokCore

setvbuf(stdout, nil, _IOLBF, 0)   // print each line right away

guard let trackpads = Multitouch() else {
    print("Couldn't load MultitouchSupport.framework")
    exit(1)
}

GestureDetector.sliders = [.left, .right]
trackpads.onEvent = { event in
    switch event {
    case .gesture(let g):          print("👆", g.rawValue)
    case .slider(let side, let up): print("🎚", side.rawValue, up ? "▲" : "▼")
    }
}
trackpads.restart()
trackpads.watchDevices()
print("Listening on \(trackpads.deviceCount) trackpad(s). Press Ctrl-C to quit.")
RunLoop.main.run()
