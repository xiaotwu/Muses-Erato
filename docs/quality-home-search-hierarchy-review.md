# Home / Search 层级收敛建议

日期：2026-09-30（America/Los_Angeles）。用户最新反馈为按钮选项乱、难找，要求简洁直观重新设计。本建议覆盖 Home / Search，优先于早期规格中重复三操作与双 segmented 排列；不改变 Library、Settings、session 行为或已确认内容优先方向。不新增审批门槛；协调对话整合，UI stream 实施。

已检查当前 `PublicRootView`、`PublicSearchScreen`，并查看旧空 Home、普通字号本地 Search、最大字号本地 Search 实际截图：`.artifacts/quality-improvement/screenshots/home-empty.jpg`、`.artifacts/ui-quality/screenshots/search-local-dark.png`、`search-local-large-dark.png`。这些是本次重设计之前的截图，不是新方案验收。

最新用户实测偏好覆盖上一轮建议：Home 顶栏仅 **+**，Search 来源/类型合并至对应位置的 **Filters** 菜单，Queue 从所有全局顶栏移至 player/mini controls。以下布局已按此收敛；不再要求 Add 可见文字或正文两枚筛选菜单。

再次更新：用户真机反馈要求 **Search 提交图标化；右上 Filters 在前、Settings 最后；Source/Type 都为真正多选**。下文末尾“多选搜索与固定播放器控件”覆盖早期单选字段和文字 Search 按钮建议。UI owner负责搜索端到端，Session owner负责播放器；本检查不改变代码所有权。

## 推荐最终布局

| 页面 | 主入口 | 次要入口 | 内容 |
| --- | --- | --- | --- |
| Home 有内容 | Recently Played、Your Playlists 的实际内容 | 顶栏 **+** 菜单：Open YouTube link / Import playlist；Settings | 最近播放→本地列表→已登录账号列表；无底部重复三按钮 |
| Home 无内容 | 单卡内短标题 **Start your library**、一句解释、全宽 **Search videos** | 同一卡片内低强调 **Open link / Import playlist**，普通字号并排、大字竖排；顶栏同一个 Add | 不显示空 Recently Played；未登录不显示空 YouTube shelf，改一条可选 Sign in 行 |
| Search | 全宽清晰输入框、一次明确文字 **Search** 提交 | 右上 Filters 图标菜单内 Source / Type 两个带标题分节；当前来源与类型可用一行轻量摘要 | 单独结果区域；初始态一句输入建议，提交后状态和结果接替它 |

### Home

1. 导航栏 Home；右侧仅 **+** 与 Settings；+ 使用 ≥44pt 标签区域和 accessibilityLabel **Add to library**，menu 三项 **Open YouTube link / Import playlist / Create local playlist**。Queue 不出现在 Home/Search/Library 全局顶栏，改由播放器与 mini player 到达。空态说明改为 **Use + to open a link or import a playlist** 或直接描述任务，不再指向不存在的 Add 文字。
2. 有内容首屏先显示最近确认播放；有列表则直接可点击。不要加重复 hero、链接输入框、Start your library 或底部 Search/Open/Import 操作组。用户可用 Search Tab 搜索，用 Add 增加来源。
3. 无内容时使用自然高度的一个空态区，不把图标+说明单独包成大卡再将三个按钮散落其外。仅 Search videos 使用金色主按钮，点击设置编辑类型 Videos、请求一次输入聚焦，不自动搜索；Add 承接链接与导入。
4. 空态就近添加入口采用主协调的单卡内 **Open link / Import playlist**，仅 bordered 或 text 次操作，不能三个同尺寸金色 pill 分散在卡片外。顶栏 Add 作为所有状态固定的添加位置，空态卡作为首次操作就近入口；不再额外放一条 Add a link or playlist，也不加正文链接输入框。普通字号首屏只有一个显著主按钮。
5. 未登录时不要在空态下面再展开 **YouTube Playlists + YouTube Music + Sign in + Account settings**。显示一句 **Your YouTube playlists · Sign in** 即可；OAuth 不可用则不提供登录行。账号列表真正有内容/加载/错误时才显示独立来源章节。外部 YouTube Music 入口保留在现有 Playback/Settings，不必在 Home 常驻争夺注意。
6. 有内容时章节标题 + See all；账号后续页 More/失败 Retry 留在该章节末尾，复用已修 continuation 行为。不能为了精简隐藏恢复动作或重新 reset pager。

