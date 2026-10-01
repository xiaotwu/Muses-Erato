# iPad follow-up

2026-09-30（America/Los_Angeles）。继续范围：regular iPad 页面重建、横竖屏、最大字号、真实窄窗口、提交身份与系统 accessibility audit。不修改 session/privacy/settings/CI；不提交 Git。

预留 simulator：753E6065-1F2D-4FBA-9DE7-4889EEAFF83A，iPad Pro 13-inch (M5) / iOS 26.5。主手机及其他线程的 simulator 不占用。使用 `.artifacts/ipad-quality/` 工程/结果与独立 `/tmp/muses-ipad-quality-20260929` DerivedData。

## 生产源码冻结点

本线生产源码在 2026-09-30 07:10 UTC 冻结（最终使用 `.combine` 保留标准 Button semantics；`.ignore` 试验未保留）；后续仅验证与测试文档收尾。准确 SHA256：`.artifacts/ipad-quality/production-source-sha256.txt`。主协调可立即 commit / 重跑 signed archive，不需等待本线测试结束；全项目冻结仍由其他线程修正决定。

- `PublicRootView.swift`：侧栏独立 identifier 与单一 accessibility label；Library 计数、`PublicEmptyState` 说明改用 label 色；三个 discovery 按钮将 44 点最小高度放进 label，确保实际控件命中区域足够大。
- `PublicHomeContent.swift`：YouTube Music link 黑色文字、金色箭头、单一 accessibility label。
- `PublicLibraryHeroViews.swift`：分类按钮单一 accessibility label，保留选中 traits 和独立 identifier。
- 新增 `Tests/MusesPublicUITests/PublicIPadLayoutUITests.swift`；现有整个 UI tests directory allowlist 包含该文件，无需 manifest 改动。

## 实测

| 用例 | 结果与证据 |
| --- | --- |
| 真实 regular sidebar 重建，local video、local playlist、online 提交身份 | 首轮通过，`initial-ui.xcresult`；断言不存在 compact tab，draft kind 改变后重建不重标已提交 video 结果 |
| portrait/landscape Home/Library/Search/Settings 入口 | 首轮通过，`initial-ui.xcresult` |
| 最大辅助字号横屏分类、搜索 source/type menu、Settings | 首轮通过，`initial-ui.xcresult` |
| 系统真实窄窗口 | 通过，`window-resize-ui.xcresult`；拖动 iPadOS resize handle，window 从 `(0,0,1032,1376)` 变为 `(329,219,375,823)`；Library 与 Search 聚焦成功 |

最终冻结生产源码复验：`final-functional-ui.xcresult` 中 regular 提交身份重建、portrait/landscape 入口、最大辅助字号 3 项通过。窄窗口扩大到 Home/Settings 后首次失败是 test adapter 在键盘覆盖底部 tab 时未收起键盘就点击 Home；明确点击 Search 空态收起键盘、断言键盘消失后再切 Home，`final-window-ui.xcresult` 独立 1/1 通过（0 skipped），窄窗口 Home/Library/Search/Settings 全部可操作并恢复系统窗口。没有通过 skip 回避失败；没有为此修改生产源码。

拆类后的共享辅助逻辑已实际重新编译并执行窄窗口测试，0 新 warnings/errors。最终 4 个功能用例的通过证据来自上述两次 run，不把曾失败的整个 result bundle 声称为绿色。所有最终生产源 SHA256 校验通过。追加最大字号 screenshot 时发现 SwiftUI category crossfade 尚未结束，capture 增加 0.4 秒稳定等待后另行复验；不以过渡帧当裁切缺陷。

最新真实窄窗口截图位于 `.artifacts/ipad-quality/final-window-attachments/`，含 Library/Search/Settings、系统缩放前后、bounds 文本。Settings `CDBB2C60-0C32-422D-94C6-995796A6483A.png` 已目视确认内容完整。完整 regular 与最大字号截图在 `final-functional-attachments/`。

稳定截图复验 `settled-large-ui.xcresult` 1/1 通过、0 skipped、0 warnings/errors，截图在 `settled-large-attachments/`。测试和文档现已收尾；生产代码从 07:10 UTC 后没有本线进一步修改，主协调可提交最新 test adapter（keyboard dismissal + capture 短等待）与文档。专属 simulator 已释放，可供主协调后续复核。

