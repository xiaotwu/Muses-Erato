import SwiftUI

struct SleepTimerSheet: View {
    @Environment(SleepTimerService.self) private var sleepTimer
    @Environment(\.dismiss) private var dismiss

    private let options = [15, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            List {
                if sleepTimer.isActive {
                    Section {
                        HStack {
                            Label(tr("Timer Active", "定时运行中"), systemImage: "clock.fill")
                                .foregroundStyle(BrandColors.magenta)
                            Spacer()
                            Text(sleepTimer.remainingFormatted)
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(BrandColors.textPrimary)
                        }

                        Button(role: .destructive) {
                            sleepTimer.cancel()
                        } label: {
                            Text(tr("Stop Timer", "关闭定时器"))
                        }
                    }
                }

                Section(header: Text(tr("Turn Off Playback After", "在指定时间后停止播放"))) {
                    ForEach(options, id: \.self) { minutes in
                        Button {
                            sleepTimer.start(minutes: minutes)
                            dismiss()
                        } label: {
                            HStack {
                                Text(tr("\(minutes) Minutes", "\(minutes) 分钟"))
                                    .foregroundStyle(BrandColors.textPrimary)
                                Spacer()
                                if sleepTimer.isActive && Int(sleepTimer.totalSeconds / 60) == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(BrandColors.magenta)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(tr("Sleep Timer", "睡眠定时器"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Done", "完成")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