### Search

1. 输入位于内容顶部：placeholder **Search videos, playlists…**（Saved 时 **Search saved items**）；一处清除 x 与一处提交按钮。普通字号可用右侧紧凑文字 **Search**；移除左侧装饰放大镜或避免右侧也只有重复放大镜导致“哪个是输入、哪个是按钮”不清楚。键盘 Search 同样可提交。
2. 来源/类型统一到 Search 右上角 Filters 图标 Menu，位置对应 Home 的 +，Settings 相对顺序一致。Filters label 用系统 **line.3.horizontal.decrease** 等可识别符号，44pt 区域，accessibilityLabel **Search filters**、accessibilityValue **Source: YouTube, Type: Videos**。Menu 内直接两个 Section **Source** / **Type**，不再嵌套两级菜单：Source = YouTube / Saved，Type = Videos / Playlists / Channels；Saved 不提供 Channels。每项 label 名称明确，当前选择显示 checkmark + selected trait，不能仅靠金色。修改只影响 draft，不请求网络。正文最多一条低强调当前范围摘要 **YouTube · Videos**；旧结果仍按 session submitted 身份标注。
3. 不常驻 “Search saved videos and local playlists without an online request.” 长说明；Saved 名称与结果来源已说明范围。仅配置不可用等真实限制保留紧凑说明，并靠近受影响来源，不能与结果错误重复成两张大 notice。
4. 输入区与结果区间距 20–24pt。结果区用 **Results for “query”** + 次级 count，避免在一行堆 count/query/source/type；需要来源时结果分节 **Saved / YouTube**。正文标题 primary，来源 secondary，金色用于操作而非每个结果标题。
5. draft 与 session submitted query/kind/source 继续分离。类型/来源改变但尚未提交时，旧结果头仍说明原 submitted 身份；无需不断插入新的长解释段打断视线，可用结果标题下短字幕。

## Search 状态

| 状态 | 呈现 |
| --- | --- |
| 初始 | 输入与控件 + 一句 **Search for a title or creator**；不显示 Results/0 results，不展示再一套开始按钮或 hero |
| 首批加载 | 结果区 **Searching…**；有本地结果先显示；不显示 No results；输入可编辑，阻止重复提交 |
| 有结果 | 查询标题/数量→来源分节→结果列表→必要时 Load more；不重复初始说明 |
| 无结果 | **No results for “query”** / **No saved items match “query”**；一句建议与 **Edit search**，聚焦输入 |
| 首批失败 | 结果区一条原因 + **Retry**；保留查询，不伪装为空；可靠配置缺失用 Saved 的明确降级 |
| 有结果后失败 | 保留全部结果，错误与 Retry 位于失败来源/分页末尾；不重跑成功页，不置顶多次重复大警告 |
| 清除 | draft/submitted/错误/分页复位，回初始；不删除库，不发布晚到响应 |

## 最大字号与可达性

- 不缩小文本适配；输入本身占一整行，清除保持内嵌小图标，显式 Search 按钮移到下一行。装饰/操作图标使用约 18–20pt，点击区 ≥44pt；不让装饰放大镜和两个巨型按钮把 query 挤成几个字。截图中的 `Fix…` 是需要解决的空间分配问题。
- 右上 Filters 在最大字号仍为稳定大小图标与44pt区域；菜单项用系统字号、完整文字、Source/Type 分节和选中标记。正文范围摘要允许换行，不再次铺两枚巨大筛选按钮。
- 有内容 Home 最近播放/账号列表使用纵向行，不使用窄固定宽卡片截长标题；Add/Settings/结果 More 的符号保持稳定大小和完整辅助名称。
- 空态按钮自然换行；所有内容可滚动，最后一个结果/恢复动作不被 tab/mini player 遮住。正文聚焦顺序为输入→提交/清除→结果；导航栏 Filters 独立可达；焦点请求仅来自明确入口，不因普通切 Tab 弹键盘。
- 原有金色/系统背景/原生 presentation 保留；不增加渐变 hero、全页玻璃或新的动画风格。

