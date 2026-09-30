# Muses-Erato 项目质量、功能与体验评估

评估日期：2026-09-29（America/Los_Angeles）。源码基线：`a4b0760`。本次没有修改应用代码。

## 结论

项目已有扎实的值模型、队列、迁移与数据清理基础，但产品入口、构建配置和回归验证尚未收敛。下一阶段最有价值的工作是：让用户容易开始使用、让收藏和历史符合直觉、让 Public 构建能完整运行回归测试，并让播放或网络失败可以直接恢复。

本次主要评估当前 iOS Public 产品。仓库中的 macOS、Watch、Widget、继承服务和 Native 实验代码不等于当前 Public 应用已交付的功能。Public 使用可见 YouTube 播放器；实验 Native 的后台音频应独立评估。不要把两种构建的能力或测试结果混为一谈。

## 验证证据与边界

使用 `project-public.yml` 生成隔离工程，构建并启动 Public Debug 应用，iPhone Air / iOS 26.5 模拟器，成功。生成工程位于 `.artifacts/public-project`，DerivedData 位于 `/tmp/muses-erato-audit-20260929/DerivedData`。

| 本次运行 | 结果 |
| --- | --- |
| MusesDomain | 9 项通过 |
| MusesQueue | 3 项通过 |
| MusesPersistence | 40 项通过 |
| MusesNetworking | 4 项通过 |
| MusesCatalog | 28 项通过 |
| MusesIOSOAuth | 20 项通过 |
| Public 应用构建、安装与启动 | 成功；有一个原生播放器相关弃用警告 |
| Public 应用测试目标及一个搜索分页 UI 用例 | **编译失败，未执行测试** |

基础包共 104 项测试通过。包测试在 host macOS 运行，不能替代 iOS 应用级验证。应用测试失败原因是 Native 测试引用了 Public 配置下不存在的初始化参数和成员；详情见后文。

首启政策页使用普通启动捕获。后续截图使用 UUID 隔离资料库与 catalog fixtures，未登录真实 Google 账号。Fixture 图片为空，不能据此判断真实封面的加载质量。未验证真机长时间播放、真实 OAuth、iPad、深色模式、最大 Dynamic Type、VoiceOver 全流程、网络切换、Release 签名产物或当前外部审核状态。输入自动化没有成功产生可确认的搜索提交，因此错误态问题按源码证据报告，没有声称完成其视觉复现。

本次截图与包测试日志保存在 `.artifacts/quality-review-2026-09-29/`；此目录被 Git 忽略。本文截图使用当前工作区绝对路径，移动工作区时需调整链接。

## 当前优势

- Domain、Queue、Persistence、Networking、Catalog、OAuth 已拆为本地包，有独立测试和接口边界。
- 播放器事件有 generation、video ID 和当前实例校验；目录分页也有失效代数，降低旧请求覆盖新状态的风险。
- 导入保留重复条目和顺序，存储、迁移、删除范围已有明确设计与针对性测试。
- 用户笔记模型采用写入成功后发布状态的方式，值得推广到其他编辑流程。
- UI 已使用系统颜色、44pt 操作区域、Dynamic Type 分支、减少动画与减少透明度设置；卡片轮播最多创建五张卡片，有明确性能意识。
- Public 发布依赖通过单独配置去掉 YouTubeKit，源码 allowlist 有助于控制实际交付范围。

## 当前界面检查

### 1. 首次启动：可用，但阅读与理解成本高

![01 首次启动隐私政策](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/01-privacy.jpg)

整篇政策作为一个正文 Text 呈现，首屏缺少简短产品介绍，段落标题也缺乏视觉与语义层级。用户尚未了解应用就需要阅读长文本。

