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

        var gate = IFrameEventGate(expectedOriginHost: "com.xiaotwu.muses.erato")
        let firstGeneration = gate.load(first)
        let ready: [String: Any] = ["kind": "ready", "videoID": first.rawValue,
                                    "generation": String(firstGeneration)]
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato")?.kind == .ready, "ready lost")
        check(gate.accept(ready, isMainFrame: false, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "subframe accepted")
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "evil.example") == nil, "foreign origin accepted")
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "www.youtube.com") == nil, "YouTube accepted as app identity")

        let secondGeneration = gate.load(second)
        check(secondGeneration > firstGeneration, "generation did not advance")
        check(gate.accept(ready, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "stale ready accepted")
        let error: [String: Any] = ["kind": "error", "videoID": second.rawValue,
                                    "generation": String(secondGeneration), "code": 150]
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato")?.kind == .failed(.embeddingDisabled),
              "embedding error mapping failed")
        let identityError: [String: Any] = ["kind": "error", "videoID": second.rawValue,
                                            "generation": String(secondGeneration), "code": 153]
        check(gate.accept(identityError, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato")?.kind == .failed(.missingClientIdentity),
              "identity error mapping failed")
        let blocked: [String: Any] = ["kind": "playBlocked", "videoID": second.rawValue,
                                      "generation": String(secondGeneration)]
        check(gate.accept(blocked, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato")?.kind == .playBlocked,
              "scripted playback block event lost")
        check(gate.accept(blocked, isMainFrame: false, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil,
              "blocked event must obey the same origin/frame gate")
        let ended: [String: Any] = ["kind": "ended", "videoID": second.rawValue,
                                    "generation": String(secondGeneration)]
        check(gate.accept(ended, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato")?.kind == .ended, "ended lost")
        check(gate.accept(ended, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "duplicate ended accepted")
        gate.clear()
        check(gate.isAlive && gate.videoID == nil, "clear must remove video without retiring adapter")
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "cleared video accepted")
        let nextGeneration = gate.load(second)
        check(nextGeneration > secondGeneration, "same-video reload reused generation")
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "old same-video callback accepted")
        check(gate.accept(blocked, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "stale block cannot fail new playback")
        gate.teardown()
        check(gate.accept(error, isMainFrame: true, originScheme: "https",
                          originHost: "com.xiaotwu.muses.erato") == nil, "post-teardown accepted")
        print("P1 IFrame contract checks passed")
    }
}