## 本轮验收重点

普通字号空/有内容 Home：一眼可找到 Search 和 Add；链接/导入不再在正文与顶栏重复铺开。Search：一眼可区分输入、提交、过滤与结果；无需先阅读范围长文才能操作。

最大字号 Search：输入不被图标挤窄，能直接完成一次 Saved playlist 搜索并查看首结果；Home 能发现 Add 并执行链接/导入。保留独立提交身份、分页 Retry、Saved 禁 Channels、Search videos 聚焦的现有回归，不因视觉精简撤掉正确状态处理。

本文仅设计审阅；新截图/模拟器/新增测试及新提交由实施与主协调完成。旧 freeze 的 CI 结果只能代表旧源码，不作为本次重设计的质量结论。


## 最新约束的聚焦检查与少量实施意见

本次只读快照仍有上一轮 `Add +`、正文 `filters` 与全局 queueToolbar；UI/Session owner 正在实施，不能将这些中间状态当成最终缺陷。

1. **Filters 展开即看到两分节和选中值。** 按 Source / Type 分节平铺、打勾，不只提供两个无当前值的子菜单；打开过滤器不提交，关闭后结果不被 draft 重标。最大字号和 VoiceOver都确认当前选择可读；数据源不可用项说明原因。
2. **Queue 至少有一个直接按钮。** full player 主控制附近显示 list.bullet 按钮，label **Queue**、value **N upcoming**；mini player 用同符号独立44pt按钮，tap mini主体仍进入player，tap Queue只打开队列。不要把Queue藏进播放器More的第三层或只靠长按。关闭Queue返回原播放器，不重置播放/位置；清空是Queue页内另一个确认动作。
3. **只有 upcoming、没有 currentTrack 时仍可达。** 当前mini显示条件通常依赖currentTrack；移除全局Queue后，需Session/UI保证只排队尚未播放或恢复后有upcoming时展示轻量mini queue入口。不能制造空库无播放器无顶栏队列的孤立队列。相关展示状态由Sessionowner处理。
4. **+ 与 Filters 可见位置一致，辅助名称不同。** 不用两个同名More；Home为Add to library，Search为Search filters。图标尺寸稳定，不为最大文字放大到挤压标题；Settings保持独立。空态不再告诉用户找Add文字。

以上是最新偏好下的设计要求；未执行新截图/模拟器，也未编辑生产代码。Queue原有Native `player.queue`可复用，Public/mini入口需要同义辅助标签和跨present/dismiss流程验收。

## 多选搜索与固定播放器控件（最新用户反馈）

### 搜索：真正多选与结果层级

1. **提交改单个 magnifyingglass 图标**，固定约18–20pt、44pt触控区、accessibilityLabel Search；移除输入左侧重复装饰放大镜，为query留空间。最大字号图标不随文字无限放大；清除是另一个44pt xmark，不能替代提交。键盘Search保留。右上顺序从左到右 **Filters → Settings**，合并在同一处声明 toolbar顺序，避免跨父/子视图追加后排序不确定。
2. **Source与Type用集合选择。** 每个菜单项 toggle自己的 membership，不像当前scope/searchKind覆盖前项；选中checkmark + selected trait + 可读“Selected/Not selected”。Section Source = YouTube / Saved；Type = Videos / Playlists / Channels。同一轴为OR，来源与类型之间为有效组合交集：选Saved+YouTube和Videos+Playlists，返回这四类支持组合的并集。Saved没有Channels，不能虚构空本地channel组；YouTube未选时Channels不可选并解释仅在线可用。
3. **每轴至少一项。** 推荐不允许取消最后一项，菜单中该选项禁用但明确“至少选择一个来源/类型”；不要暗中把空选择当All。若移除YouTube使仅Channels失效，归一化为Videos并立即更新菜单值/轻量摘要，不更改已提交结果。线上不可用时禁用YouTube且保留Saved；取消/重开Filters不自动发送请求。默认保持YouTube+Videos，不默认勾全而扩大预算。
4. **编辑选择与提交快照独立。** 实际请求捕获query + sources集合 + kinds集合 + generation；result heading基于提交快照，切筛选时已有结果不重标。Filters accessibilityValue可读为“YouTube and Saved; Videos and Playlists”；摘要只显示一次，选多项可用“YouTube + Saved · 2 types”，不堆三个长说明。
5. **结果按Source一级、Type二级固定顺序分组。** Saved先、YouTube后；每组Videos→Playlists→Channels。单type可省二级标题但行仍有类型/来源。跨来源重复的相同(kind,id)保留Saved为主，附Available on YouTube或简单来源信息；不能按裸id把video/channel误去重。总数为去重后可见项，各分组计数与所见一致。多type不得合并成一个无法区分视频播放与列表/频道导航的大列表。
6. **每个在线type有独立分页/失败状态。** 本地结果立即显示；一个在线type失败不清另一个type成功结果，错误和Retry置于该组末尾，Retry只重试失败type/page。Load more属于其group，不以一个token分页所有type。在线多type需要多请求，session须纳入现有budget；禁止筛选每次勾选即发请求，禁止无条件预取全部页。统一空态仅全部所选有效group成功且都无结果；partial失败不能写No results。

