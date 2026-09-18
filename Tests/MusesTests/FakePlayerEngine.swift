import Foundation
@testable import Muses

@MainActor
final class FakePlayerEngine: PlayerEngine {
    let state = PlayerState()
    var onCompletion: (@MainActor () -> Void)?
    var loads: [UUID] = []
    var delayNs: UInt64 = 0

    func load(_ track: TrackSnapshot) async throws {
        loads.append(track.id)
        if delayNs > 0 {
            try await Task.sleep(nanoseconds: delayNs)
        }
        guard state.track?.id == track.id else { return }
        state.buffering = false
        state.isPlaying = true
    }

    func prepare(_ track: TrackSnapshot) async {}
    func playPrepared() -> Bool { false }
    func play() { state.isPlaying = true }
    func pause() { state.isPlaying = false }
    func toggle() { state.isPlaying.toggle() }
    func seek(to time: Double) { state.position = time }
    func setVolume(_ v: Float) {}
    func setEQ(_ bands: [EQBand]) {}
    var isEQAvailable: Bool { true }
    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void) {}
    func removeSpectrumTap() {}
}
