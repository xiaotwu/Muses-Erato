# Public UI 实施规格

日期：2026-09-29（America/Los_Angeles）。供协调对话确认与各实施对话对接。本文为推荐实施方案，应用源码仅作只读检查；不代表已完成界面或真机验证。

协调更新：两个 UI 实施计划已获主协调确认并启动，本文为其统一规格与后续验收参考，不新增审批门槛。以 `quality-privacy-settings-plan.md`、`quality-home-library-search-plan.md` 及对应已交付 API 为实施边界；本文的新增精细建议若尚未接线，列为集成检查项，不阻塞已授权实施。

## 1. 已确认范围与设计方向

- 保留金色强调色、系统内容表面、Home / Search / Library 三个主目的地；Settings 从导航栏进入。
- Home 内容优先：有内容展示最近播放和播放列表；无内容展示搜索、打开链接、导入播放列表三个可执行入口。
- Library 只显示 All Saved / Playlists / Favorites / History。Songs 重复分类、Podcasts 无效入口不再显示。旧模型枚举和删除语义保持兼容。
- 首启为一个精简介绍弹窗；完整政策可从弹窗及 Settings > Privacy 阅读。匹配当前政策版本的明确同意完成前不构造应用 session / 网络与账号服务。
- Public 可见 YouTube 播放器的前台限制必须准确说明。Native 实验能力按实际构建能力分支，不把后台音频当作 Public 承诺。
- Liquid Glass 服务于系统呈现层与操作控件；内容卡片、政策长文、结果列表保留系统不透明表面。

依据：`docs/quality-improvement-coordination.md`、`docs/project-quality-review-2026-09-29.md`；检查了 `PublicRootView`、`PublicHomeContent`、`PublicLibraryHeroViews`、`PublicCollectionDeck`、`PublicCatalogViews`、`PublicPrivacyView`、`PublicSettingsViews`、`PublicServiceLinks` 与 `PublicYouTubeApp`。

截图基线为 `.artifacts/quality-review-2026-09-29/screenshots/01-privacy.jpg` 至 `06-settings.jpg`。已查看首启、Home、Library、Search、Settings 图；Podcasts 问题有评审和源码依据。截图是旧界面，不能作为本轮验收证据。

## 2. 共用布局、视觉与导航

| 项目 | 实施规则 |
| --- | --- |
| 主导航 | compact 使用系统 TabView，顺序 Home / Search / Library；regular 保留现有 NavigationSplitView 的同三个目的地。每个目的地保留自己的导航状态 |
| Settings | 每个根页右上角齿轮，44 × 44pt 最小点击区域；sheet + NavigationStack，标题 Settings，右上 Close；不是第四个 Tab |
| 间距 | 水平边距沿用 PublicStyle.inset = 20；章节间 24–28；章节内部 12；行标题/说明间 4–6；内容宽上限沿用 900，政策阅读上限 750 |
| 字号 | 页面标题用系统导航标题；章节 .title2.bold；主内容 .body；解释 .subheadline；来源 .caption。使用文本样式，不设固定字体尺寸缩小关键文案 |
| 表面 | 背景 systemBackground；内容 secondarySystemBackground；内容圆角建议 16，封面 12–16。避免卡片套卡片；列表分隔线采用系统样式 |
| 颜色 | 沿用现有浅/深金色 token；主要文字 label，辅助文字 secondaryLabel。金色只用于选择和操作，不以颜色单独表达错误、选中或来源 |
| 操作 | 一处只有一个突出主操作；其次操作有完整文字。破坏性操作进入 More 菜单及系统确认，不与开始使用的操作同等强调 |
| 封面 | 视频优先 16:9；播放列表可保留现有方形艺术布局。加载/失败用固定比例系统表面 + 来源符号；缺图不显示错误弹窗，不把占位标题改成 Song |
| Mini player | 仅有 currentTrack 且播放器关闭时显示。iOS 26.1+ 沿用系统 accessory；iOS 18–26.0 用已有 safeAreaInset。滚动末尾操作不得被遮挡 |
| 错误组件 | 符号 + 简明原因 + 对应恢复按钮，容器用系统表面；错误属于当前操作。仅全局资料库不可用或清理未完成可使用全局提示 |

既有队列入口保留在导航栏；若小屏导航栏拥挤，打开链接移至明确的 Add/更多菜单，Home 空态仍必须直接显示 Open link。Settings 始终可达。改变 Tab 或打开 Settings 不自动触发播放。

