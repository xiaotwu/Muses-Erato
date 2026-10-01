# Home / Library / Search UI 调查与实施计划

日期：2026-09-29（America/Los_Angeles）。状态：**只读调查完成，等待协调对话确认 `docs/quality-ui-design.md` 与实施指令。未修改 UI 代码。**

## 范围与依据

遵循 `docs/quality-improvement-coordination.md` 和 `docs/project-quality-review-2026-09-29.md`。已查看评估截图 `02-home.jpg`、`03-library.jpg`、`05-search.jpg`；这些只代表改动前应用，不是本轮验收证据。

本线程拥有 `PublicRootView.swift`、`PublicHomeContent.swift`、`PublicLibraryHeroViews.swift`、`PublicCollectionDeck.swift`、`PublicCatalogViews.swift` 与对应 UI 测试。不修改 session、domain/persistence/network、privacy/settings 或 project manifest；不提交 Git。新增 UI 源文件需要向协调线程报告路径，由测试/CI 线程更新两个工程 allowlist。当前同一 checkout 的其他改动保持原样。

## 调查结论

- `PublicRootView.swift` 当前 1160 行，集中承担导航、Home/Search/Library、链接输入、Web player、播放列表详情及 Queue。直接提取 private 类型需要同步调整文件可见性，不可仅搬代码。
- Home 的 `PublicHomeLibraryContent.recent` 使用 `session.libraryHistory` 的前 12 项；空态只解释“playlist tracks”。`PublicHomePlaylistShelves` 仅展示账号播放列表，未展示本地播放列表；未登录提示只指向 Settings。
- Library 默认 `.videos`，分类依赖 `LibraryCategory.allCases` 排除三项，因而仍暴露重复 `.songs` 和无效 `.podcasts`。截图中分类两端被裁切。展示偏好仅为 Root 的 `@State`。
- `libraryTracks` 是播放列表成员并集，`libraryFavorites`、`libraryHistory` 又按该集合过滤。session 已另有独立 `favorites`、`history`；但需要 session 线程统一公开语义、清空行为和保存集合，UI 不另造持久化投影。
- Search 使用 `searching`、`searchError`、合并 `searchItems` 与 private `submittedSearch/submittedKind`。UI 无法可靠区分初始、空结果与失败；分类改变会隐式再次联网。输入框内容可能已不同于当前结果的提交查询。
- `CatalogItem.source == "local"` 已显示 Saved video，在线项已显示 YouTube 来源；可以复用来源而无需修改 catalog 值模型。当前本地搜索只搜索视频，和在线搜索一起提交。
- Web player 位于 Root 文件，错误使用共享 `failureMessage`，外部 YouTube 操作藏在菜单，缺少 Retry。需消费 session 提供的播放专属恢复状态。
- 现有 UI 测试包含 Songs 导入流程、“No playlist videos”、空库清空按钮 disabled、Favorites 先加入列表才可见等旧假设。更新这些预期时保留删除确认、重启持久化、分页错误保留结果与大字可达性覆盖。

## 待批准设计的实施轮廓

1. Home 有内容时按最近确认播放、本地播放列表、账号播放列表组织，空态直接搜索、打开链接、导入。主操作通过 Root 传入 closures 路由，子视图不维护第二份 tab/sheet 状态。账号恢复只使用账号 pager 的错误，Home 不回显播放错误。
2. Library 显式使用四个可见分类：全部保存、播放列表、收藏、历史。旧 enum 的 `.songs/.podcasts` 保留兼容，进入 UI 时归一化到支持分类，不修改历史 rawValue。分类标签与标识符分离，显示名称以设计文档为准。
3. 每个 Library 空态有就近操作。零内容隐藏清空与无意义展示切换。非空集合保留 Cards/List，持久保存选择；大字模式优先可达列表或设计确认的降级卡片。新增本地筛选用于快速定位，不触发在线请求；排序项和默认模式待设计确定。
4. Search 展示提交查询和来源；明确初始、首次加载、结果、无结果、首次失败与分页失败。已有本地结果时在线失败只显示在线恢复提示，不清空本地结果。首次 Retry 与分页 Retry 使用不同入口和标识符。切分类不隐式消耗在线请求，明确提交后联网。
5. 播放失败在播放器内直接展示 Retry / Open YouTube；是否可重试由 session 决定，内容限制不能因 UI 重试绕过。按钮按大字模式竖排，维持 44pt 点击区域。
6. 保留金色与系统 surface；Liquid Glass 仅用于系统导航、分类选择与 controls，并以系统版本、减少透明度和辅助字号提供 fallback。继续使用现有 Reduce Motion 分支。

