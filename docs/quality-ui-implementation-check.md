# 集成 UI 设计与交互检查

日期：2026-09-29（America/Los_Angeles）。检查对象为共享 checkout 当前代码与 `.artifacts/quality-improvement/screenshots/home-empty.jpg` / `library-empty.jpg`；对应设计 `docs/quality-ui-design.md`。只读生产源码，未占用模拟器、未运行测试、未改生产文件、未提交 Git。多个 stream 同时实施，以下行号为检查时位置。

## 结论

首启 gate、完整政策、Home、Library、Search、Settings 的主要结构已经对齐。两个截图证明普通字号空 Home/Library 的三个开始操作可见，Library 四分类没有旧截图两端裁切；它们不能证明有内容、失败、大字、VoiceOver、iOS 18 或首启复验通过。

冻结复核更新：此前两个 P1 与两个 P2 已全部 **resolved（源码修正已核对）**。本检查没有剩余已确认的必修项；平台及完整套件验收仍按下文限制报告。无需重新选风格或增加批准流程。

## 已解决问题

| 原问题 | 状态 | 冻结源码证据与验收边界 |
| --- | --- | --- |
| [P1] Home 后续页 Retry 重置已加载播放列表 | Resolved | `PublicHomeContent.swift` Retry 现调用 `loadAccountPlaylists()`，不 reset；错误存在时隐藏 More；错误/按钮改竖排。显式下拉刷新才重置。Home continuation 真实失败复验与完整套件由协调方报告 |
| [P1] Search 提交来源由易失 View State 决定 | Resolved | `PublicSearchScreen.swift` 的 `usesLocalResults` 读取 `session.isSubmittedSearchLocal`，不再按 apiConfigured 改写旧结果来源；query/kind 同样来自 session；onAppear 恢复编辑输入来源。compact 本地列表搜索及返回已有通过记录；iPad regular 重建仍未实测 |
| [P2] Saved 开放无法工作的 Channels | Resolved | source/type 普通 picker 和辅助字号 Menu 都仅在 YouTube 且已配置时提供 Channels；`normalizeDraftKind()` 回到 Videos；线上缺配置禁用线上来源，placeholder/辅助标签按 draft 来源命名；切来源不提交请求 |
| [P2] Search videos 未同步类型与焦点 | Resolved | `PublicRootView.swift` 的入口设置 draft `.video` 与一次 `searchFocusRequested`，Search 通过 Binding 消耗焦点请求；不自动提交、不修改 session submitted 身份。专项焦点回归记录通过 |

历史触发与修正要求见本文件上一轮检查；上表取代“必须修正”清单，不应将旧检查描述作为冻结代码仍有问题的结论。

## 冻结核对与回归记录

已读取 `docs/quality-home-library-search-handoff.md`，并执行六个 UI 生产文件 SHA-256 核对，全部 OK，匹配 `.artifacts/ui-quality/production-source-sha256.txt`。本检查没有运行模拟器或重跑 XCTest。

实施方记录的修正后回归为四轮 **9/9、3/3、2/2、1/1 通过**，每轮独立日志和 xcresult；最后大字 Menu 回归在 2026-09-29 19:32:58 PDT 完成。首轮 core 曾有失败并修正，不把多个轮次合并声称完整 suite 通过。精确证据路径、测试清单、最新截图见 UI handoff。协调器完整 UI suite 正在另行执行，Native Settings-dismiss 过渡由对应线程排查，本文不提前判定其结果。

## 已修正或已对齐的代码证据

| 页面 | 检查结果 |
| --- | --- |
| 首启介绍 | 当前 `.fraction(0.78)` / `.large`；普通字号 consentControls 已移至底部 safeAreaInset，大字在 ScrollView 内；Not now / Continue setup 可回到无服务 gate；版本 2026-09-29.1；写入读回校验；缺/空政策阻止 saved/fixture consent 进入 |
| 完整政策 | 同一资源、章节 header trait、正文 selectable、限宽、服务条款链接；无阅读自动同意代码路径。Settings 展示同意版本 |
| Home | 独立确认历史、本地/账号列表、仅保存视频 fallback、空态三操作；首批按需加载、More 显式；错误未覆盖本地 shelf |
| Library | 显式四分类、ViewThatFits 单行/两行/纵向回退；独立 projections；空集合不显示清空/展示切换；本地过滤与无匹配状态；大字临时 List；展示偏好持久化 |
| Search | query/kind 已改从 session 读取；分类不隐式联网；本地来源字幕/分节；idle/loading/error/empty；首次 Retry 与分页 Retry 分开；submitted scope 已统一为 session 来源 |
| Settings | 系统 grouped list、About version/build/edition、独立 account/metadata/deletion OperationState；确认和 pending cleanup 保留；Public/Native 文案按能力分支 |

Library 当前默认 presentation `.list`，统一规格第 5 节写“保留 Cards 默认”；这是可接受的实现收敛：大集合更好定位，不属于必须回滚。请协调方在最终规格中统一默认值，保留已有用户偏好。

## 残留验收限制

- 首启旧稿 Not now 未在首屏由协调方实测发现；当前 footer / fraction 已修，首启最终截图和流程结果以 Privacy/协调方最新记录为准。本检查没有新增首启实测证据；小屏横屏最大字号的 Continue setup 可达性仍需覆盖。
- Home 账号内容最大辅助字号已改纵向行；Search source/type 已改完整标签 Menu；Library Cards/List 图标固定 18pt、触控区仍 44pt。实施方最大字号相关回归通过，原先“大字无回退/图标溢出”的描述已失效。
- 实施方交接了普通/最大字号有内容 Home、Library、Search 本地及分页失败截图；本检查直接查看的是协调方两张空态截图，未重新逐张检查所有最新截图，不签署全部画面已视觉通过。
- iOS 18 runtime、VoiceOver、iPad regular 重建、真实 OAuth、真机及真实 iframe 媒体未验证；Reduce Transparency 仅代码 fallback，未实测切换。不能从模拟器深色/最大字号通过推导这些覆盖。
- 当前 Search 错误为 session display string + Retry，没有结构化 retryAt/auth recovery；UI 不猜测日期或根据字符串匹配恢复策略。进一步细化依赖类型化接口，属于后续增强。
- Library 默认 List 与早期规格保留 Cards 默认的文字不同，接受当前定位优先的实现，不需回滚；已有用户展示偏好继续持久保留。最终规格可由协调方统一默认值。
- 完整 Public/Native suite 与 Native Settings-dismiss 过渡仍以负责线程最终日志为准；本文的 resolved 表示原四项源码缺陷已修，不表示所有平台验证完成。