## 3. 首启与版本化同意

### 3.1 推荐结构

Gate 先绘制无服务的静态 welcome 背景：app 名称、简单本地图标、系统背景。不在背景初始化 PublicRootView、播放器、AsyncImage、session 或账号刷新。

在该背景上展示一个系统 sheet，普通字号初始建议 `.fraction(0.78)` / `.large`，小屏、横屏与辅助字号只用 `.large`。sheet 内容为可滚动 VStack，底部 safeAreaInset 放同意与继续操作。iOS 26+ 保留系统 sheet 表面，不叠加覆盖整张 sheet 的自定义玻璃，也不固定高度。

首屏内容顺序：

1. 本地图标，标题 **Welcome to Muses**（.title.bold，允许换行）。
2. 一句定位：**Organize YouTube videos and playlists, with notes and time bookmarks.**
3. 两个简短说明行：**Playback stays in the visible player. Closing it or putting Muses in the background pauses playback.**；**Search, artwork and playback connect to Google / YouTube. Google sign-in is optional.**
4. **Privacy policy** 导航行，进入内嵌完整政策；**YouTube Terms** 与 **Google Privacy** 外部链接，明确浏览器跳转。
5. 底部可换行的同意控件：**I agree to the privacy policy and YouTube terms**，默认未选中。
6. 主按钮 **Agree and continue**，仅在已勾选、政策资源有效且写入未进行时可用；次按钮 **Not now**。

首次仅提供必要介绍；账号登录在进入应用后按需发生。首启文案使用编译能力判定，不构造 session：Public 使用上述前台限制；Native 文案说明默认可见播放器与可选实验后台音频，不能将 Public 前台限制概括为 Native 全部能力。Native 启用实验模式仍在 Playback 子页说明与确认。

### 3.2 拒绝、关闭、缺失与更新

| 状态 | 行为 |
| --- | --- |
| 首次未同意 | 勾选默认 false；政策版本显示于完整政策页；不构造 content 闭包返回的 view |
| Not now / swipe 关闭 | 保持静态 welcome，显示 Continue setup 与阅读政策入口；不进入主 Tab、不启动服务、不循环立即弹窗 |
| 再次打开 / 重启 | 从本地同意版本判断。未匹配仍显示 gate；用户可主动重新打开介绍 |
| 政策资源缺失/空白/不可读 | 明确 **Privacy policy is unavailable. Please try again after updating Muses.**；继续按钮禁用。提供支持和外部条款；外部政策链接不能替代待同意的内嵌版本 |
| 保存同意失败 | 保留 gate 与勾选状态，显示 **Could not save your agreement. Try again.**；不构造 session |
| 已同意当前版本 | 仍检查政策有效、非空；通过后跳过介绍，惰性构造 PublicConsentedAppView/session。已保存同意与 DEBUG fixture 都不能绕过缺失/空白政策 |
| 版本变化 | 标题 **Review the updated privacy policy**；取消旧勾选，重新确认。若提供版本差异说明，只能来自真实政策修改，不虚构摘要 |
| 清理/迁移待完成 | 保留独立 cleanup marker 与现有恢复保护。同意版本不得因库删除而重置，也不得因重新同意而清掉清理 marker |

同意的提交顺序是：验证当前内嵌政策可读 → 持久化版本并确认可读回 → 发布 accepted 状态 → 构造 session。不得在按钮点击同时启动服务再异步记录同意。现有 DEBUG fixture bypass 仅限隔离测试，不进入 Release，也不代替真实首启测试。

外部条款链接是用户明确操作后的系统浏览器跳转；gate 的“不启动服务”指应用 session、OAuth 刷新、catalog、图片、后台任务与播放器，不妨碍主动阅读外部条款。完整政策本身必须可离线阅读。

### 3.3 完整政策阅读页

首启与 Settings 使用同一 `PublicPrivacyView` / 文档数据源；标题 Privacy，顶部 app 名称、policy version、当前已同意版本（Settings 中显示）。正文按真实章节拆为标题与段落，各标题 `.isHeader`，正文可选择；纯 Markdown 文件仅作为单个 Text 显示无法满足章节导航要求。

保留所有完整正文，不按摘要删减。可采用保守段落解析器或本地结构化章节数组：只识别已知文档结构，解析不成功时回退完整原文，不能丢字。底部保留 YouTube Terms、Google Privacy、Account Access 和 Support；Support 注明 GitHub Issues 为公开页面。