这些是实施边界，不代替待确认设计；文案、层级、布局、卡片默认值与具体视觉规格以最终设计为准。

## 文件拆分提案

优先保持现有文件内组件化，避免无必要工程配置变动。若协调线程批准新增源文件，按以下边界一次性抽取，新增名称仅为提案：

| 文件 | 最终职责 | 注意事项 |
| --- | --- | --- |
| `PublicRootView.swift` | 紧凑 tabs / 宽屏 sidebar、sheet/link/import 路由、生命周期、Settings 接线 | tab 选择与 tool sheet 仍由唯一 Root 管理；不修改 privacy/session 初始化 |
| `PublicHomeContent.swift` | populated / empty Home、最近播放、本地及账号 playlist shelves | 通过 closures 执行搜索、链接、导入、历史、账号设置路由 |
| `PublicLibraryHeroViews.swift` | 支持分类及标签、Cards/List 控件、集合行、清空与删除提示 | 全部保存删除语义必须与 session 对齐；旧 Songs helper 保留到确认无其他依赖 |
| `PublicCollectionDeck.swift` | 有界卡片投影、焦点、手势、playlist blocks | 保留最多五张可见卡片；筛选/删除后 clamp 焦点；空数组不访问索引 |
| `PublicCatalogViews.swift` | catalog rows、来源、catalog details、paging | 账号 catalog 同样复用该文件，不破坏授权或显式加载行为 |
| 提案 `PublicSearchScreen.swift` | Search 输入/范围、提交、状态及恢复呈现 | Root 传入 query/focus 或抽取独立状态所有者；避免两份提交查询 |
| 提案 `PublicLibraryScreen.swift` | Library 分类内容、筛选、数量、空态与展示偏好 | 使用 session 投影，不实现保存或删除业务 |
| 提案 `PublicWebPlayerScreen.swift` | 现有 Web player、IFrame surface 与 mini-player（依可见性边界定） | 不改 Native player；Retry 调 session，外链使用 session 的有效 URL |
| 提案 `PublicContentStatusViews.swift` | 共用 notice/empty/action labels 与视觉 token | 只抽可复用 UI；现有其他文件对 PublicStyle/labels 的引用保持可编译 |

不同时开展 session 重构。抽取前核对 `PublicPlaylistDetail`、`PublicQueueView`、`PublicAddToPlaylistMenu`、`PublicIconActionLabel` 等跨文件引用，逐项移除不适用的 private；仅暴露必要的 module-internal 类型。若新增文件未获工程 allowlist 支持，先在拥有文件内完成组件边界。

## Session API 需求交接

以下是所需语义，名称供 session 线程决定并通过协调线程确认。UI 不依赖某个拟议拼写。

