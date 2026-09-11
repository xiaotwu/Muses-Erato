import SwiftUI
import SwiftData

/// Automation Rules view allowing users to create, view, and toggle context-aware smart music playback rules.
struct AutomationRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AutomationRule.name) private var rules: [AutomationRule]
    @State private var showCreateSheet = false
    @State private var newRuleName = ""
    @State private var selectedTrigger: AutomationTrigger = .trackCompleted
    @State private var selectedAction: AutomationAction = .likeTrack

    var body: some View {
        List {
            Section(header: Text(tr("ACTIVE RULES", "运行中的自动化规则")),
                    footer: Text(tr("Rules react to real-time playback events to organize your library automatically.",
                                   "自动化规则根据实时播放事件自动整理你的音乐资料库。"))) {
                if rules.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("No Automation Rules Yet", "暂无自动化规则"))
                            .font(.headline)
                            .foregroundStyle(BrandColors.textPrimary)
                        Text(tr("Add rules to auto-like completed tracks, triage skips into your inbox, or queue next songs.",
                                "添加规则以自动收藏完整听完的曲目、将跳过的歌曲加入收件箱稍后整理，或自动安排播放队列。"))
                            .font(.caption)
                            .foregroundStyle(BrandColors.textSecondary)

                        Button {
                            addDefaultRules()
                        } label: {
                            Label(tr("Add Preset Rules", "添加预置推荐规则"), systemImage: "wand.and.stars")
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                    }
                    .onDelete(perform: deleteRules)
                }
            }

            Section {
                Button {
                    showCreateSheet = true
                } label: {
                    Label(tr("Create Custom Rule", "创建自定义规则"), systemImage: "plus")
                }
            }
        }
        .navigationTitle(tr("Automation Rules", "智能自动化"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    Section(header: Text(tr("RULE DETAILS", "规则详情"))) {
                        TextField(tr("Rule Name", "规则名称"), text: $newRuleName)
                        Picker(tr("Trigger Event", "触发时机"), selection: $selectedTrigger) {
                            ForEach(AutomationTrigger.allCases, id: \.self) { trigger in
                                Text(trigger.label).tag(trigger)
                            }
                        }
                        Picker(tr("Action", "执行操作"), selection: $selectedAction) {
                            ForEach(AutomationAction.allCases, id: \.self) { action in
                                Text(action.label).tag(action)
                            }
                        }
                    }
                }
                .navigationTitle(tr("New Rule", "新建规则"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Cancel", "取消")) { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("Save", "保存")) {
                            createRule()
                            showCreateSheet = false
                        }
                        .disabled(newRuleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColors.textPrimary)

                HStack(spacing: 6) {
                    Text(rule.trigger.label)
                        .font(.system(size: 12))
                        .foregroundStyle(BrandColors.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(BrandColors.textTertiary)
                    Text(rule.action.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BrandColors.accent)
                }

                if let fired = rule.lastFiredAt {
                    Text(tr("Last fired: \(fired.formatted(date: .abbreviated, time: .shortened))",
                            "上次触发: \(fired.formatted(date: .abbreviated, time: .shortened))"))
                        .font(.system(size: 11))
                        .foregroundStyle(BrandColors.textTertiary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { rule.enabled = $0 }
            ))
            .labelsHidden()
            .tint(BrandColors.accent)
        }
        .padding(.vertical, 4)
    }

    private func createRule() {
        let name = newRuleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let rule = AutomationRule(
            name: name,
            trigger: selectedTrigger,
            action: selectedAction
        )
        modelContext.insert(rule)
        newRuleName = ""
    }

    private func addDefaultRules() {
        let rule1 = AutomationRule(
            name: tr("Auto-like finished songs", "自动收藏听完的歌曲"),
            trigger: .trackCompleted,
            action: .likeTrack
        )
        let rule2 = AutomationRule(
            name: tr("Add skipped tracks to Inbox", "跳过的歌曲移入收件箱待听"),
            trigger: .trackSkipped,
            action: .addToInbox
        )
        modelContext.insert(rule1)
        modelContext.insert(rule2)
    }

    private func deleteRules(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rules[index])
        }
    }
}
