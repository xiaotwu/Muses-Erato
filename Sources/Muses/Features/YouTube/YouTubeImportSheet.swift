import SwiftUI

/// Sheet for importing a YouTube playlist link: paste URL + import button + progress states.
struct YouTubeImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    let onImport: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("https://www.youtube.com/playlist?list=PL...",
                          text: $url)
                    .textFieldStyle(.roundedBorder)

                Text(tr("Supports YouTube playlist links (with list= parameter). Importing is for personal use only, comply with YouTube's Terms of Service and local laws.", "支持 YouTube 歌单链接(含 list= 参数)。导入仅个人使用,遵守 YouTube 服务条款与当地法律。"))
                    .font(.caption).foregroundStyle(BrandColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .frame(maxWidth: 480)
            .navigationTitle(tr("Import YouTube Playlist", "导入 YouTube 歌单"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel", "取消")) { dismiss() }
                        .foregroundStyle(BrandColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Import", "导入")) {
                        onImport(url)
                    }
                    .font(.headline)
                    .foregroundStyle(BrandColors.accent)
                    .disabled(url.isEmpty)
                }
            }
        }
        .presentationDetents([.height(240), .medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }
}