最小接口交付必须包含submitted sources/kinds和每group pager，不能只把UI改成多个勾号后继续调用旧single searchKind。UI owner负责协调所需session契约；本设计文档不要求其他线程直接修改其文件。

### 播放器：固定主控，状态在其后

当前Public `playerDetails` 在slider/Play之前依次插入queue failure、playback error、checkpoint failure、pending与command failure，状态增加/消失会改变控件y位置。这与真机反馈相符，优先修结构，不只设动画为nil。

推荐compact顺序：**可见video surface → 稳定标题/收藏行 → 时间进度 → 固定主控行（Play/Pause、Next、Queue）→ 可滚动辅助区**。标题普通字号最多两行，完整标题可在details读取；大字允许自然换行，其高度只随内容/字号变化，不能随播放状态变化。

- 主控区域在viewport中独立于错误/解释VStack，不能被动态消息顶动；Public主控保持64×64、其他≥44pt。pending仅在同一按钮frame内显示spinner或overlay，保留button identity与VoiceOver焦点；按session确认语义显示Play/Pause，禁用重复命令。不要在主控前插入“Pausing…”独立行。
- 状态常态不需要“Playing/Paused”与按钮再重复描述。用按钮accessibilityValue表达状态；必要的短状态放主控后固定单行status slot，其高度不因loading/paused/playing改变，空态不让后续控件跳动。错误长文在下方辅助区换行，不塞进固定slot。
- 辅助区按具体操作显示最多一个最相关错误，附必要Retry/Open YouTube；不同来源的保存失败/队列失败仍保留作用域，不能用删除文案方式藏掉真实失败。长产品前台说明进入已有Playback/详情；不在每次播放常驻大段政策/能力说明。
- Notes/bookmarks以一个明确入口或折叠区；Queue集中按钮/页，compact不要再铺完整queue+notebook全文令主播放器像多个页面拼在一起。iPad现有右侧queue可保留，主控左列固定；大字/小屏必要时video与控件使用有边界滚动布局，仍保证状态切换不改控件位置，不以固定总高度截断文字。
- Native当前主控前没有相同多message插入，但加载spinner替换Play仍应保持同frame/identifier；Native与Public辅助区遵循同层级，保留各自准确播放能力。mini player同样标题/Play/Queue稳定，错误不插在其控制之前。

### owner产物复核要点

搜索owner输出后核对：多选不是single互斥、源/type分节与checks、Filters先Settings最后、图标Search辅助名、submitted集合、去重计数、独立group分页与partial恢复、最大字号可操作。

播放器owner输出后核对：loading→playing→pausePending→paused→failed切换中主Play按钮位置/identity不变；错误/Retry可达且位于主控之后；Queue/notes发现性；Public visible player要求与Native差异未因精简被误改。证据应来自新owner源码和截图/回归，不将head9e64b0e或旧CI通过当作此次改动验收。待owner产物到达再只读复核，不启动真机测试或改共享代码。