窄窗口是 iPadOS 26 windowed multitasking 实测，没有第二个并排 app，因此不宣称传统双 app Split View。窗口尺寸持久化，测试通过系统 Window Controls → Zoom 恢复，避免后续 regular 测试误用窄窗口。截图现用 `XCUIScreen.main.screenshot()`：`app.screenshot()` 在旋转/非零窗口 origin 时裁切错误，早期图片不能作为完整视觉验收。

## Accessibility audit

`performAccessibilityAudit` 收集所有 `.all` finding，末尾断言 findings 为空；没有忽略任何类型或具体 finding。没有通过的 audit 不算验收通过。

严格审计已独立为同文件中的 `PublicIPadAccessibilityAuditUITests` 类；默认 `PublicIPadLayoutUITests` 只有四个真实功能测试。公共辅助类 `PublicIPadUITestCase` 没有任何 test 方法。CI/spec 线程可以让 `MusesPublicIPad` 仅运行功能类，`MusesPublicIPadAudit` 可选 scheme 运行严格诊断类；手机 scheme 排除两个 iPad 类。没有用 XCTSkip 掩盖实际 iPad 功能失败；唯一 skip guard 是非 iPad 设备不能执行 iPad 系统窗口操作。

早期 landscape 与切 portrait 的 audit 截图/窗口方向不同步，不能直接据此判断颜色。恢复系统全屏、从 portrait 启动后，`fullscreen-portrait-audit-ui.xcresult` 坐标为 1032×1376，完整截图正确。仍报告 Library 计数/空状态及 Search 空状态说明对比度不足，本轮提高文字对比度。三个发现入口旧按钮 AX bounds 实际只有约 34–36 点，本轮将 44 点高度移入控件 label。

全屏 audit 还报告 Home link 和侧栏 Library 文字 contrast（截图实际黑色）、Library 四个无 element hitRegion。本轮为交互控件使用单一 accessibility label，避免重复静态文字节点。最终复验待追加。

最终 `.combine` 源码的 `combined-audit-ui.xcresult` 已执行所有四个页面；Search 与空状态说明 contrast 不再报告。Home link/侧栏黑色文字与 Library 黑色计数仍报告 contrast，Library 四个无 element hitRegion 仍报告，未过滤、未宣称通过。完整屏幕 Library 截图 `combined-audit-attachments/66D52509-0531-4336-9E25-6E472CA02D76.png` 显示计数/说明为黑色、discovery 按钮 AX bounds 为 58 点高；不能为消除黑色文字报告继续盲改生产设计。

### Settings 跨归属 findings：请主协调转交 Privacy/Settings

未改 Settings；报告两项 textClipped、About 与 YouTube account caption contrast nearly passed、五项 elementDetection（无 element）。只有两项 contrast 能定位真实元素，其余需要归属线程复核；不能将全 app audit 标记通过。原始报告：`.artifacts/ipad-quality/fullscreen-audit-attachments/4C2D7EA4-42E5-45F6-8FB0-65837E237535.txt`。Settings 完整截图：同目录 `9D72AD8E-1A8E-482A-A8AF-2C73DB724E09.png`。

复验 Settings finding 波动为一项 textClipped、About contrast nearly passed、四项 elementDetection（无 element）；账号 caption 不再报告（其他线程共享改动可能已更新）。最新原始报告：`.artifacts/ipad-quality/combined-audit-attachments/840DDE4D-4467-43CE-AD99-8E0EA53D1D4C.txt`，Settings screenshot `E5E1BCA6-73E9-4B92-A606-B53A72B784CB.png`。请主协调转交 Privacy/Settings 复核。没有向其他 chat 直接发送工具消息：本线没有直接来自人类用户的 chat messaging 授权，工具规则不接受 orchestrator 的转交授权。

Desktop Computer Use 对 Device Hub 三次 timeout，XcodeBuildMCP runtime snapshot 没有可交互 target。系统窗口操作由 XCTest 的 SpringBoard Window Controls/resize handle 执行，坐标动作来自已检查的实际截图。没有用强制 frame 或 preview 冒充系统分屏。
