# Home / Library / Search implementation handoff

状态：实施完成，生产源码冻结。冻结校验时间：2026-09-29 19:32:40 PDT（America/Los_Angeles）。最终大字 Menu 回归于 19:32:58 完成通过，之后没有修改生产源码。未提交 Git、发布或修改外部账号。

## 最终实现

- Home 优先确认播放历史、本地列表、账号列表；仅保存视频时显示 Saved Videos；空态及有内容页提供 Search videos / Open link / Import。Search videos 将 draft kind 设置为视频并消耗一次聚焦请求，不自动提交，也不覆盖旧 submitted 结果身份。
- 账号 Home 首次只加载一页，More 显式下一页；失败保留已有行、Retry 当前 continuation、隐藏重复 More；下拉刷新才重置。最大辅助字号账号内容采用纵向行。
- Library 只显示 All Saved / Playlists / Favorites / History，单行→两行→大字单列降级，保留旧 enum 兼容。独立 session 投影、本地筛选、非空才显示 controls，作用域删除确认正确。List 为默认，`public.library.presentation` 保存 Cards/List；最大辅助字号临时显示 List，不覆盖偏好。
- Search 分离 draft 与 session submitted query/kind/source，明确 idle/loading/results/empty/error/partial；本地与 YouTube 来源分节，分页失败保留结果；切类型不联网。本地仅视频/播放列表，Channels 不开放无效入口。线上缺配置独立解释、禁用线上来源，本地仍可操作。辅助字号 source/type 使用带完整文字的系统 Menu。
- Player 使用 raw playbackError 呈现 Retry playback / Open YouTube，queueFailureMessage 单独显示，不附错误的播放恢复动作。保存位置失败单独 Retry saving position；生命周期离开前台调用 checkpoint。播放器明确金色 tint。
- Search/CatalogDetail/VideoDetail/Queue 在操作处显示队列错误。VideoDetail 的笔记/其他错误 fallback 保留。
- 修正视频/结果/列表条目数量的单复数，placeholder 为 Video details unavailable。最大字号 Cards/List 图标保持 18pt，44pt 操作区域及完整辅助标签保持。

新增唯一 UI 源文件：`Sources/Muses/Features/Public/PublicSearchScreen.swift`，已由协调方加入 Public/Native allowlist。其余改动仅本线程拥有的六个 UI 源文件与对应 UI 测试。没有修改 session、network、privacy/settings、工程 manifest。测试 helper `addSavedVideosToLocalPlaylist` 保留，并适配四分类直接定位；Native 调用者仍可使用。

## 编译与回归证据

本线程专用模拟器：34668CCA-C1F0-4BB7-AB5C-8E5AAB3C0F6E（Muses Home Library Search，iOS 26.5，iPhone Air）。未占用协调器的 46441 模拟器。隔离工程 `.artifacts/ui-quality/MusesPublic.xcodeproj`；DerivedData `/tmp/muses-ui-quality-20260929` 与 `/tmp/muses-ui-quality-20260929-finalbuild`。

Public Debug 构建及 build-for-testing 成功。最后一次菜单大字 test 又编译了冻结版本并成功。下面每轮都保留独立 xcresult/log，不把多轮结果冒充一个完整 suite：

| 轮次 | 精确结果 | 证据（均在 `.artifacts/ui-quality/`） |
| --- | --- | --- |
| 首轮 core | Catalog 8/8；Library 1/5，四个用例失败（7 条断言） | `core-ui.xcresult`, `test.log` |
| 修正 core | 9/9 通过：Library 5、Search pagination 1、Playlist Import 3 | `corrected-ui.xcresult`, `corrected-test.log` |
| 新交互 | 3/3 通过：Search videos 聚焦不提交、普通/最大字号导入+本地列表搜索+返回 | `final-ui.xcresult`, `final-test.log` |
| 键盘/图标 | 2/2 通过：Outside tap 仍验证两处键盘收起；最大字号 Library | `keyboard-large-ui.xcresult`, `keyboard-large-test.log` |
| 最终菜单 | 1/1 通过：最大字号导入、Library、有内容 Home、本地列表搜索与返回 | `menu-large-ui.xcresult`, `menu-large-test.log` |