建议先用简短说明解释“搜索、整理视频、记录笔记”以及播放前台限制；政策页保留完整内容和版本化同意，以分节方式展示关键数据行为。复选与继续操作保持清楚，VoiceOver 能按标题定位章节。不要额外加入多页强制教程。[Apple Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

### 2. Home：导航清楚，下一步不够明确

![02 Home](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/02-home.jpg)

已有最近播放、账号播放列表和三栏导航。空历史只显示解释文字；打开链接藏在顶部图标中。账号登录入口主要位于 Settings，当前无内容的用户需要自己探索。

建议新用户首页直接提供“搜索视频”“打开链接”“导入播放列表”入口；未登录时提供就近登录操作。已有内容后优先展示继续观看、最近添加与播放列表。留白本身没有问题，问题是缺少与当前状态匹配的主操作。

### 3. Library：样式一致，但内容范围不易理解

![03 Library](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/03-library.jpg)

默认选中 Videos，首屏分类两端被裁切，空态仅解释需要导入或加入播放列表，没有直接操作按钮。源码中 Songs 与 Videos 都来自同一个播放列表成员集合；Favorites 和 History 又被这个集合过滤。

建议合并重复内容分类，保留“全部保存、播放列表、收藏、历史”。如果业务坚持仅展示播放列表成员，应明确命名为“播放列表中的视频”，并另设独立收藏和历史入口。空态直接提供导入和搜索操作，零条目时收起视图切换与清空按钮。

### 4. Podcasts：明确的无效入口

![04 不支持的 Podcasts](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/04-podcasts.jpg)

用户可以选中 Podcasts，但内容只告知本版本不支持。建议从当前主导航移除，待存在可用内容和完整流程时再开放。隐藏 Artists、Albums 后仍保留 Podcasts 的筛选方式说明分类可见性缺少统一能力规则。

### 5. Search：结构易理解，状态模型需要细化

![05 Search 初始态](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/05-search.jpg)

搜索框与视频、播放列表、频道分类清楚。源码用同一个空态处理“尚未提交”“查询无结果”“网络失败后无结果”，都提示输入并提交。API 不可用时仍允许提交，可能同时出现不可用提醒、未授权错误和初始空态。

建议使用 idle、loading、success、empty、error 状态；结果为空时复述查询，出错时显示对应恢复操作。按本地与 YouTube 来源区分结果，提供资料库内部搜索和排序。切换分类不应让用户毫无提示地消耗新的在线搜索请求。

### 6. Settings：组织合理，反馈应按操作隔离

![06 Settings](/Users/xiaotwu/Code/Muses-Erato/.artifacts/quality-review-2026-09-29/screenshots/06-settings.jpg)

账号、资料库与数据、播放、隐私与支持分组简洁，应保留。相关子页面复用全局 `failureMessage`，可能显示其他流程留下的错误。建议账号、同步、删除、播放分别拥有自己的操作状态与提示；提供 App 版本和构建渠道，便于支持排障。

## 按优先级排列的改进

P0：影响发布验证或产品事实一致性；P1：直接影响核心功能与稳定性；P2：改善规模、效率和精致度。

| 优先级 | 证据与影响 | 建议 | 验收标准 |
| --- | --- | --- | --- |
| P0 | `project-public.yml` 关闭 Native 条件，但继承 `project.yml:133` 的 ExperimentalNativePlaybackTests。测试第 17、46 行调用 Native 专有初始化器；Public stub 无此接口，实测编译失败 | 分离 PublicTests 与 NativeTests；为关闭 Native 的构建保留能力边界测试；提供清楚的 Public 与 Native scheme | 两种构建分别 build/test 通过；Public Release 保持 Native 不可用；CI 能发现配置漂移 |
| P0 | 当前政策声明 Cloud Home 请求和账户 Home 推荐；实际 PublicRootView 的 Home 只调用本地内容与账号播放列表。当前代码仍使用政策版本 2026-09-28.2 | 对照最终构建校正政策、同意版本、托管页面与产品说明；按构建渠道提供准确文案 | 实际构建的界面能力、网络行为和内嵌文档逐项一致；旧同意版本处理明确 |
| P1 | PublicYouTubeApp.swift:848 播放前必须取得 embedding status；没有 catalog 或状态请求失败会阻止加载。README 与搜索不可用文案却称视频链接仍可工作 | 修正产品承诺；保证发布所需 catalog 配置；区分未配置、网络故障、内容限制与配额耗尽，提供播放器内重试和外部 YouTube 操作 | 无配置、无网、配额耗尽、禁止嵌入、正常视频分别有正确状态；限制判断不被绕过 |
| P1 | `libraryTracks` 仅取播放列表成员，Favorites/History 再按成员过滤；未加入列表的视频可被播放、收藏，却不出现在这些 Library 分类 | 让收藏与历史独立于播放列表成员；或明确重命名并补独立入口 | 打开视频→收藏→离开→重启，用户能在收藏找到它；已确认播放的记录能在历史找到 |
| P1 | HTTP.swift:132 把 Retry-After 截到最多 2 秒；第 54 行只解析秒数字，忽略 HTTP 日期 | 解析两种格式；长等待直接结束自动重试，返回可恢复状态；无服务端等待值时使用退避和 jitter | `Retry-After: 120` 不会两秒后再请求；日期格式与任务取消有测试 |
| P1 | RequestBudget 仅保留内存计数，重启会恢复额度；Public session 每日设置 10 次搜索、100 次其他请求，用户缺少可理解反馈 | 保存日期与设备计数，区分本地预算与项目配额；合并重复请求，按需拉取账号分页，并解释恢复时间 | 重启不会清空当日计数；跨日正确恢复；错误能说明是设备限制还是服务端限制 |
| P1 | pause/detach 使用 `try? persistQueue()`，保存失败无反馈；time 事件只修改内存 checkpoint | 统一 checkpoint 保存策略：暂停、退出等关键节点保存，周期保存节流；失败记录本地诊断并给出适当反馈 | 注入保存失败与进程终止测试；恢复位置、队列和播放意图有明确预期；避免每秒写盘 |
| P1 | 约 1276 行 PublicYouTubeApp.swift 中 session 同时管理启动迁移、OAuth、搜索、播放、队列与删除；全局 failureMessage 被多个页面复用 | 先提取 PlaybackController、AccountSession、LibraryStore 与各流程状态；保留 composition root 组织依赖，不做全仓重写 | 各流程可独立测试；网络错误不会污染收藏或设置页面；晚到响应不跨账号或跨删除流程发布 |
| P1 | `.github/workflows` 当前只见手动政策发布，没有应用质量检查工作流 | 建立 PR 质量流水线：包测试、Public/Native 构建、应用回归；发布候选继续运行现有 artifact 审计脚本 | 新 PR 自动报告结果；构建渠道和测试目标错误阻止合入；日志不包含凭据 |
| P1 | 可见 Podcasts 无功能；Songs/Videos 内容重复；Home 和 Library 空态缺少直达操作 | 收敛分类，使用能力驱动可见性；增加就近搜索、链接、导入入口 | 每个可见分类有有效内容或可完成的首项操作；首次添加流程不需要猜图标 |
| P2 | history 用 ID 对 tracks 反复线性查找；searchItems 去重嵌套 contains；Library 投影重复展开成员 | 建立按 ID 的索引与投影缓存；先测大资料库，再决定后台计算与批量持久化边界 | 用 1k/5k/10k 项资料库测启动、切分类、搜索和刷新；以主线程耗时与滚动卡顿为证据 |
| P2 | 大集合卡片一次只突出一项，列表入口需要切换；展示偏好仅在视图 State 中保存 | 大集合提供列表、排序、筛选和资料库内搜索；保存用户展示偏好；卡片用于探索与最近内容 | 长列表快速定位目标；返回或重启保留偏好；卡片删除后焦点落在合理的条目 |
| P2 | 样式 token 主要只有颜色与 inset，字号、圆角和间距散落多文件 | 提取文字、间距、圆角与状态色 token；保留金色点缀和系统表面，减少重复容器；统一空态、加载、失败与封面占位 | Home/Search/Library/Player 四种状态的视觉一致；浅色/深色与增大对比度可读 |
| P2 | Public UI 以英文与字符串拼接为主，未发现 Public 文案本地化调用或字符串目录 | 若目标覆盖中文用户，补 String Catalog、中英文和复数；建立小屏、大字、VoiceOver 回归 | 标题、数量、错误和辅助标签一致本地化；最大字体下关键动作可见且顺序合理 |
| P2 | 删除的交互保护已有基础，但笔记、书签等用户投入内容缺少明显可迁移入口 | 提供用户自有笔记、书签、编辑与列表成员引用的导出/恢复；将备份格式和 API 展示元数据分开 | 导出→空资料库导入保留用户内容与重复顺序；不引入禁止持久化的 API 展示数据 |

Retry-After 的日期或秒数形式见 [RFC 9110 §10.2.3](https://www.rfc-editor.org/rfc/rfc9110.html#name-retry-after)。设备计数不能保护整个 Google 项目的共享额度，需要按真实 Cloud Console 配额建立容量预期。当前官方文档列出独立 search.list 调用配额，不能沿用旧成本假设：[YouTube Data API quota usage](https://developers.google.com/youtube/v3/getting-started#quota-usage)。

## 建议的产品方向与执行顺序

Public 当前最有支撑的定位是“整理 YouTube 视频与播放列表，并保留观看笔记和时间书签”。笔记和书签能形成区别于普通播放器的价值。若核心目标仍是后台听音乐，应将播放来源与 Native 验收作为单独产品决策；当前 Public 的前台播放约束需要在开始使用时讲清楚。

第一批：修复 Public 测试配置、补 CI、统一构建与政策事实、修正无配置视频链接承诺。这批完成后，才有可信的发布验证基础。

第二批：调整资料库范围与分类、补空态主操作、细化搜索和播放错误、修正 Retry-After 与预算持久化。用“新用户找到内容→播放→收藏或加入列表→重启后找回”作为完整验收流程。

第三批：逐步提取 session 职责、增加大集合定位、用户内容导出、封面与状态组件规范、中英文和辅助功能验证。保留已有迁移与写入后发布策略，不在架构调整时改变用户数据语义。

## 下一轮真实验证重点

- Public：真机首启、OAuth 成功/取消/失效、网络断开恢复、播放加载失败、切到后台与返回、收藏与历史重启恢复、账号撤销与数据删除。
- Native：单独验证锁屏、音频中断、耳机切换、失效流刷新、长时间播放；不能用 Public 模拟器结果推导。
- 设计：有内容与无内容、浅色/深色、小屏/iPad/横屏、最大 Dynamic Type、Reduce Motion、VoiceOver 的主任务。
- 数据：存储写入失败、重复导入、删除当前视频、进程中断恢复、旧库升级与用户内容导出回读。

建议记录启动耗时、播放准备耗时、失败与恢复耗时、滚动卡顿、内存增长和导入吞吐量。先形成基线，再制定预算；本次没有采集性能 trace 或用户行为数据，因此不提供虚构的性能分数、留存率或崩溃率。
