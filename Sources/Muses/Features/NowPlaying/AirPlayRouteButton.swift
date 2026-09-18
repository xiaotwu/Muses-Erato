import AVKit
import SwiftUI

/// System AirPlay route picker for the Now Playing audio sheet.
struct AirPlayRouteButton: UIViewRepresentable {
    var tint: UIColor = .white
    /// Active route tint — brand-neutral white (not coral).
    var activeTint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = activeTint
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = activeTint
    }
}
