import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@main
struct ContractChecks {
    static func main() {
        let first = IFrameVideoID("M7lc1UVf-VE")!
        let second = IFrameVideoID("dQw4w9WgXcQ")!
        check(IFrameVideoID("invalid!") == nil, "invalid ID accepted")
        check(IFrameVideoID("abcdefghijkl") == nil, "long ID accepted")

        var gate = IFrameEventGate()
        let firstGeneration = gate.load(first)
        let ready: [String: Any] = ["kind": "ready", "videoID": first.rawValue,
                                    "generation": String(firstGeneration)]
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com")?.kind == .ready, "ready lost")
        check(gate.accept(ready, isMainFrame: false, originScheme: "https",
                          originHost: "www.youtube.com") == nil, "subframe accepted")
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "evil.example") == nil, "foreign origin accepted")

        let secondGeneration = gate.load(second)
        check(secondGeneration > firstGeneration, "generation did not advance")
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com") == nil, "stale ready accepted")
        let error: [String: Any] = ["kind": "error", "videoID": second.rawValue,
                                    "generation": String(secondGeneration), "code": 150]
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com")?.kind == .failed(.embeddingDisabled),
              "embedding error mapping failed")
        let ended: [String: Any] = ["kind": "ended", "videoID": second.rawValue,
                                    "generation": String(secondGeneration)]
        check(gate.accept(ended, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com")?.kind == .ended, "ended lost")
        check(gate.accept(ended, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com") == nil, "duplicate ended accepted")
        gate.teardown()
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com") == nil, "post-teardown accepted")
        print("P1 IFrame contract checks passed")
    }
}
