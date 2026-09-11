import SwiftUI

/// 32-Band tactile graphic equalizer sheet for iOS.
struct EQEditorView: View {
    @Bindable var playback: PlaybackService
    @Environment(\.dismiss) private var dismiss

    @State private var bands: [EQBand] = []
    @State private var isEnabled: Bool = true
    @State private var selectedPreset: String = "Flat"

    private let presetNames = ["Flat", "Bass Boost", "Vocal", "Acoustic", "Rock", "Electronic"]

    init(playback: PlaybackService) {
        self.playback = playback
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preset Picker & Enable Toggle
                HStack {
                    Toggle(isOn: $isEnabled) {
                        Text(tr("EQ Enabled", "启用均衡器"))
                            .font(.headline)
                    }
                    .tint(BrandColors.accent)

                    Spacer()

                    Menu {
                        ForEach(presetNames, id: \.self) { preset in
                            Button(preset) {
                                applyPreset(preset)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedPreset)
                                .font(.subheadline)
                                .foregroundStyle(BrandColors.accent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(BrandColors.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BrandColors.surface, in: Capsule())
                    }
                }
                .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                .padding(.top, 12)

                // Interactive Frequency Response Curve
                curveView
                    .frame(height: 110)
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)

                // 32-Band Slider Grid (Horizontal Scrollable)
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 14) {
                        ForEach(Array(bands.enumerated()), id: \.offset) { index, band in
                            VStack(spacing: 8) {
                                Text("\(Int(band.gain))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(band.gain > 0 ? BrandColors.accent : BrandColors.textSecondary)

                                // Vertical slider
                                Slider(
                                    value: Binding(
                                        get: { band.gain },
                                        set: { newVal in
                                            bands[index] = EQBand(frequency: band.frequency, gain: newVal)
                                            playback.setEQ(bands)
                                        }
                                    ),
                                    in: -12...12,
                                    step: 0.5
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 140, height: 26)
                                .frame(width: 26, height: 140)
                                .disabled(!isEnabled)

                                Text(formatFreq(band.frequency))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(BrandColors.textTertiary)
                                    .frame(width: 32)
                            }
                        }
                    }
                    .padding(.horizontal, AppleMusicSpacing.pageHorizontal)
                    .padding(.vertical, 8)
                }

                Spacer()
            }
            .background(BrandColors.background)
            .navigationTitle(tr("32-Band Equalizer", "32段图形均衡器"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Done", "完成")) {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(BrandColors.accent)
                }
            }
        }
        .onAppear {
            initializeBands()
        }
        .presentationDetents([.medium, .large])
    }

    private var curveView: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandColors.surface)

                // Zero line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Frequency gain curve
                if !bands.isEmpty {
                    Path { path in
                        for (i, band) in bands.enumerated() {
                            let x = (CGFloat(i) / CGFloat(bands.count - 1)) * geo.size.width
                            let normGain = CGFloat(-band.gain) / 24.0 // -12...+12
                            let y = (geo.size.height / 2) + normGain * (geo.size.height * 0.8)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [BrandColors.accent, Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5
                    )
                }
            }
        }
    }

    private func initializeBands() {
        if bands.isEmpty {
            let standardFrequencies: [Double] = [
                20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630,
                800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000,
                12500, 16000, 18000, 20000
            ]
            bands = standardFrequencies.map { EQBand(frequency: $0, gain: 0) }
        }
    }

    private func applyPreset(_ name: String) {
        selectedPreset = name
        switch name {
        case "Bass Boost":
            for i in 0..<bands.count {
                let gain: Float = i < 8 ? Float(8 - i) * 0.8 : 0
                bands[i] = EQBand(frequency: bands[i].frequency, gain: gain)
            }
        case "Vocal":
            for i in 0..<bands.count {
                let gain: Float = (i >= 12 && i <= 22) ? 4.0 : -1.0
                bands[i] = EQBand(frequency: bands[i].frequency, gain: gain)
            }
        case "Rock":
            for i in 0..<bands.count {
                let gain: Float = (i < 6 || i > 24) ? 5.0 : -2.0
                bands[i] = EQBand(frequency: bands[i].frequency, gain: gain)
            }
        default: // Flat
            for i in 0..<bands.count {
                bands[i] = EQBand(frequency: bands[i].frequency, gain: 0)
            }
        }
        playback.setEQ(bands)
    }

    private func formatFreq(_ freq: Double) -> String {
        if freq >= 1000 {
            return String(format: "%.0fk", freq / 1000)
        }
        return "\(Int(freq))"
    }
}
