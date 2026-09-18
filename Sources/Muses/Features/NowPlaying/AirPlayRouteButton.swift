import SwiftUI
import AVKit

/// System AirPlay route picker for the Now Playing transport.
struct AirPlayRouteButton: UIViewRepresentable {
    var tint: UIColor = .white
    var activeTint: UIColor = UIColor(red: 250 / 255, green: 88 / 255, blue: 106 / 255, alpha: 1)

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