政策内容必须随最终构建校正：Public Home 本地最近播放/播放列表与账号播放列表，不宣称未实际运行的 Cloud Home/账号推荐；完整说明可见播放器校验、前台限制、API 配置依赖、账号缓存与清理保护。协调已确定本轮内嵌政策版本 **2026-09-29.1**，Swift 常量与资源 header 同步；协调方负责本地站点/构建器对齐，归档发布候选不改、不发布外部页面。

## 4. Home

### 4.1 有内容

滚动顺序：Recently Played → Your Playlists（本地）→ YouTube Playlists（已登录账号）。至少一个可展示章节有条目即可进入内容布局；已保存视频但暂无历史/播放列表时，展示 Saved Videos 小节（最多 6 项），避免误判为完全新用户。

- 最近播放最多 12 项，按已确认播放时间倒序、video ID 去重；See all 跳至 Library > History。无历史时省略整个章节，不留一句无下一步的空说明。
- 普通字号可沿用现有水平卡片（宽约 228）；辅助字号使用纵向紧凑行，标题不限行。点击沿用 session.playTracks，校验与恢复流程仍由播放层负责。
- 本地播放列表最多 6 项；标题、条目数、明确 Local 标记；点击进入播放列表详情，Play 是独立操作。See all 跳至 Library > Playlists。
- 账号播放列表明确 **YouTube** 来源，不能与本地副本混为一类；首批按需加载，More 才请求下一页，不为填满 Home 自动拉全部页或订阅。
- 底部小型 Add content 操作组：Search / Open link / Import playlist，保证已有内容用户也能继续添加。

### 4.2 无内容

首屏居中偏上但按内容自然布局，避免固定高度撑出大空白：小型本地 play.rectangle 图标 → **Start your library** → **Find a video, open a YouTube link, or import a playlist.** → 全宽主按钮 **Search videos** → 两个次按钮 **Open link** / **Import playlist**。普通字号能放一行时并排，宽度不足或辅助字号纵向。

Search 切换至 Search 并聚焦输入；Open link 打开现有链接 sheet；Import playlist 打开现有导入 sheet。API 未配置时 Search 仍能搜索本地库；无本地库时说明 **Online search is unavailable in this build**，把 Open link 外部 YouTube 途径说清楚，不能承诺应用内链接播放一定可用。

未登录且 OAuth 配置可用时，三项操作下方显示 **Have YouTube playlists? Sign in**，进入 Account 页进行用户主动登录。OAuth 未配置不显示不能执行的登录按钮。账号登录不是使用本地库的前置条件。

### 4.3 Home 状态

| 状态 | 内容与恢复 |
| --- | --- |
| 本地有内容、远端加载 | 本地内容立即展示；远端章节 ProgressView，不用整页遮罩 |
| 远端空 | YouTube 章节显示 No YouTube playlists；本地内容不受影响 |
| 远端失败、有缓存 | 保留条目，章节底部显示失败 + Retry；标明当前显示上次结果 |
| 远端失败、无缓存 | 仅该章节错误 + Retry / Account settings；不替换全页内容 |
| 未登录 | 有本地内容仍内容优先；紧凑 Sign in 行代替远端空 shelf |
| 账号切换/退出 | 清除前账号远端展示；保留本地数据；晚到响应不发布 |

下拉刷新只刷新已授权的远端章节；本地投影不需网络刷新。账号 API 与页面加载必须可取消、合并，不能通过页面反复出现绕过 budget。

## 5. Library

### 5.1 四分类与布局

根页标题 Library；分类顺序 **All Saved / Playlists / Favorites / History**，默认 All Saved。普通小屏优先四项完整可见的紧凑分类；推荐 `ViewThatFits`：单行四个文字按钮 → 两列两行。辅助字号固定两列，若每列容不下完整标签改为一列。选中加系统表面背景、字重与 selected trait，不裁切两端，不依赖横向滑动才发现首末分类。

分类下为数量 + Presentation（Cards/List）+ More，只有当前集合非空才显示展示切换和清空。集成版默认使用 List，保留已选择的 Cards/List 偏好；辅助字号采用 List 的可达布局，但不覆盖用户存储偏好。设备级偏好使用已确认 `public.library.presentation` key，非法值回退默认；不擅自改变 Delete Local Data 的偏好清理范围。

