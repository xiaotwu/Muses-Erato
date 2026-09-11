import SwiftUI

/// YouTube brand mark: red rounded rectangle + white play triangle.
public struct YouTubeMark: View {
    public var size: CGFloat = 18

    public init(size: CGFloat = 18) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(red: 1, green: 0, blue: 0))
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.04)
        }
        .frame(width: size * 1.28, height: size * 0.92)
        .accessibilityLabel("YouTube")
    }
}
