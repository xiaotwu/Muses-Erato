import SwiftUI

/// Circular Play control on artwork — larger hit target, press scale ~0.97.
struct HoverPlayButton: View {
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 36, height: 36)
                .background(BrandColors.laurelGold, in: Circle())
                .shadow(color: BrandColors.laurelGold.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(MusesPressStyle(scale: MusesMotion.pressScale))
        .frame(minWidth: AppleMusicSpacing.hitTarget, minHeight: AppleMusicSpacing.hitTarget)
        .contentShape(Circle())
        .help(tr("Play", "播放"))
        .accessibilityLabel(tr("Play", "播放"))
    }
}
