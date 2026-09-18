import Foundation

struct EQBand: Codable, Equatable, Sendable {
    var frequency: Double      // Hz
    var gain: Float            // dB, -24...24
    var q: Float               // Bandwidth factor, 0.1...10

    init(frequency: Double, gain: Float, q: Float = 1.0) {
        self.frequency = frequency; self.gain = gain; self.q = q
    }
}

/// 10-band UI on a 32-slot `AVAudioUnitEQ`: the first 10 slots take the UI bands, the rest stay bypassed.
enum EQBandMapping {
    static let engineSlotCount = 32

    struct Assignment: Equatable, Sendable {
        var frequency: Double
        var gain: Float
        var q: Float
        var bypass: Bool
    }

    static func assignments(from uiBands: [EQBand], slotCount: Int = engineSlotCount) -> [Assignment] {
        (0..<slotCount).map { index in
            if index < uiBands.count {
                let band = uiBands[index]
                return Assignment(frequency: band.frequency, gain: band.gain, q: band.q, bypass: false)
            }
            return Assignment(frequency: 1000, gain: 0, q: 1, bypass: true)
        }
    }
}

enum EQPresets {
    static let flat: [EQBand] = [
        EQBand(frequency: 31, gain: 0, q: 1.0),
        EQBand(frequency: 62, gain: 0, q: 1.0),
        EQBand(frequency: 125, gain: 0, q: 1.0),
        EQBand(frequency: 250, gain: 0, q: 1.0),
        EQBand(frequency: 500, gain: 0, q: 1.0),
        EQBand(frequency: 1000, gain: 0, q: 1.0),
        EQBand(frequency: 2000, gain: 0, q: 1.0),
        EQBand(frequency: 4000, gain: 0, q: 1.0),
        EQBand(frequency: 8000, gain: 0, q: 1.0),
        EQBand(frequency: 16000, gain: 0, q: 1.0)
    ]
}