当前分类有条目时提供本地过滤输入，按标题/creator匹配，不请求 catalog；无匹配显示 No saved items match “{filter}” + Clear filter，与真正零集合空态区分。数量可显示过滤数 / 总数；切分类可清当前过滤，用户的展示偏好继续保留。排序一期沿稳定保存顺序/历史时间，不新增无字段支持的 Recently added 或 Favorites date。

当全库无内容时保留分类及零数量，空态下直接 Search / Open link / Import；没有清空按钮。Playlists 有空列表对象仍是有内容，显示 0 videos 并提供添加入口。

### 5.2 精确数据范围

| 分类 | 数据与排序 | 空态与操作 |
| --- | --- | --- |
| All Saved | 本地持久化选择的 YouTube 视频全集，按 TrackID 去重；不局限播放列表成员，不包含仅供远端展示的 catalog cache。保持当前保存顺序作为一期默认，后续支持已定义时间字段后的最近添加排序 | No saved videos；Search videos / Open link / Import playlist |
| Playlists | 本地播放列表对象，保留用户顺序与列表内重复 occurrence；账号列表由 Home/Account 展示，导入后是本地对象 | No playlists；Create playlist（主） / Import playlist |
| Favorites | 所有本地 liked 视频，与播放列表成员无关；一期保持稳定保存顺序，不虚构收藏时间 | No favorites yet；Open a video and choose Favorite；Search videos / Open link |
| History | 已确认 playback 事件关联视频，独立于列表成员；按最新确认事件倒序，每个视频一行 | No playback history；Videos appear after playback is confirmed；Search videos / Open link |

打开链接、搜索点击、校验失败、单纯排队不能记作已播放。删除播放列表不清掉独立收藏与历史。API 元数据过期时保留选择和操作能力，标题用 **Video details unavailable** / video ID 占位，不叫 Song，也不把“保存”暗示为可离线播放。

若 `tracks` 含仅缓存条目或非 YouTube 旧媒体，不能直接把全部 `tracks` 当 All Saved；session 方必须提供准确投影。旧 `.songs` / `.podcasts` / `.artists` / `.albums` / `.subscriptions` 值可以保留供迁移与旧调用，公开分类用显式 allowlist；旧选择恢复到 All Saved。保留 `.songs` 旧清理的列表成员范围，隐藏入口不等于扩大旧删除范围。

### 5.3 行操作与删除

行主点击开始当前集合播放；More 提供 Video details、Add to queue、Favorite/Remove favorite、Add to playlist 与作用域删除。当前模型已有的能力先实现，缺少能力不能仅展示失效按钮。

| 操作 | 确认文案与范围 |
| --- | --- |
| Remove favorite | 只取消 liked；不删视频、列表、历史、笔记/书签 |
| Remove history item / Clear history | 只移除本地历史；不取消收藏、不删除视频与其他引用 |
| Delete playlist / Clear playlists | 只删本地列表对象；视频、收藏、历史、笔记仍在；YouTube 不变 |
| Clear playlist videos | 只清该列表 occurrence；视频与其他列表仍在 |
| Delete saved video | 明确会移除本设备该视频的收藏、历史、队列、列表引用、笔记与书签；YouTube 不变。删除正在播放的条目沿用播放器关闭保护 |
| Delete all saved videos | All Saved > More 的危险操作，确认显示具体数量与上述完整引用范围。不得复用旧 Songs 清理后悄悄扩成全库删除 |

每次写入成功后更新 UI；失败保留原集合并就地提示。批量删除允许部分成功时必须返回数量，不能显示全成功。删除后卡片焦点移到相邻条目；最后一项删除后焦点落空态标题。列表数量按 unique 视频；播放列表详情数量按 occurrence，保持重复导入语义。

## 6. Search

### 6.1 结构与提交

顶部保留现有输入卡片和显式 Search 按钮，清除用输入内 xmark，名称 Clear search；不以 trash 暗示删除已保存内容。下方 Videos / Playlists / Channels，辅助字号用带完整标签的 Menu picker；来源在结果内按 **Saved on this device** 和 **YouTube** 分节，行仍带来源字幕。

输入 draft 与 submitted query/kind 分开。输入和切分类均不自动联网：切分类保留 draft，说明 **Search in Playlists** 或相应类型，等待显式提交；返回已缓存的同 query/kind 结果可直接显示。提交后收键盘并保持已提交查询可见，禁用重复提交但允许编辑。local 结果立即发布；远端请求状态不遮住 local 结果。

