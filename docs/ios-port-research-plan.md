# Muses → Erato：iOS 目标架构与迁移实施规格

> 版本：2026-09-27 · 状态：实施基线 · 主仓库：[Muses-Erato](https://github.com/xiaotwu/Muses-Erato) · 产品参照：[Muses](https://github.com/xiaotwu/Muses)
>
> 本文合并用户提供的《Muses iOS — Maximum-Quality Architecture & Migration Specification》和本仓库此前的 iOS 移植研究。用户规格提出的产品质量、分层、工程方法和大幅重构权限是主体；已确定的“仅 YouTube 内容、优先公开上架 App Store”是发布约束。两者冲突时，以明确的授权与分发门槛决定某能力能否进入公开版。本文是后续实施的唯一主计划；旧实现不是规范。

## 0. 执行摘要与不可变决策

1. **产品**：复刻 Muses 的内容组织、视觉身份、队列语义和高质量交互，针对 iPhone/iPad 重设导航与展示。允许大幅重构、拆包、替换协议、删除旧代码；不以最小 diff 为目标。
2. **内容与发行**：公开版只使用 YouTube 内容，优先 App Store。用户明确拒绝将 Apple Music 作为替代来源。Ad Hoc IPA 是测试与备选分发，不自动授予媒体使用权。
3. **公开版播放**：在当前可查的公开政策与授权下，YouTube 使用**可见的官方 IFrame Player**；账户、歌单、订阅等按需使用官方 YouTube Data API。不能把当前 Innertube 解析流、第三方镜像、yt-dlp 或 Media Gateway 作为公开版绕配额／播放路径。
4. **原生音频能力**：AVPlayer/AVAudioEngine、后台音频、EQ、频谱、Gapless、Crossfade、流文件缓存等架构可以为**用户有权播放的本地文件**及未来取得明确授权的来源设计；这些能力不因此自动适用于 YouTube。若坚持“公开版只有 YouTube 内容”，本地文件能力应先作为隔离模块与测试夹具，不擅自把它变成第二内容来源。
5. **阶段门槛**：任何 YouTube 原生流播放、音频分离、下载、后台播放、代理转发、Media Gateway 或 YouTube Music 非公开接口进入公开版前，都要有对应的明确许可与平台审核结论。没有证据则保持关闭，并且不以代码可运行或 IPA 可安装替代授权判断。
   - **2026-09-27 真机验收补充**：用户确认队列与清空交互正常，并提出歌曲后台连续播放需求。该需求保留为获权播放能力的目标；当前官方 YouTube 嵌入路径仍在后台停止。歌曲分类、Data API key 和 OAuth 不授予后台播放许可。若授权边界改变，先更新本计划和能力矩阵，再交付后台实现；不得擅自加入其他内容来源。外部打开 YouTube 不承诺继承本 App 队列或后台连续播放。

### 2026-09-27 Library 与发布补充要求

- Library 分类改为顶部横向可滚动选项，保留选中反馈和辅助功能，内容区使用 macOS 当前源代码中的英雄卡设计进行 iOS 适配。
- Library 各类本机资料均有删除／移除操作：保存视频、收藏、本机歌单、历史、笔记、书签及升级后可编辑投影。删除保存项时处理队列与歌单等依赖，失败不更新成功状态；不以删除本机资料冒充删除 YouTube 云端内容。
- 歌曲式英雄卡需要音乐／视频呈现切换，视频格式仅显示有来源的数据。官方 Data API 缺少 YouTube Music 专有分类与音轨信息时，明确标注限制，不编造格式、专辑关系或歌曲判定。界面呈现切换必须保持官方播放器可见；真正音频播放模式仍受上述授权门槛约束。
- 支持与反馈统一使用 GitHub Issues（已启用）；Discussions 目前未启用。隐私政策准备在仓库中公开管理，发布前核实 URL、真实数据处理、保留／删除边界和 Google/Apple 所需开发者联系配置。
6. **真实状态**：当前 iOS 源码已有 SwiftData、队列、Now Playing、音频图、Innertube/镜像解析、WKWebView 视频 sheet 等入口，但“有代码”不等于真机验收或可上架。现有主播放是 `YouTubeStreamEngine`，现有 WKWebView 仅为二级视频 sheet。原本的 `ios` yt-dlp player-client 名称并不代表 yt-dlp 有原生 iOS 支持。

### 0.1 能力矩阵：先决定发布，再选择实现

| 能力 | App Store：仅 YouTube，现有公开授权 | 本地/明确授权来源 | 验收条件 |
| --- | --- | --- | --- |
| YouTube 视频播放 | 可见官方 IFrame，保留其控件、署名、广告和交互 | 同左，除非单独获权 | 真机播放、嵌入失败与页面切换验收 |
| YouTube 账号、歌单、订阅、搜索 | 官方 Data API、合规 OAuth、配额预算 | 同左 | 测试账号、分页、限额、撤权与删除数据 |
| YouTube Music 首页/目录 | 不能假设内部 Innertube 可作为公开稳定接口；先提供官方数据能支持的发现 | 待单独授权 | 来源、时效、缺口显式列出 |
| YouTube 纯音频、后台、离线、EQ、频谱 | 暂不交付 | 仅当来源和使用方式获明确许可 | 授权文本、审查、真机测试 |
| 本地音频、音频图、锁屏控制 | 当前“仅 YouTube 内容”产品范围之外，保持隔离 | 可完整实现 | 文件权限、格式、系统控制与性能 |
| Media Gateway/yt-dlp/代理 | 不作公开版 YouTube 播放后备 | 只作获权来源的条件性方案 | 许可、安全、成本、故障与隐私审查 |
| Queue、历史、收藏、笔记、歌单 UI | 本地状态和可用官方数据可做；播放操作受 IFrame 能力约束 | 完整原生管线可做 | 状态一致性、恢复与大数据集 |
| CarPlay/Watch/锁屏遥控 | 不把 YouTube 嵌入播放变相扩展为后台／隐藏播放器 | 获权音频来源再启用 | entitlement 与真机逐项审核 |

**重要设计结论**：用户规格中的“WKWebView 不应成为主播放器”只适用于获权的原生音频路径；对于当前 App Store/YouTube 主线，官方可见播放器是必要的主播放适配器。应把播放器协议设计为能力驱动，而不是把 IFrame 伪装成 AVAudioEngine。能力受来源、授权、运行平台和分发渠道共同决定，不由一个 `if appStore` 布尔值猜测。

## 1. 现状、证据与项目基线

- 本地 iOS 工作区在研究时有大量未提交改动；文档不代表已覆盖或提交这些改动。动手前运行 `git status`，保留既有工作，选择可复现的基线。两个项目源码与当前工作树均应重新盘点。
- 已观察到的 iOS 入口：`Sources/Muses/App/AppComposition.swift` 注入 `YouTubeStreamEngine`；`Sources/Muses/Features/YouTube/YouTubeVideoStage.swift` 通过 WKWebView 打开嵌入视频并暂时挂起原生播放；`PlaybackService`/`QueueService`、SwiftData、搜索、发现、资料库、歌词、EQ、系统扩展已有代码。它们的真实行为需要逐项验证。
- 研究阶段 `MusesCore` 的 3 项测试通过，iPhone 17/iOS 26.5 模拟器 Debug 构建返回 0；还没有真机播放、登录、后台、耗电、UI 的验收结论。构建警告与功能状态在实施 Phase 0 重新记录。
- macOS 产品参照为资料库（艺术家/专辑/歌曲/收藏/视频/播客/订阅/歌单/历史）、Home/发现/搜索、上下文队列、歌词、评论、章节、视频、笔记和系统媒体交互。菜单栏、独立窗口、浏览器 Cookie helper、桌面歌词与更新安装器属于平台专属。
- README 中关于无损/Hi-Res/Dolby、离线与后台等表述必须与实际来源、编码及授权一致；实施时逐条核对并修正营销与设置文案。

### 1.1 源码盘点表的定义

每个用户流程都记录：`macOS 行为`、`iOS 已有入口`、`公开版目标`、`本地/获权目标`、`自动测试`、`模拟器`、`真机`、`发布阻塞`。状态只允许：未实现、已有代码未验证、自动测试通过、模拟器通过、真机通过、发布准入通过。不得用“有类名”代替验收。

## 2. 产品与设计原则

- 行为和体验优先于源码兼容；共享 Domain、状态机、数据契约和业务规则，平台 UI 独立。iOS 不引入 `Process`、`Pipe`、shell、`chmod`、PATH、下载的可执行文件或其他浏览器 Cookie 提取。
- 视图只向应用服务发意图、观察状态；不直接调用 resolver、`URLSession`、`AVPlayer` 或修改 SwiftData。Catalog 不获取媒体流；播放层不建立音乐目录。
- 每个可见控件必须匹配实际能力。IFrame 不提供原生 PCM，EQ/频谱/音质徽章不能伪称生效；受限能力应隐去或解释原因，而不是展示永远“准备中”的假状态。
- 单一真值、明确取消、可测状态机、失败可恢复、可观测性能。Swift 并发中避免共享可变状态和用 `sleep` 修竞争；不通过 singleton 修依赖注入。
- 对现有 macOS 使用者保持行为兼容与升级路径；最终让 macOS 消费共享核心，但不在早期把 iOS 重构强行耦合到 macOS 的发行周期。

## 3. 目标模块、依赖和代码所有权

目标结构可逐步形成，不要求一次创建所有空包：

```text
Apps/MusesIOS                  iOS composition root、场景、路由、生命周期
Apps/MusesMac                  macOS composition root（后期迁移）
Packages/MusesDomain           强类型 ID、Track/Release/Artist/Playlist、能力与错误
Packages/MusesCatalog          官方目录查询契约、映射、分页、搜索与 Home
Packages/MusesPersistence      SwiftData schema、迁移、repositories
Packages/MusesQueue            确定性队列状态机与快照
Packages/MusesPlayback         PlaybackCoordinator、官方播放器协议、时钟
Packages/MusesAudio            获权/本地媒体用 AVPlayer、AVAudioEngine、DSP
Packages/MusesNetworking       HTTP、重试、节流、认证桥、指标
Packages/MusesArtwork          图像加载、尺寸与调色板缓存
Packages/MusesSystem           iOS/macOS 各自系统集成契约
Packages/MusesDesignSystem     token、布局规则、无业务状态组件
Platform/iOS                   IFrame/WKWebView、音频会话、通知与扩展
Platform/macOS                 yt-dlp 等只属于 macOS 且经过分发审查的 adapter
Server/MusesMediaGateway       条件性方案；不纳入当前公开版构建图
```

依赖方向：`UI → Application Services → Domain + Ports ← Infrastructure Adapters`。Domain 不导入 SwiftUI、UIKit、AppKit、AVFoundation、WebKit、SwiftData、yt-dlp 或网络 DTO。不存在 UI→yt-dlp、Feature→具体 resolver、Catalog→StreamResolver、Gateway→用户资料库的依赖。每个包定义公共 API 和最小可编译目标；先抽边界再物理拆包，防止过早切包造成循环依赖。

### 3.1 身份与数据模型

强类型 `TrackID`、`ArtistID`、`ReleaseID`、`PlaylistID`、`VideoID`、`ChannelID`、`CatalogID`，在持久化和网络边界进行校验与编码。`Track`（用户组织的音乐实体）、`CatalogItem`（提供者结果）、`PlaybackSource`（可播放资源）、`Video`（YouTube 对象）不互相等同。来源可建模为 `.youtubeVideo(VideoID)`、`.localFile(BookmarkedFileID)`、`.authorizedRemote(ProviderID, ResourceID)`，但公开构建的可用来源由能力策略筛选。保留原始 ID 和 provenance，避免字符串/URL 在业务层到处流动。

SwiftData 存用户真值：收藏、播放历史、笔记、队列、导入关系、设置。可重建的封面、目录响应、分辨出的临时地址是缓存；定义版本、TTL、删除与迁移政策。历史记录与推荐输入需允许用户清除。建立 schema 版本、双向可读迁移测试数据、首次安装/升级/损坏恢复路径，不以清数据库解决迁移失败。

### 3.2 核心协议草案

```swift
protocol MusicCatalog: Sendable {
    func search(_ request: CatalogSearchRequest) async throws -> CatalogSearchPage
    func home(context: CatalogContext) async throws -> HomePage
    func artist(id: ArtistID) async throws -> ArtistPage
    func release(id: ReleaseID) async throws -> ReleasePage
    func playlist(id: PlaylistID) async throws -> PlaylistPage
}

@MainActor protocol PlaybackCoordinatorProtocol: AnyObject {
    var snapshot: PlaybackSnapshot { get }
    func load(_ source: PlaybackSource, context: QueueContext) async throws
    func play() async throws
    func pause() async
    func seek(to position: Duration) async throws
    func skip(_ direction: SkipDirection) async throws
}

protocol PlaybackAdapter: AnyObject {
    var capabilities: PlaybackCapabilities { get }
    var events: AsyncStream<PlaybackEvent> { get }
    func load(_ source: PlaybackSource, intent: PlaybackIntent) async throws
    func play() async throws
    func pause() async
    func seek(to position: Duration) async throws
    func teardown() async
}

protocol StreamResolver: Sendable {
    func resolve(_ source: PlaybackSource,
                 policy: StreamResolutionPolicy) async throws -> ResolvedStream
}
```

`StreamResolver` 与 `ResolvedStream(URL、过期、MIME、codec、headers、range、质量、provenance)` 仅供**获权原生媒体 adapter**；官方 YouTube IFrame 接收视频/歌单 ID，不返回媒体 URL。禁止为统一接口把 IFrame 的视频 ID 假装成流 URL。`PlaybackCapabilities` 明示 `seek`、`queueByID`、`backgroundAudio`、`audioProcessing`、`offlineMedia`、`rate`、`gapless` 等，由来源和 adapter 实际支持结果决定。

## 4. YouTube 公开版的数据、认证与配额

### 4.1 Catalog 与 Data API

公开版以官方 Data API 读取可提供的元数据、播放列表、订阅、频道、视频及明确的全网搜索；不把 Innertube、Piped/Invidious 或抓网页作为公开版的可用后备。现有 Innertube 模型可作为迁移参考，但不得让其 DTO 进入 Domain，且只有在对应接口获得明确可发布依据后才能激活。官方 Data API 并不等价于完整 YouTube Music 目录或个性化 Home；差距应在产品矩阵中保留。

- 已知链接/分享导入：在设备端解析并校验 video/playlist ID，保留原始 URL 供用户追溯；只在需要元数据时调用 Data API。
- 搜索：优先查本地资料库；仅在用户明确提交或合理 debounce 后调用官方 `search.list`，去重同一查询，取消过期任务。默认 `search.list` 是单独的每日 100 次调用桶；其他常见读取方法通常 1 unit/次，默认共享 10,000 units/日，实际以项目控制台和官方当前文档为准。公众规模下 100 次搜索很低，产品须有额度耗尽体验与官方扩额方案。
- 账号数据：`channels.list`、`playlists.list`、`playlistItems.list`、`subscriptions.list`、`videos.list` 依页面/用户动作分页、批量、增量读取。缓存遵守 API 政策规定的时限；ETag 优化流量不等于保证免计配额。
- Home：先展示可解释的授权资料、订阅、已保存收藏和本地历史；无法从公开 API 取得的 YouTube Music 专属个性化模块不伪造、不标为已复刻。
- 预算表记录“动作→端点→次数/页数→估算 unit→高峰 DAU→缓存命中→失败退避”；增加请求计数诊断，禁止用多个 Cloud 项目、用户自带开发者密钥或镜像服务分摊同一产品配额。

### 4.2 OAuth、权限和数据管理

现有桌面 loopback OAuth 不是 iOS 发布架构。独立 iOS OAuth client，使用 Google 支持的原生回调与 PKCE；最小 scopes，游客/只读/显式写入逐级授权。Token 存 Keychain，不记录在日志、缓存、崩溃报告或共享偏好。验收登录、过期刷新、撤销授权、切换账户、删除本地账号数据、分页冲突与网络失败。若官方 API 不支持某个 YouTube Music 用户数据功能，不借助浏览器 Cookie 绕行。

## 5. 播放架构：公开版与原生媒体共用编排，不共用假能力

### 5.1 单一状态与队列

`PlaybackCoordinator` 是 UI 的唯一入口；状态由 adapter 事件驱动，包括 `idle/loading/ready/playing/paused/buffering/ended/failed`、当前来源、队列 generation、当前位置、时长、错误与可用能力。时钟来源清楚：IFrame 使用 Player API 报告并校正，本地管线使用媒体时钟；UI 不自行推断“播放成功”。事件携带 generation，快速连点 Next、过期加载回调与销毁后的 JS 消息必须被丢弃。

`PlaybackQueue` 分 current/upcoming/history/sourceContext/repeat/shuffle/generation，随机顺序可重现并持久化。`playNow`、`playNext`、`append`、`remove`、`reorder`、`previous` 都有明确不变量；一次仅一个 owner 发起过渡。应用重启恢复来源、顺序、位置和模式，但不自动播放。仅当官方播放器允许时驱动 YouTube 前台队列；不保证不可用视频能被跳过或自动播放，用户可见的错误需标明原因。

### 5.2 官方 YouTube IFrame adapter（公开版 P1）

使用可见 `WKWebView` 与官方 IFrame Player API；保留原生的视频表面、YouTube 署名/控件/广告，不覆盖或缩成看不见的音频节点。先证明点击触发播放、inline 行为、同一 WebView 切换 video ID、播放结束/错误回调、前后台与页面切换时的暂停/销毁、网络断开与不可嵌入内容错误。IFrame 控制事件通过窄桥接转换成 `PlaybackEvent`；JS 消息做来源校验、generation 校验、最小权限。禁止把 WebView 音频接入 AVAudioEngine 或用静音/隐藏播放器实现后台播放。当前 `YouTubeVideoStage.swift` 是原型入口，需由二级 sheet 调整为官方主播放的可见呈现；现有原生音频挂起语义也应随主播放替换。

iPhone 播放屏应持续显示满足官方要求的视频区域；队列、歌词、章节、评论不能遮挡播放器关键内容或让视频退到后台继续播放。小尺寸 MiniPlayer 可以展示状态和打开播放页，但不能承载正在播放的隐藏 YouTube 播放器。iPad 可在分栏旁保持足够大的可见播放器。嵌入内容如果拒绝播放，提供明确提示与“在 YouTube 打开”动作，不改用流解析器兜底。

### 5.3 获权原生音频 adapter（条件性，独立构建与验收）

用户规格中的双管线完整保留为**条件性目标**：Streaming Pipeline 以 AVPlayer 快速首播与 seek；Decoded Pipeline 以 AVAudioEngine/PlayerNode/EQ/TimePitch 处理本地或明确授权可解码的媒体。`Hybrid Playback` 的 stream→decoded handoff 需对齐时钟、音量、rate、路由与播放意图，无双音、跳点和爆音；进行 A/B 听感与自动状态测试。绝不可用这套管线处理未获许可的 YouTube 视频音轨。

允许按媒体合同实现预解析、去重、range/segment 缓存、热磁盘缓存、缓存上限/淘汰、过期 URL 刷新、Prefetch、Gapless、Crossfade、EQ 和按需频谱。每项通过 adapter 能力声明与签约来源判断。若 AVAudioFile 对不完整容器有约束，保留 AVPlayer streaming，不能承诺“前 N 秒就可切引擎”。处理 HTTP 403/410、IP 绑定、签名/过期、seek/range 失败时遵守来源合同；未知原因上报结构化错误，不能无限重试。

原生音频的 AVAudioSession、耳机/蓝牙/ AirPlay route changes、interruption、锁屏/Control Center、后台 audio mode、Watch/CarPlay 只针对被允许的音频来源启用。BackgroundTasks 只用于非关键元数据/缓存维护，不能作为持续播放机制。频谱离开界面即停止，降低动态效果和后台关闭非必要刷新。

### 5.4 Media Gateway 的条件性设计记录

用户规格提出版本化 `/v1/playback/sessions`、session refresh、DIRECT/PROXY 两路和 stream health。保留为**未来获得相应媒体许可后**的架构选项，不创建公开版 YouTube 解析服务器。它不能用来绕过 Data API 额度或 YouTube 的音频分离、下载及背景播放规则。若真正启用，先明确来源授权、地域、成本、隐私、滥用防护、安全更新与故障 SLA；再实现 typed session request/response、过期时间、可重试错误、短期凭据、服务端限流、监控、IP/range 兼容与直连/代理成本模型。yt-dlp 若存在只能在有权使用的服务器/macOS 基础设施中充当内部 adapter，永不进入 Domain、iOS bundle 或公开版播放依赖图。

## 6. iOS 信息架构与视觉实现

### 6.1 内容覆盖

Home、发现、搜索、资料库和播放为顶层路径；资料库必须让艺术家、专辑、歌曲、收藏、视频、播客、订阅、歌单、历史可发现。对每项明确游客/登录/无网络/空库/失效内容状态，保留稳定身份、排序、筛选和大列表性能。上下文队列、笔记、歌词、视频/播客章节、评论只在可用 API、授权和播放器可见性支持下交付。播客若基于 YouTube 视频，同样受 IFrame 约束；倍速/15 秒跳转等依 Player API 实测能力，不按原生音频默认承诺。

### 6.2 平台布局

- **iPhone**：Home、发现、资料库、搜索四个清楚目的地；每个路由有独立返回语义。播放页以官方视频为主要可见内容，艺术品、元数据、队列与歌词围绕它布局；触控目标、单手操作、动态字体、VoiceOver、降低透明度/动态效果都要实测。
- **iPad**：`NavigationSplitView` 或等效自适应分栏，保留 macOS 的内容密度但使用 iPad 导航；宽度变化、横竖屏、键盘和指针都有布局规则。队列可为 inspector，但不得遮住官方播放表面。
- **设计系统**：从 Muses 的艺术品比例、深色氛围、排版节奏与品牌色提炼 token。iOS 26 使用系统 Liquid Glass 作为交互层；iOS 18–25 有系统材质后备。高对比度、浅色、动态字体、VoiceOver 和 Reduce Motion 是正式规格。平台系统控件优于复制 macOS 窗口样式。封面/调色板提取离开主线程，有尺寸级缓存；不能为每个滚动 cell 重复解码。
- **平台专属**：macOS 菜单栏、全局快捷键、桌面歌词、更新器和浏览器 Cookie helper 不移植。iOS 的分享扩展、Spotlight、Widget、Live Activity 等逐项核对价值和权限；扩展不得暗中续播 YouTube。

## 7. 网络、并发、缓存、错误与隐私

网络层集中构建 `URLSession`、超时、取消、指数退避与 jitter、429/5xx/断网分类、请求合并、分页和日志脱敏。主线程仅做 UI 状态发布；解析、图片处理、JSON 映射、数据库批量操作移到合适 actor/后台任务。`@MainActor` 只包需要 UI 串行语义的状态，加载任务携带 query/route/queue generation，过时响应不得覆盖新内容。Home 用符合政策的 stale-while-revalidate，断网显示有明确更新时间的可用本地内容。

错误统一为认证/权限/配额/网络/内容不可用/不可嵌入/播放失败/数据迁移/服务失效；用户文案给出可执行恢复动作，内部保留关联 ID 和脱敏诊断。不得静默改走非公开解析器。数据最小化：Keychain 保存 token；可清除搜索历史和收听历史；封面/目录缓存设上限与过期；系统日志不含 token、Cookie、完整私人歌单内容或媒体签名 URL。先做权限与数据流程表，再写隐私标签和上架材料。

## 8. 性能预算与观测

用户规格中的数值作为**获权原生音频实验目标**，不是官方 IFrame 的保证：冷启动首次可交互 <1.0s、热启动 <500ms、本地已缓存点按到声音 <150ms、网络未缓存 P50 <500ms/P95 <1200ms、成功预取切歌主观无缝、常用 UI 60fps 且 ProMotion 友好。测量环境、设备、网络、样本量与 P50/P95 必须记录；达不到时展示实测、瓶颈与可接受目标，不用不受控的 YouTube 广告/网络加载证明 iOS 代码回归。

App Store IFrame 路径单独测：点击到播放器 ready、点击到实际 playing、切歌到新视频 ready、缓冲和失败率、内存、WebView 数、页面切换销毁时间、能耗。公共指标：首屏、滚动丢帧、图像解码、SwiftData 查询、主线程阻塞、冷/热启动和登录/搜索的 API unit。使用 Instruments/OSLog，诊断默认不采集用户内容。建立性能基线，优化须提供前后同条件证据。

## 9. 工程阶段、交付物和阶段门槛

每阶段产出可运行纵向流程、设计/决策记录、测试证据、风险清单；不做一次巨大 rewrite 后才运行。阶段可在独立分支推进，但共享工作区存在未提交修改时先保护和归档现状。未完成的产品能力不标记为完成。

| 阶段 | 具体工作 | 可审查交付与退出标准 |
| --- | --- | --- |
| P0 基线与授权 | 冻结当前源码/工作区基线；macOS→iOS 逐屏/逐流程矩阵；官方政策、OAuth、配额和扩展 entitlement 审核；真机/模拟器测试清单 | 功能状态表、构建测试记录、许可/发布决策记录、API 预算表。未获权功能从公开版范围剔除 |
| P1 官方播放纵向原型 | 把 WKWebView 二级视频 sheet 演进为可见 IFrame 主播放适配器；JS 事件桥、状态、切歌/队列、错误；真机验证 | 从已知链接→前台播放→Next→离开页停止的演示；无原生媒体流解析兜底；真机记录与故障表 |
| P2 Domain 与持久化 | 强类型 ID、Track/PlaybackSource/能力/错误；SwiftData repositories/schema migration；Queue 状态机 | Domain 无平台依赖；迁移夹具与队列不变量测试；旧用户数据在更新后仍可读 |
| P3 Catalog、OAuth 与预算 | 官方 Data API adapter、分页、缓存、搜索、Home、iOS OAuth/PKCE、撤权；隔离非公开目录适配 | 游客/真实账号和限额场景全路径；请求量实测、缓存时效与隐私核对 |
| P4 应用编排与 UI | `PlaybackCoordinator`/`PlaybackAdapter`、iPhone/iPad shell、资料库全部入口、收藏/历史/歌单/笔记；Muses 视觉 token | iPhone 小/大屏与 iPad 横竖屏对照；可见播放器与队列状态一致；Accessibility 可操作 |
| P5 获权音频研究（条件） | 仅以本地测试媒体/明确授权来源验证 StreamResolver、双管线、handoff、EQ、Gapless、缓存 | 与公开版构建隔离；测试源授权记录、音频 contract tests、延迟/能耗实测。不得阻塞 App Store 主线 |
| P6 系统集成与发布 | OAuth/隐私、分享、Spotlight、Widget/Live Activity 的适用性；真机中断/切页/内存/升级；App Review 文案 | TestFlight/审核材料、权限清单、发布阻塞归零；受限系统能力无误导入口 |
| P7 macOS 迁移 | 在 iOS 核心成熟后让 macOS 使用共享 Domain/Queue/Persistence/Catalog；平台专属 yt-dlp 等留在 adapter | macOS 行为回归、无 AppKit 泄漏到共享包；删除重复模型与被替换旧代码 |

阶段依赖：P0 → P1；P2 与 P3 可在接口冻结后分支开发；P4 在 P1/P2/P3 核心稳定后集成；P5 独立于 App Store 交付；P6 通过后才对外宣称可发布；P7 在跨平台 contracts 稳定后进行。若新政策或明确授权改变门槛，先更新本能力矩阵与决策记录，再改代码。

### 9.1 每阶段的工程规则

1. 先读两个仓库当前源码、`AGENTS.md`（若存在）、工程设置、测试与旧文档；识别行为不变量和已有未提交工作。
2. 对新公共协议给出契约测试。旧测试只在仍表达正确行为时保留；删除绑定错误实现的测试并写对应新测试。
3. 保持可构建、可启动；每个阶段运行相关单元、集成和 UI 测试，记录设备/系统版本和实际命令。真机播放/音频/route/后台类结论不能由模拟器代替。
4. 测试快速多次 Next、取消搜索、登录过期、分页重复、断网恢复、低存储、WebView 销毁、schema 升级和播放器不支持内容。只做能验证状态不变量与用户行为的测试，避免与实现逐行镜像。
5. 对架构变化在 ADR 写明动机、备选、能力限制与迁移；旧模块稳定替换后删除，不保留永久双真值或仅为测试通过的兼容层。
6. 每个 PR/工作单元包含行为变化、迁移影响、测试证据、已知限制。远端推送、历史重写、删除其他人工作需按操作风险单独审视。

## 10. 最终验收定义

**架构**：Domain 无平台和媒体解析依赖；Catalog/Playback/Persistence 边界清楚；iOS 不使用 subprocess；iOS/macOS 有独立 composition root；公开版依赖图中没有 YouTube 原生流解析或 Media Gateway 后备。

**产品**：用户能从 Home/搜索/分享链接进入内容详情与可见官方播放，操作前台队列、保存收藏/历史/笔记和支持的歌单；资料库各分类可发现；游客/登录/断网/配额耗尽/不可嵌入均有可理解的路径。对无法复刻的 YouTube Music 私有能力列清楚缺口而不假装实现。

**数据**：老数据库升级后数据仍在；队列和随机顺序重启后可恢复但不自动播放；撤销登录可删除本地敏感数据；缓存过期、容量和政策限制经过测试。

**体验**：iPhone/iPad 不同尺寸、浅深色、动态字体、VoiceOver、Reduce Motion；滚动、动画和图片解码无明显主线程阻塞；播放器在播放时始终符合可见性要求。

**质量**：自动测试、UI 流程、真机播放、网络异常、快速交互、长时间运行、能耗/内存、签名与 App Store 发布材料均有证据；性能目标附测量环境与 P50/P95。获权原生音频能力若没有授权或未纳入发行构建，不作为公开版 DoD，也不能在商店描述中宣称。

## 11. 实施工作包与验收样例

以下工作包可作为后续对话拆分任务的默认粒度。每个工作包需包含设计、代码、迁移、自动测试和人工验收记录；不得仅以“文件已创建”关闭。

| 工作包 | 输入/边界 | 最小验收样例 |
| --- | --- | --- |
| W1 仓库与工程基线 | 两仓库 HEAD、未提交修改、Xcode/SDK、target、entitlement、依赖清单 | 从干净检出能复现构建；当前工作树变更不丢失；变更对应的风险和归属可追溯 |
| W2 能力决策引擎 | `ContentRights`、`DistributionCapabilities`、`PlaybackCapabilities`，由 composition root 注入 | 公开版 YouTube 只选官方 IFrame；无授权时 StreamResolver/媒体缓存/后台音频无法被路由触发 |
| W3 身份与模型 | 强类型 ID、来源、provenance、序列化/迁移映射 | 不同来源同名歌曲不会误合并；旧 stableID 可映射；无效 URL/ID 明确失败 |
| W4 队列与恢复 | 队列 generation、上下文、插播、重复/随机、持久化 | 快速 Next×10 仅最后一代生效；重启顺序和进度不漂移；不自动续播 |
| W5 官方播放器 | `WKWebView` IFrame、JS 桥、事件、可见性、生命周期 | 播放/暂停/切歌/结束/错误状态与实际视频一致；sheet/路由退出后无声音；不可嵌入有回退按钮 |
| W6 Catalog/OAuth | 官方 Data API、游客、最小 scope、PKCE、Keychain、分页 | 账号撤权后私有数据不继续展示；超过配额不重试风暴；重复/漏页可检测 |
| W7 持久化与缓存 | SwiftData migration、目录缓存 TTL、图像缓存、删除数据 | 旧数据升级无损；断网时展示标明时效的缓存；清除账号后敏感缓存确实删除 |
| W8 iPhone/iPad 信息架构 | 主页、发现、搜索、资料库分类、详情、播放、队列、设置 | 从每个入口到播放不超过合理层级；横竖屏与分栏切换不丢状态；读屏可到达所有主要操作 |
| W9 获权音频管线 | 隔离的测试源、AVPlayer/AVAudioEngine、session、DSP、cache | 仅在有权源上测点按延迟、handoff、seek、route、EQ、Gapless；不进入公开版构建图 |
| W10 发布与运维 | 配额看板、隐私标签、审核材料、诊断、迁移回滚策略 | 发布候选版的已知限制、真实账号/真机记录、审核截图和权限依据齐全 |

### 11.1 关键状态机不变量

- 一个 `PlaybackCoordinator` 在任何时刻最多拥有一个正在发声的 adapter。若切换来源失败，旧 adapter 的保留或终止由显式策略决定，不允许两个声源叠加。
- `load`/`seek`/`skip` 的异步结果都与请求 generation 绑定；旧结果不得覆盖当前来源、进度、队列或用户意图。`pause` 在缓冲中也应记录为最终意图，ready 后不能擅自播放。
- `ended` 只由适配器真实结束事件驱动一次。自动进入下一项之前检查 repeat/shuffle/可用性；失败项不无限循环。
- 视图消失、场景失活、WebView 被销毁后，JS 消息不得访问失效对象；播放是否继续由分发能力和当前可见 UI 决定，不由遗留 native engine 自行恢复。
- 用户资料库的 ID 和行为持久化，目录/媒体临时缓存可删除；缓存未命中或过期不能删除收藏或历史记录。

### 11.2 端到端验收场景

1. **游客**：首次启动→Home/搜索→打开可嵌入视频→可见播放→手动 Next→离开播放页，确认状态和声音一致、无账号令牌。
2. **登录**：iOS OAuth→最小授权→分页读取歌单/订阅→添加本地收藏→撤销授权，确认令牌与私有缓存清除，仍可访问游客内容。
3. **受限内容**：地区限制、删除、年龄限制、禁止嵌入、广告/缓冲、网络切换，确认错误可见、无解析流/镜像后备。
4. **配额**：模拟搜索桶耗尽、429 和 5xx；禁止无限重试，保留本地索引、解释恢复方式并记录端点级请求量。
5. **升级**：旧 SwiftData 样本升级后收藏、歌单、笔记、历史、队列和用户设置一致；故障时可诊断且不静默清空数据库。
6. **交互压力**：快速 Next/Previous/Play/Pause、反复进出 Now Playing、iPad 旋转/分屏、低内存回收、断网恢复；没有双音、幽灵播放器、崩溃或过期状态覆盖。
7. **辅助功能**：最大动态字体、VoiceOver 顺序、高对比度、Reduce Motion、浅/深色；播放器和关闭/错误操作都可访问。

### 11.3 测试层次与设备矩阵

Domain/Queue/能力策略用纯单元测试覆盖不变量；Catalog/OAuth 用脱敏 fixture 与可控 HTTP fake 覆盖分页、认证和配额；Playback 用事件驱动 fake adapter 做 contract tests；SwiftData 用旧 schema fixture 做升级与异常恢复；UI 测试覆盖关键导航和可访问性。官方 IFrame 的真机交互、播放结束、路由切换、系统中断和能耗无法由 fake 或模拟器替代，须在至少一台受支持 iPhone 和一台 iPad（或明确记录尚缺设备）上运行。不同 iOS 版本至少覆盖最低目标系统和当前发布系统；每项报告设备、系统、网络、测试视频、结果与限制。

### 11.4 发布风险登记

| 风险 | 触发信号 | 处理门槛 |
| --- | --- | --- |
| YouTube IFrame 在某些视频/设备不可播 | 真机错误率、嵌入限制、登录要求 | 不用非公开流解析兜底；提供 YouTube 外部打开和清晰文案，统计比例后决定产品范围 |
| 官方 API 不能提供 Music 专属首页/目录 | 目标画面与 Data API 返回不匹配 | 用明确可解释的订阅、歌单、本地历史替代；产品差距写入发布说明 |
| 搜索配额随用户增长耗尽 | 项目配额趋势或 403 quota 错误 | 本地搜索、提交触发、缓存、官方扩额和 UX 降级；不得用多个项目规避 |
| IFrame 广告/加载导致延迟目标失效 | 点按到 playing 的长尾增加 | 单独测量 WebView ready/playing，不承诺原生音频的 SLA；改善 UI 等待体验 |
| 旧 SwiftData 数据升级失败 | 升级测试或线上错误码 | 保留可恢复快照，停止写入/给用户恢复路径；不能默认删库 |
| 未提交工作或分支被覆盖 | 重构前工作树非干净 | 先盘点并保护改动，再选工作树/分支；不得为换架构无说明地覆盖用户代码 |

## 12. 参考与复核点

- [YouTube API Developer Policies](https://developers.google.com/youtube/terms/developer-policies)、[政策实施指南](https://developers.google.com/youtube/terms/developer-policies-guide)：音频分离、下载、后台/隐藏播放器、广告与可见性。
- [YouTube IFrame Player API](https://developers.google.com/youtube/iframe_api_reference)、[Google iOS 嵌入指引](https://developers.google.com/youtube/v3/guides/ios_youtube_helper)、[Player 参数](https://developers.google.com/youtube/player_parameters)。
- [YouTube Data API 配额](https://developers.google.com/youtube/v3/determine_quota_cost)、[配额与合规审核](https://developers.google.com/youtube/v3/guides/quota_and_compliance_audits)、[Google 原生应用 OAuth](https://developers.google.com/identity/protocols/oauth2/native-app)。
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)、[Ad Hoc 分发](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile)、[设备限制](https://developer.apple.com/help/account/devices/devices-overview)、[TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)。
- [yt-dlp 官方发布说明](https://github.com/yt-dlp/yt-dlp/blob/master/README.md)、[iOS Pythonista 支持请求](https://github.com/yt-dlp/yt-dlp/issues/11780)。

这些外部规则会变动；在 P0 和提交 App Review 前重新核对版本、原文和实施细节。本文是工程规划，不代替平台或权利人的明确授权。
