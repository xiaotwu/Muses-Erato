import Foundation
import Observation

/// Sleep timer: automatically pauses playback when the countdown ends.
///
/// `@MainActor @Observable`; the UI can bind `isActive` / `remainingSeconds` directly.
/// Remaining time is computed dynamically against absolute wall-clock time (`targetEndDate`),
/// eliminating drift during background suspension.
@Observable
@MainActor
final class SleepTimerService {
    private let playbackService: PlaybackService
    private var uiUpdateTask: Task<Void, Never>?

    /// Target end date based on absolute wall-clock time.
    var targetEndDate: Date?

    private(set) var isActive = false
    private(set) var totalSeconds: Double = 0

    /// 基于绝对时刻动态计算剩余秒数，杜绝后台漂移
    var remainingSeconds: Double {
        guard isActive, let target = targetEndDate else { return 0 }
        return max(0, target.timeIntervalSinceNow)
    }

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
    }

    /// Starts the timer.
    /// - Parameter minutes: Minutes to count down (e.g. 15/30/45/60).
    func start(minutes: Int) {
        start(seconds: Double(minutes * 60))
    }

    /// Starts the timer with explicit seconds.
    func start(seconds: Double) {
        cancel()
        totalSeconds = max(0, seconds)
        targetEndDate = Date().addingTimeInterval(totalSeconds)
        isActive = true

        // 仅用于驱动 UI 刷新与到期执行
        uiUpdateTask = Task { [weak self] in
            while let self, self.isActive {
                let remaining = self.remainingSeconds
                if remaining <= 0 {
                    self.playbackService.pause()
                    self.cancel()
                    break
                }
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    /// Cancels the timer (playback is not paused).
    func cancel() {
        uiUpdateTask?.cancel()
        uiUpdateTask = nil
        targetEndDate = nil
        isActive = false
        totalSeconds = 0
    }

    /// Formats the remaining time as `H:MM:SS` or `M:SS`.
    var remainingFormatted: String {
        let total = Int(ceil(remainingSeconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}