import SwiftUI

/// Circular Play control on artwork — larger hit target, press scale ~0.97.
struct HoverPlayButton: View {
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(BrandColors.magenta, in: Circle())
                .shadow(color: BrandColors.magenta.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
        .contentShape(Circle())
        .help(tr("Play", "播放"))
        .accessibilityLabel(tr("Play", "播放"))
    }
}