在远端可用时 Search 为混合显式搜索；远端不可用时按钮变为 **Search saved videos**，本地视频仍可检索，在线分类禁用并附原因。重复结果优先本地，不能把 Saved 来源丢掉；同 id 不同 kind 不能互相去重。远端行的 Playlists/Channels 行为是打开详情，视频行是进入播放器校验。

### 6.2 状态机

| 状态 | 画面与操作 |
| --- | --- |
| idle | Find videos and playlists；Enter a title or creator, then search。无结果数量、无错误、无假 No results |
| loading 首批 | Searching YouTube… + 可用的本地分节；无初始提示或无结果卡；取消/清除取消请求 |
| results | 分节数量，保留 submitted query；底部按需 Load more，仅有 nextPageToken 时显示 |
| empty | 仅在已提交且相关数据源成功返回后：No results for “{query}”；建议更短关键词 + Edit search；若仅搜索本地，明确 No saved videos match… |
| error 无任何结果 | Couldn’t search YouTube + 对应恢复按钮；显示 submitted query。不能同时出现 idle/empty 文案 |
| partial（本地或上页结果存在，远端失败） | 保留结果；远端章节或分页尾部错误 + Retry。整体不是 empty |
| 清除 | draft/submitted/结果/错误/分页一起复位；取消旧请求并失效其 generation；不删库、不让晚到结果重新出现 |

错误必须分类为 unavailable configuration、offline/transient、authentication required、device budget、server quota、content restriction。配置缺失显示设置/构建可用性说明；网络错误 Retry；需要登录显示 Account settings；设备限制显示本地时区恢复时间和本地搜索；服务端配额不给保证恢复时间，若有可靠 Retry-After 显示 Try again after… 并禁用提前 Retry。不能把 apiConfigured false 一律报 Unauthorized。

分页失败只重试失败页，不重跑首批搜索；Search 新查询/新类型/清除时失效旧页和旧任务。预算计数与重试边界由 networking/session 提供，UI 不自行计时重试。

## 7. Settings / Privacy

继续使用 insetGrouped List，保留已确认的 Account → Library & data → Playback → Privacy & support 分组；Privacy & support 内提供完整 Privacy policy、支持/条款/权限链接，About 版本信息可用末尾 section，无需新层级。普通字号每行图标+标题+系统 disclosure，不叠玻璃内容卡片。这里的 Privacy 路径指 Settings 中可达完整政策，不要求为了标题拆出额外根页。

- Account：未登录时明确 Sign in with Google 与 read-only 描述；配置缺失说明不可用；登录取消静默回到未登录，失败在 Account 操作区提示。成功、loading、signing out、revocation 与 cleanup pending 分开。
- Library & data：Refresh details 的独立进度/错误/成功；Delete local data 独立状态。继续使用现有包含 retained originals、website data 的确认范围和重启待清理说明。pending 时有 Retry cleanup；失败不显示删除完成。
- Playback：Public 默认前台播放器说明；Native 选项仅实际 nativePlaybackAvailable 时显示，并保留实验确认。不可用版本不展示灰掉的后台开关造成误导。
- Privacy：可直接进入完整政策，显示 Policy version / Accepted version；条款与 Google 隐私、权限管理链接可达。首启同一个政策页，禁止维护两份正文。
- Support：公开 GitHub Issues 链接；提示别提交账户或凭据。不要自动收集或上传日志。
- About：显示 bundle display name、CFBundleShortVersionString、CFBundleVersion、实际构建渠道 Public / Experimental Native（来自编译能力，不由 Debug 名称猜测）；允许复制版本信息。缺字段显示 Unknown，不 crash。

操作开始只清自己的旧状态；完成状态紧邻触发控件，不借全局 failureMessage。Settings 关闭后不会在 Home 展示刚才的账号错误。已有 API 未返回 typed result 时需要 session 方交付状态接口，不能在 UI 把点击后 failureMessage == nil 当作成功。

## 8. iOS 18–26 与辅助功能