首轮发现并修正两个真实 UI 问题：Menu 内按钮的 confirmationDialog 随菜单关闭而消失；ViewThatFits 父 identifier 覆盖子分类 identifier。确认状态改挂持续存在的 Menu；分类移除父 identifier，独立 library.category.* 稳定。相应回归已重跑通过。旧键盘测试期待未提交时 Results heading，现点击真正可见的 idle 文本，保留键盘断言。

源文件 `git diff --check` 通过。协调器完整 suite 属于另一轮，应以其日志单独报告；本线程没有声称完整 Public/Native suite 均通过。

## 最新截图与实际设置

以下均为本轮 XCTest 附件导出的真实截图，目录绝对路径为 `/Users/xiaotwu/Code/Muses-Erato/.artifacts/ui-quality/screenshots/`：

- `library-cards-dark.png`：有内容 Cards，集合 controls（corrected 轮）。
- `library-large-dark.png`：最大辅助字号 Library，最终修正的 Cards/List 图标（keyboard-large 轮）。
- `home-populated-dark.png`：普通字号本地/账号播放列表（final 轮）。
- `home-populated-large-dark.png`：最大辅助字号有内容 Home（最新 menu-large 轮）。
- `search-retry-dark.png`：分页失败保持结果并显示 Retry（corrected 轮）。
- `search-local-dark.png`：普通字号本地播放列表结果与返回保留（final 轮）。
- `search-local-large-dark.png`：最大辅助字号 Search，来源/类型文字完整、单数 result 正确（最新 menu-large 轮）。

深色模式实际通过 `simctl ui appearance dark` 设置并读回为 dark；大字通过 `UICTContentSizeCategoryAccessibilityXXXL` 真实 launch 参数运行。Reduce Transparency 仅代码 fallback，未实际切换/截图；iOS 18 runtime、VoiceOver、iPad regular 重建、真机/真实账号和真实在线 iframe 播放未验证。没有将 fixture 截图当作真实封面/在线播放证据。

## 尚存接口边界

Search 错误目前为 session display string + Retry，没有结构化 retryAt/auth recovery，UI 不猜测恢复时间、不按字符串匹配错误。配置缺失有准确本地降级；设备预算与服务错误文案由 session/network 提供。进一步细化错误恢复需要其类型化 API，不在本轮 UI 里复制策略。

## 冻结源码 SHA-256

证据文件：`.artifacts/ui-quality/production-source-sha256.txt`，已对六个文件运行校验全部 OK。以下是协调器各轮 source 验收边界：

```text
221f74edabf8dd14e211d84a068babe45b89a03d5e464047ffd1683ce797bb7c  Sources/Muses/Features/Public/PublicRootView.swift
6cf6937a01e47ab0d7f68944e48a6f950c327a670ae5b78524e39920cabfabe4  Sources/Muses/Features/Public/PublicHomeContent.swift
454d9ec7842f9ce739e7124d4d2203aa6addd4ece0c67f681a9d6fdb02f7fb86  Sources/Muses/Features/Public/PublicLibraryHeroViews.swift
3ad6f00da32a19df453007c58ca2876d7edf318e17dc8911962606752a5a5229  Sources/Muses/Features/Public/PublicCollectionDeck.swift
82ec02f523e8151e4faba55b48c129b8f08ccced50a693f9f96898a6cb6827ff  Sources/Muses/Features/Public/PublicCatalogViews.swift
06981671866434987765a09295f02829416b34c791af5101b58720ce6658a004  Sources/Muses/Features/Public/PublicSearchScreen.swift
```

实施及测试文件已稳定；不再轮询或修改。专用模拟器测试完毕后关闭，截图/日志/xcresult 保留。
