import Foundation
import AVFoundation
import Observation

/// Context capture service for iOS.
///
/// Provides a snapshot of the current `ListeningContext` at playback transitions.
/// Bridges AVAudioSession for headphones and audio route detection.
@Observable
@MainActor
final class ContextService {
    private let calendar: Calendar

    struct DeviceContext: Sendable {
        let outputDeviceName: String?
        let isHeadphones: Bool?
    }

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Captures current context for listening event analysis.
    func capture() -> ListeningContext? {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let dow = calendar.component(.weekday, from: now)
        let isWeekend = dow == 1 || dow == 7
        let dev = Self.defaultDevice()

        return ListeningContext(
            hour: hour,
            dayOfWeek: dow,
            isWeekend: isWeekend,
            frontmostAppBundleId: "com.xiaotwu.muses.erato",
            outputDeviceName: dev.outputDeviceName,
            isHeadphones: dev.isHeadphones
        )
    }

    /// Encodes context into JSON string for storage.
    static func encode(_ context: ListeningContext?) -> String? {
        guard let context else { return nil }
        let data = try? JSONEncoder().encode(context)
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Decodes context JSON string.
    static func decode(_ json: String?) -> ListeningContext? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ListeningContext.self, from: data)
    }

    static func defaultDevice() -> DeviceContext {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        guard let first = outputs.first else {
            return DeviceContext(outputDeviceName: nil, isHeadphones: nil)
        }
        let portType = first.portType
        let isHeadphones = portType == .headphones
            || portType == .bluetoothA2DP
            || portType == .bluetoothLE
            || portType == .bluetoothHFP
            || portType == .airPlay
        return DeviceContext(outputDeviceName: first.portName, isHeadphones: isHeadphones)
        #else
        return DeviceContext(outputDeviceName: "Default Output", isHeadphones: false)
        #endif
    }
}