系统 TabView / NavigationStack / sheet 优先；iOS 26 原生控件自动采用系统外观，具体玻璃组合使用 Apple `GlassEffectContainer` 与 `glassEffect`，有 `#available(iOS 26, *)` 保护。自定义 `.interactive()` 仅用于可点击控件；modifier 放在布局/外观设置之后，圆角同组一致。多个自定义玻璃控件放同一容器；一期无需额外 morph 动画。[Apple Liquid Glass 指南](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)、[glassEffect](https://developer.apple.com/documentation/SwiftUI/View/glassEffect%28_%3Ain%3A%29)、[GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)

- iOS 18–25：主操作 `.borderedProminent`，次操作 `.bordered` / 系统菜单；sheet 系统表面。无需第三方玻璃 polyfill。iOS 26.0 mini player 走 safeAreaInset；26.1 才启用现有 accessory。
- Reduce Transparency：自定义 glass 回退不透明 secondary/tertiarySystemBackground；文字 primary；不采用半透明金色文字。不能仅换为另一种 blur。
- Increase Contrast：系统文字颜色和边界；选中加字重/selected trait，玻璃上不能仅靠金色明暗判断。
- Reduce Motion：分类、卡片、焦点的动画关闭；不用自动轮播/缩放/parallax。状态切换允许无动画，操作逻辑相同。
- Dynamic Type：至少最大 accessibility 字号检查。标题与主要按钮不限行；footer 可滚动；政策同意控件和 Continue 不被固定高度截断；分类/操作组切竖排；列表行允许高度增长。不会为了 fit 缩小文字。
- VoiceOver：章节 `.isHeader`； decorative 封面/符号 hidden；按钮含具体视频名或作用域；selected、agreement 有 value。区分 Play 与 More，避免一个巨大 combined 元素吞掉菜单。错误出现宣布一次，焦点留在原操作；可重试按钮仍可发现。
- 触控/键盘：所有实际 label ≥44pt；输入具有显式 label、submitLabel、取消/清除；菜单能用键盘/VoiceOver调用；拖动卡片有前后与列表替代操作。
- iPad/横屏：阅读内容居中限宽；sheet 支持自然高度和滚动；系统 split 导航保留三个目的地。大字不以宽屏为理由固定多列。
- 文案：本轮至少统一英文产品名/Video 称谓与来源文案，避免 Songs/artist 与当前视频定位冲突；新增字符串集中可本地化，不以 string 拼接生成数量/错误。完整中英文翻译属于额外交付，不能声称已支持。

## 9. Session / UI API 契约与文件对接

以下是可实施的接口约束；建议类型名称为示意，协调对话可映射现有接口，行为不能省略。UI 实施方不直接修改 session 文件以追赶命名。

| 提供方 | 最小接口 / 数据 | 必须保证 |
| --- | --- | --- |
| Privacy UI / composition | `PublicPrivacyPolicy.version/text/defaults`；`PublicPrivacyGate(content:)`；可读章节 + 本地 acceptedVersion | content 仅当前版本同意后求值；保留 acceptanceKey 与 cleanup 隔离；协议摘要与内嵌全文一致 |
| Session / library | `libraryTracks` = All Saved；`libraryFavorites` = 所有 liked；`libraryHistory` = 独立已确认历史；`playlists` | 稳定 TrackID、明确持久化选择 vs catalog cache、去重与排序；旧枚举兼容 |
| Session / search | submitted query/kind、local results、remote pager、phase/hasSubmitted、configuration capability | UI 能区分 idle/empty/error；generation 防晚到响应；online 不可用仍发布 local；kind 切换不自行联网 |
| Session / feedback | 每个 operation 的 idle/running/succeeded/failed；failure 含可显示 message、recovery、retryAt（可选） | 账号、同步、删除、搜索、播放状态互不污染；取消不当作失败；失败不会提前发布写入成功 |
| Session / account | signedIn/oauthConfigured、accountPlaylistPages、按需首批加载与 next page | Home 只请求其需要的列表；不隐式拉全页/订阅；账号 epoch 校验 |
| Session / playback | open/openLink/playTracks、已确认事件、typed playback failure/retry | 内嵌权限校验不绕过；当前视频失败可 Retry/Open in YouTube；失败/排队不记历史 |
| UI preferences | 已确认设备级 `public.library.presentation`；隔离测试 defaults | 重新进入、重启保留 Cards/List；辅助字号临时 fallback 不覆盖保存值；delete local data 是否清此偏好由现有设置语义统一 |
| Settings / build | bundle version/build + compile-time capability | 渠道准确，不从调试标志误推 Native；无 session 网络请求也能读取 |

建议错误数据形状：

```swift
enum PublicRecoveryAction {
    case retry, accountSettings, openInYouTube, editQuery, retryCleanup
}
struct PublicOperationFailure {
    let message: String
    let recovery: PublicRecoveryAction?
    let retryAt: Date?
}
enum PublicOperationPhase {
    case idle, running, succeeded
    case failed(PublicOperationFailure)
}
```

`retryAt` 只能来自可解释的设备预算/Retry-After；显示本地时区格式，session 负责是否能重试。类型可改为现有 domain 类型，不强制引入新的全局 coordinator。Search 的本地结果和远端 phase 必须分开，以表达 partial 状态；单个 phase 无法表达来源完整性。

一期最小适配：增加 `searchHasSubmitted` / 只读 submittedQuery/submittedKind 与 localSearchItems 暴露；UI 从 pager.loaded/loading/error 推导远端状态。operation-specific 状态应由 session/controller 发布，UI 不读取全局错误猜成功。旧 `failureMessage` 暂留兼容只用于未迁移流程与真正全局故障，不能继续铺到各页。

### 已交付接口对照（覆盖上述示意拼写）

- 搜索身份：`submittedSearchQuery`、`submittedSearchKind`、`hasSubmittedSearch`。`searchSaved(_:)` 仅本地视频；`search(_:)` 在线加本地；`retrySearch()` 保留提交身份和来源范围；`nextSearchPage()` 在 Saved 范围不请求；`clearSearchResults()` 回 idle。消费现有 `CatalogItem.source == "local"`，可分节或逐行明确来源；不要重复造 UI 内提交状态覆盖 session。
- Library：`libraryTracks` 是 open/enqueue/import/legacy migration 形成的持久化视频引用，catalog paging/search cache 不进入这里；`libraryFavorites` / `libraryHistory` 已独立。`.videos` 全集图删除、`.songs` 保留旧成员语义；favorites/history 原子清理；playlists 只删容器。
- 错误：`libraryFailureMessage`、`playbackFailureMessage`、`accountFailureMessage`、`metadataFailureMessage`、`deletionFailureMessage`。Settings 消费 `accountOperation` / `metadataRefreshOperation` / `localDataDeletionOperation`，其 `PublicOperationState` 含 `isRunning/message/error/pendingRestart`。
- 播放：`canRetryPlayback` / `retryPlayback()` 重新校验；`playbackCheckpoint.failure/pending` / `retryPlaybackCheckpoint()` 暴露本地保存恢复。重启恢复队列与位置但暂停，不自动加载媒体。当前类型化错误仍属后续强化；本轮使用已交付专属 message + retry 能力，准确展示事实即可。
- 已确认新增 source allowlist：`Sources/Muses/App/PublicSessionControllers.swift`、`Sources/Muses/Features/Public/PublicSearchScreen.swift`，由协调/TestsCI 更新两种构建。

`PublicRecoveryAction` 等示意不要求重写已交付类型。设备预算已有持久化实现；Search 精确 budget/retryAt 分类如尚未可见，列为集成待检查，不据泛化字符串猜测恢复时间。

文件边界遵循协调文档：Design 仅本文；Privacy/Settings 拥有相应视图、service links、policy 与测试；Home/Library/Search 拥有 root/home/hero/deck/catalog 与 UI 测试；session stream 拥有启动/lifecycle、域/持久化、projection、typed feedback 和 app tests。新 source paths 由协调方纳入 Public allowlist。本文不要求全仓重构。

## 10. 验收与实施优先次序

1. 先统一版本化 gate、完整政策结构与事实、library projection 与错误状态契约；协调对话确认后 UI 实施方接线。
2. 完成首启、Home 三操作、四分类、Search 状态与 Settings Privacy/About；清理所有可见 Songs/Podcasts 文案与入口。
3. 各自做针对性测试；协调方集成 Public/Native 构建与回归，再采新截图。不要用截图 fixture 同意 bypass 验收 gate。

| 场景 | 必须观察的结果 |
| --- | --- |
| 首次/旧版本同意 | 没有服务创建/图片请求/账号刷新；同意默认 false；阅读、拒绝、重开、更新版本重新同意都可完成 |
| 政策缺失、同意保存失败 | 服务不启动；按钮/错误准确；已有 cleanup marker 不丢 |
| 空 Home/Library | 所有首项操作可到达实际页面；API 缺失不承诺链接一定能内嵌播放 |
| 有历史/列表/仅保存视频 | 本地内容首屏可用；账号失败不遮本地；来源清楚 |
| 收藏/历史独立性 | 非播放列表视频→收藏、确认播放→重启→对应分类仍可见；删除列表仍可见 |
| 删除作用域 | 移除收藏、清历史、删列表、删视频、删全库分别验证保留/删除对象与正在播放处理；失败 UI 不虚报成功 |
| 搜索 | idle/loading/results/empty/error/partial，分类不自动请求，新查询和清除拒绝旧响应；分页失败可原页重试 |
| Settings | 登录取消、失效、sync/delete/cleanup 错误分别仅在所属操作出现；Policy version/About 真实 |
| 平台/辅助 | iOS 18 fallback、26.0/26.1 accessory边界、浅/深、小屏/iPad/横屏、最大字号、Reduce Motion/Transparency、VoiceOver主流程 |

建议保留现有 `privacy.agreement`、`privacy.continue`、`public.openLinkEntry`、`public.search` 等测试标识；新分类增加稳定 ID `library.category.allSaved/playlists/favorites/history`，不要把 rawValue 的可翻译标题当永久标识。旧测试按语义调整：不能因取消 Songs 清空覆盖而失去 scoped deletion 测试。

## 11. 风险与待协调事项

- 最重要依赖是 All Saved 的真实持久化范围。直接展示所有 transient tracks 或扩大旧 `.songs` 删除接口都可能造成事实/数据损失问题；projection 与显式全库操作先由 session 方确认。
- 首启 sheet 背景如果先构造 app/session 会破坏现有 consent gate；保留 content 惰性边界比弹窗外观更优先。
- 当前 `loadAccountCollections()` 拉完分页并读取订阅；Home 新方案依赖按需加载接口，UI 单改章节无法解决请求预算问题。
- 全局 failureMessage 现有调用多；独立反馈无法完全靠视图封装解决，需与 session/controller 工作同步。
- 当前政策包含 Cloud Home 等与已检查 Public Home 不一致的陈述，最终资源/版本/托管文档必须由协调方一致更新。此设计文档不发布托管页面。
- API 未配置时链接内嵌校验仍可能失败，所有开始使用文案需保留准确限制与外部途径。
- iOS 18、最大字号、VoiceOver、iPad、真实账号与网络恢复尚需执行验证；本文没有声称这些已通过。

## 12. 实施中只读检查意见

本节在两个 UI stream 已启动后检查共享工作区，属于集成待核对，不代表最终代码评审或已复现的 UI 缺陷。未修改应用，也未运行模拟器。

1. 当前 `PublicPrivacyView.swift` 已正确校验非空政策、使用 `2026-09-29.1`、支持 Not now / Continue setup，Native intro 按编译能力分支。sheet 普通字号仍为固定 `.height(640)`；建议改为适应屏幕的 fraction / large 或确认小屏横屏表现。全篇阅读 roundtrip 与保存版本前无服务创建需用针对性测试证明。
2. 当前 `PublicLibraryCategories` 已改为明确四分类，但仍 horizontal ScrollView，四项合计宽度在小屏与大字下可能需要滚动；建议采用第 5 节 ViewThatFits/多行回退以解决旧截图首末裁切的问题。selected glass 仍应按原生容器组合规则核对。
3. 当前 `PublicSearchScreen` 保留自己的 submittedQuery/kind/scope，并自行投影 local playlists；session 已提供提交身份和 `searchSaved` / `retrySearch`。建议接线统一提交/重试身份，防 Tab 重新创建或其他路径清理 session 后出现 UI 标题与实际 pager 不一致。若本地列表筛选留在 UI，应把它明确作为本地投影而非网络请求身份。
4. 当前 Search 的 source/type 都是 segmented Picker；辅助字号需要 Menu/竖排回退。Saved 仍显示可选择 Channels 再返回解释性空态，推荐禁用并说明仅在线可用，避免无效可选入口。线上不可用时输入 placeholder 仍是 Search YouTube，建议与实际本地行为一致。
5. 文档中的 typed budget/retryAt 恢复为推荐增强；现有交付 Search error 字符串 + pager retry 不足以保证时间和错误分类，集成方需真实验证可用性，不推测日期或 quota 恢复时间。

以上意见可由协调方在现有 UI stream 消化；已确认的实施授权持续有效，不需再次选风格或审批。