| 需求 | 最小接口或既有接口 | 行为契约 |
| --- | --- | --- |
| 全部保存 | `libraryTracks` 或明确 `savedVideos` | 与收藏/历史/列表独立，可找回通过链接保存的视频；明确临时 metadata cache 是否属于保存集合 |
| 独立收藏 | `libraryFavorites` 或既有 `favorites` | 收藏无需列表成员关系；重启后仍可找回；清空收藏仅解除喜欢 |
| 独立历史 | `libraryHistory` 或既有 `history` | 仅确认播放后记录、按最近排序、去重；删除列表不丢历史；清空历史不删除保存视频 |
| 分类兼容 | 既有 `selectedCategory` / `LibraryCategory` | 保留 legacy enum；UI 支持列表显式列出四项；旧选择归一化；不要改变持久 rawValue |
| 清空范围 | `clearLibraryItems(.videos/.favorites/.history/.playlists)` | `.videos` 与“全部保存”的投影一致；收藏/历史/列表操作保持独立，提示准确涵盖 notes/bookmarks/queue 引用 |
| 搜索提交身份 | 只读 `submittedSearchQuery`、提交 kind/range | 结果、空态、Retry 使用同一提交身份，而非用户正在编辑的 query；新查询使旧响应失效 |
| 搜索阶段 | 明确 `idle/loading/results/empty/failed` 或可组合状态 | 首次失败与分页失败可区分；本地有结果+在线失败可同时表达；Clear 恢复 idle，不发布迟到结果 |
| 本地定位 | `searchLocal(query, kind/range)` 或 Library 本地过滤 | 能不联网检索保存视频，若设计要求则检索本地列表；切类型/本地范围不自动联网；来源稳定 |
| 在线错误恢复 | 类型化 recovery 或 message + `canRetry/retrySearch()` | 区分未配置、认证、离线、设备预算与服务器配额；缺配置禁止无效网络提交；预算给可理解恢复时间 |
| 分页恢复 | 既有 `searchPages/nextSearchPage()` | 失败保留已加载结果；Retry 当前失败 page，不能当成重新首查；避免重复行 |
| 播放恢复 | 播放专属 failure、`canRetryPlayback`、`retryPlayback()`、有效 `currentYouTubeURL` | Retry 保留当前视频/队列/位置并重新验证 embedding；加载中禁用重复 Retry；限制不被绕过 |
| 操作隔离 | link/library/account/playback 的独立错误或状态 | Home/Library 不显示其他流程旧 `failureMessage`；本地写入失败仍向用户反馈，成功后清除自身错误 |

展示偏好可以在 UI 使用唯一命名 `@AppStorage("public.library.presentation")`，验证非法值 fallback；无需 session 新 API。须确认是否设备级偏好，以及 Delete Local Data 是否重置：未收到最终契约前不修改 cleanup 行为。

Home 本地播放列表可直接用既有 `session.playlists` 和 `PublicPlaylistDetail`；最近播放可使用 session 确认后的独立历史。账号加载/Retry 可复用 `accountPlaylistPages` 与 `loadAccountCollections()`，就近账号入口回到现有 Settings，不在本线程新增 OAuth 流程。

## 验证计划与交接

仅在实施授权后执行。由协调线程安排模拟器所有权与独立 DerivedData/results 路径；不在本轮启动构建或占用模拟器。

- Home：空库三个入口可完成首项任务；有确认历史/本地列表/账号列表时优先内容；账号失败保留本地内容；Recently Played → See all 正确到历史。
- Library：仅四个有效分类；链接保存或收藏无需创建列表；确认播放历史重启找回；列表移除不吞掉收藏/历史；Clear Favorite / History / Playlist 的删除范围各自验证，取消删除保持内容。
- Preference / 定位：Cards/List 切换、返回、重启保持；本地筛选不调用 catalog；筛选或删除卡片焦点稳定；空库无清空/切换控件。
- Search：idle/loading/success/empty/首次 error、本地结果+在线 error、缺配置、本地检索、分页失败与 Retry 保留行；分类切换无隐式网络请求；Clear 与快速重新查询无旧响应污染。
- Player：加载失败直达 Retry、恢复正常、受限制内容保留外链操作且不能正常播放；按钮不依赖隐藏菜单；取消/换视频后不会恢复旧视频。
- 可访问性：iOS 18 fallback 与 iOS 26 controls；最大辅助字号、Reduce Motion、Reduce Transparency，检查主操作和分类可达；新截图覆盖空/有内容与失败态，报告未验证设备范围。
- 更新 `PublicLibraryHeroUITests`、`PublicCatalogUITests`、相关 `PublicSmokeTests`；保存现有显式分页、删除确认、队列、重启与大字测试意义。session 单元测试及 fixture 新状态由对应线程供给，不侵占其源码。

待协调对话提供：最终 `quality-ui-design.md`、session API 名称/契约、如需新增 UI 文件的 allowlist 交接、fixture 可用错误/延迟状态、实施启动指令。计划完成后停止工作，无需轮询设计或其他线程。
