# Home / Search simplification

2026-09-30。用户实测在线搜索与播放正常，要求 Home/Search 更简洁直观。生产改动只限 Home/Search view 与相应 UI test adapter；Library/Settings/session/player 不重设计。

## 交主协调的具体方案（实施前）

已检查旧 Home/Search phone 截图及最新 iPad regular/大字画面。现状 Home 顶栏 link、空态三入口、有内容页底部三入口重复；Search 大搜索框/两排 segmented/来源说明/草稿说明/空态 card 同时出现，操作优先级混乱。

- Home：顶栏一个明确文字 `Add` 菜单，包含 `Open YouTube link` 与 `Import playlist`。链接仍进入原 sheet。队列与 Settings 保留原系统 toolbar。内容从 Recently Played → Your Playlists → YouTube Playlists 展开，没有尾部重复工具排。全空库一段简短说明和一个 `Search videos` 主按钮；有内容不显示空库 hero。YouTube Music 不在 section header 抢位，移入该 section 的 overflow 菜单。
- Search：搜索框占第一行；保留44点提交/清空以支持硬件键盘及点击提交。第二行只有两个菜单：当前来源（YouTube / On this device）与当前类型（Videos / Playlists / Channels）。菜单 label 为当前选择加小 chevron；不堆 source/type 前缀。普通字号横排，大字或窄宽度用 ViewThatFits 竖排，文本可换行；原最大字号菜单保留。删除常驻本地来源说明与每次改 draft 都出现的长提示；提交结果 heading 继续说明已提交 query、kind，新增 submitted source，确保草稿改变不重标结果。idle 使用简单标题与一句说明，不使用大背景卡。错误/无配置仅有对应必要 notice。
- 金色只用于主按钮/小图标，body 用 label 色；原低对比度与44pt修复保留。维持 session 的 submitted query/kind/source、clear cancellation、分页与 Retry 行为。

## Test adapter 影响

Home 原 `public.openLinkEntry` 顶栏 identifier 兼容保留在 Add menu。旧 open flow 在 tap menu 后增加 `public.add.openLink` action。Privacy gate 仅检查入口存在的断言不变。Home 有内容时不再出现 discovery 三按钮；Search quick-entry 的聚焦测试从 Library 的现有空库入口验证，或使用 Home 全空 fixture。Source/type 全部统一 Menu，测试通过选中 accessibilityValue 验证当前选择，不能再查询 segmentedControls。

不会为旧测试保持隐藏的重复按钮。新增视觉证据与 ordinary/max/iPad functional验证后补充结果。

## 与主协调/设计线整合后的最终稿

主协调进一步要求保留空态三项明确入口、Add 包含 Create local playlist、Search Menu 明确 Source/Type 前缀，并把 YouTube Music 留在 Settings 现有 provider links。采用这些约束：仅 Home 全空状态在一个自然高度区域内提供 Search 主操作和 Open link / Import 次级文字动作；有内容去掉全部重复 discovery。顶栏 Add 聚合三种添加操作，Queue 在 Home/Search 仅已存在播放内容时显示，Library 入口不改。未登录不渲染账号 shelf，避免 Sign in 广告。Search 框右侧显示 `Search` 文字提交按钮，只有左侧一个 magnifier；过滤菜单加 `Source:` / `Type:` 前缀，大字自然换行/竖排。idle 保留 `Find a video or playlist` 标题以提供可触及的键盘收起背景，但取消厚重 card 和重复说明。

最终实际 selector 正确命名为 `public.add`（不再使用 public.openLinkEntry），菜单 action 分别 `public.add.openLink` / `.import` / `.create`。所有现有 UI tests 的 gate predicate 已迁移到 public.add，所有实际 open flow 增加菜单 action 的第二次点击，包含 PublicLiveServiceUITests 和 Native test adapter；未改其播放或隐私逻辑。测试不再查询 Search segmentedControl，改查 Menu accessibilityValue，保留 saved scope 禁 Channels 的实际菜单断言。

Root 只使用局部补丁修改 Home/Search 前半；Session 线程和主协调修改的 scenePhase `suspendVisiblePlayback()` 与 Player 后半均保留。Library discoveryButtons 和布局完全不动。

预留原 UI 专属 phone `34668CCA-C1F0-4BB7-AB5C-8E5AAB3C0F6E`，iPad 回归仍 `753E6065-1F2D-4FBA-9DE7-4889EEAFF83A`。不占主手机/Privacy/Session simulator。隔离生成工程 `.artifacts/home-search-redesign/MusesPublic.xcodeproj` 与 DerivedData `/tmp/muses-home-search-redesign-20260930`；当前新设计已 build-run 成功，普通/最大字号截图与行为测试运行中。

首轮 phone UI：5/6 通过（ordinary/max hierarchy、分页Retry、draft类型/clear、键盘），唯一失败为 test adapter 把 Menu 实际 `video` accessibilityValue 写成 `Video`，已修断言。直接检查截图发现 toolbar 默认 style 隐去 Add 文字与大字 Source/YouTube 断词；分别强制 titleAndIcon、最大字号标题/值分行满宽，真实视觉缺陷已修。过滤菜单当前选项加入勾选图标与 selected trait。结果 heading 用同一 Text/AX id 分为 headline query 与 subheadline count/source/type，不嵌套重复id。idle精简成一条输入提示，相关键盘 tap test 使用 public.searchIdle。

复验 phone-corrected-ui 4/4 通过，大字菜单完整分行，截图已导出 `.artifacts/home-search-redesign/screenshots/`。但亲看截图，iOS 26 toolbar 对 Label 即使 titleAndIcon 仍只抽取plus；已进一步改纯 Text `Add +` 避免系统隐藏文字，后续必须再次截图验证，不依据 AX label 判断视觉可发现性。

## 主协调即时状态（07:45 UTC 左右）

暂未最终 production freeze：最后一处必要视觉修正是 Add menu 纯文字 `Add +`（代码已写，等待当前 phone run 完成后截图复验）。所有测试 adapter 包括 PublicLiveServiceUITests / Native / Privacy gate 已统一 public.add，旧ID无剩余；Root 非active suspendVisiblePlayback 保留，Player后半来自Session线不覆盖。当前可用于真机 QA 的设计内容已完整，最后的 Add 可见文字确认后预计不再改生产源码。现有 normal/max Search 图片：`.artifacts/home-search-redesign/screenshots/redesign-ordinary-search-idle.png` 与 `redesign-maximum-text-search-idle.png`；normal Home 同目录 `redesign-ordinary-home-populated.png` 是前一版只plus，不作为最终Add可见性证据，最终图片待覆盖。

空态真实测试额外确认 parent `home.empty` identifier 覆盖了三个按钮的独立 identifier；已把该id移至空态标题，保留三个控件各自id。三个操作始终实际可见，此修复恢复AX定位而不隐藏或删除操作。普通导入/本地结果回归已经通过，大字导入接续测试中。

## 新生产冻结（07:49 UTC 左右）

Home/Search 生产修正已写完，可据当前源码 build/commit；后续仅测试截图/文档。Add纯Text实测普通phone截图真的显示 `Add +`，空态三操作父ID修复后 AX恢复，两个plain次级按钮增加contentShape使实际AX命中高度44点（empty-hit-region-ui 1/1通过，0skip）。暗色截图显示金色填充的默认白字不足对比度，Home主Search与Search提交label显式使用systemBackground色：暗色为黑字、浅色为白字。没有改Library按钮或其它页面。

精确最新三文件 SHA256：`.artifacts/home-search-redesign/production-source-sha256.txt`。Root Player区域仍可能由Session线更新，本文冻结仅指Home/Search归属代码。最终normal/max有内容与空态截图将覆盖screenshots目录同名文件，不再把只plus版本当最终稿。

受影响测试已执行的边界：ordinary/max Import+local playlist Search+Home/Search返回各1项通过（empty-import-ui中的2个Import用例通过，2个empty旧parentid用例失败已修并分别复验）。不把失败bundle整体声明绿。phone-corrected-ui 4/4通过；最新纯Text Add和dark label版本的phone4视觉/功能用例运行中，随后执行iPad功能类。真实iframe/Play暂停由Session线独立验证；本线只更新其Add adapter，不宣称自己复验真实播放。

## 冻结版本截图与手机结果（最终）

**测试源码也已冻结（07:53 UTC 左右）**：所有必要 adapter、新 ordinary/max hierarchy/empty 测试均已写完；没有计划中的 test 改动。主协调可立即 commit/push当前UI与test源码启动 hosted CI。正在运行现有 MusesPublicIPad 四项用例；只追加证据和文档，不等待测试结束才能提交。

`final-phone-ui.xcresult` 4/4通过、0 skipped、0 warnings/errors：ordinary/max 空Home与有内容Home/Search菜单/本地空结果。此run的build包含07:49冻结三文件，所有 canonical截图现已用 final-phone-attachments 原始图覆盖，**不再是只plus版本**。

- 普通有内容Home：`.artifacts/home-search-redesign/screenshots/redesign-ordinary-home-populated.png`
- 普通空Home：同目录 `redesign-ordinary-home-empty.png`
- 普通Search：`redesign-ordinary-search-idle.png` / `redesign-ordinary-search-saved-empty.png`
- 最大字号Home：`redesign-maximum-text-home-populated.png` / `redesign-maximum-text-home-empty.png`
- 最大字号Search：`redesign-maximum-text-search-idle.png` / `redesign-maximum-text-search-saved-empty.png`
- Add菜单：`redesign-ordinary-home-add-menu.png` / `redesign-maximum-text-home-add-menu.png`

亲看最终普通有内容Home与Search结果，Add为真可见文字、无旧三操作尾排；结果query/title与count/source/type分两层，黑字/金色主按钮在暗色下清晰。最大字号Source/Type均标题/值分行满宽，搜索框不被提交图标挤窄。iPad回归使用 MusesPublicIPad scheme；首次误用手机scheme时0tests，明确不算iPad通过，已改正确scheme运行。

## 用户最新设计覆盖（toolbar refinement，当前进行中）

用户亲测确认新版更清楚，最新要求覆盖以上 Add 可见文字方案：Home 仅 + symbol（保留 Add to library AX label / public.add）；Search 来源和类型收至顶栏一个 slider.horizontal.3 菜单（public.searchFilters，44pt，AX值含当前source/type），两个 Source/Type 子菜单保留 public.searchSource/public.searchKind 与选中标记。Search 文字提交保留，内容筛选行移除。Home/Search queueToolbar已移除，Library/Player Queue由Session owner处理。

先前冻结因用户这次新要求解除，以上源/test更改已写完，当前普通/最大字号及empty实际菜单操作验证运行中。先前 iPad functional 4/4 passed、0failed/0skipped（155.8s），bundle ipad-functional-ui.xcresult；新版需重验受影响路径。

iOS18 CI已证实 emptyHome Menu exists=true/有效frame，但isHittable=false而实际tap可打开三项hittable菜单。empty测试保留exists、nonempty frame、inwindow并实际打开三项、打开Open link再Done返回，不盲加延时、不删操作断言。亲看当前 canonical redesign-ordinary-home-empty.png（07:49 final）明确Home title和Add+完整可见，因此此前无title/+图片不是该最终canonical内容；新版将全量覆盖同名图片并亲看。

Filters 最终采用平铺两 Section（Source/Type）及最多五个选项，减少子菜单展开。选项id为 public.searchSource.youtube / .saved 与 public.searchKind.video / .playlist / .channel；测试按打开filters→点可见选项，未保留隐藏的旧picker入口。顶filters AX值仍是当前source/type。当前生产/adapter写完，可用于主线构建；正在验证，此次新要求不能引用07:49旧冻结hash当新稿。新版截图会导至 toolbar-final-screenshots 独立目录，避免主线拿缓存的旧图片。

当前平铺方案 production/test source 均冻结（08:04 UTC），主线可立即build/commit/push；仅继续测试/截图/文档。Home/Search源已完工，未覆盖Session player最新更改。原最终07:49 canonical emptyHome真实图片标题/Add+完整；新symbol emptyHome ordinary/max实际tap+三项菜单、Open link/Done返回也passed。新版两张empty截图现有 toolbar-final-screenshots/ordinary-home-empty.png 与 maximum-home-empty.png；并非依赖isHittable=真就判断可发现性。当前无法复现持续隐藏toolbar；此前无title图片可能是旧artifact或同名路径缓存，尚未证明其根因。新目录避免复用图片URL。fresh-DD phone五项对nested版5/5通过，平铺最终版仍独立验证，不能混记。

平铺最终版 phone 5/5 passed、0failed/0skipped，104.2s，bundle toolbar-final-phone-ui.xcresult：普通/最大字号有内容与空Home、Add实际三个菜单操作、单Filters存在且旧内容筛选不存在、saved不含Channels、结果submitted身份、draft更改/clear。最新十张 final phone 图位于 `.artifacts/home-search-redesign/toolbar-final-screenshots/redesign-ordinary-*.png` 与 `redesign-maximum-text-*.png`。iPad四项本版本继续中，生产/test没有新增修改。

## 用户暂停请求（08:07 UTC 左右）

用户明确要求暂停并等待其后续命令。此后不再修改生产/test、不新启动构建/验证、不commit/push。平铺最终 phone 最小5项已完成5/5、0failed/0skipped；最新Home/Search普通/最大字号10张截图已保存 toolbar-final-screenshots/redesign-*.png。空态标题/+截图已亲看完整，无持续缺失复现；先前问题根因尚未证明（可能旧artifact/同名URL缓存），新图使用独立目录。

iPad四项命令在暂停消息到达前已经启动（toolbar-final-ipad-ui.xcresult）；消息到达时最大字号、横竖屏已通过，正在收尾此已有command，之后不开展新suite或截图扩展。主协调可保存当前工作区WIP。恢复需用户明确指示；不要自动继续。

暂停前已有 iPad command 已结束：toolbar-final-ipad-ui.xcresult，179.5s，3passed/1failed/0skipped。通过：maximum text landscape Library/Search/Settings、portrait/landscape entrypoints、regular sidebar rebuild local video/playlist/online identity。失败：testIPadWindowResizeEntrypoints，PublicIPadLayoutUITests.swift:212 的 XCTAssertTrue；此项保持未解决，不在暂停后修复或重跑。先前旧设计iPad4/4不能代替本版这一失败。最终phone5/5与iPad3/4状态分开记录。当前所有本线验证命令已结束；等待用户恢复命令。

失败精确为窄窗口 Add 的 `app.frame.intersects(addControl.frame)`（新增屏内frame检查）；同一case后续实际Add tap、三菜单hittable、Open link/Done仍执行，未报告这些操作失败。可能涉及iPad非零窗口origin的坐标空间，恢复后先核对保存bounds与AX frame，不删操作断言、也不先扩大生产修改。本次暂停不继续诊断。

## 恢复后的窄窗口最小修复

用户恢复任务。读取原失败附件，system bounds从(0,0,1032,1376)变为(329,219,375,823)；NSKeyedArchiver UI Snapshot根Application却报告(0,0,375,823)，其坐标原点不是窗口的屏幕位置。真实截图Home/+完整，实际tap和菜单断言已执行。仅test adapter改为 `app.windows.firstMatch.frame.contains(addControl.frame)`，保留完整屏内边界检查（比intersects更严格）及三菜单/链接/Done验证，增加Application/window/Add坐标附件。没有改Home/Search production或Session/Player。测试源码修复已写完，可冻结；仅重跑失败的testIPadWindowResizeEntrypoints，不重复全suite。

首次resume运行0/1failed仍指向旧app.frame.intersects，导出的附件没有新Add bounds。运行后检查工作区也仍为旧断言（测试文件另有新增6行），因此不能把该次当新坐标修正的回归失败。已重新精确写入窗口contains和bounds附件，并立即读回验证；保持其它新增测试/helper代码。最终source冻结以此读回为准。

## 窄窗口修复完成与冻结

`ipad-narrow-corrected-ui.xcresult`：仅重跑失败项 testIPadWindowResizeEntrypoints，1passed/0failed/0skipped，50.0s。最新几何附件明确：Application=(0,0,375,823)，window=(329,219,375,823)，Add=(574.5,233,58,36)。证实旧app.frame不含button是坐标原点差异；屏幕坐标window完全包含Add，真实菜单三项/链接Done及Settings路径全部通过。附件目录 `.artifacts/home-search-redesign/ipad-narrow-corrected-attachments/`，包含bounds与窄窗口截图。此前最新iPad另外3项passed保留，不把此次1项说成重跑完整suite。

仅修改PublicIPadLayoutUITests的边界断言及证据附件；生产代码未改。当前本线source/test均冻结，可以集成提交；不commit/push、不重复Home/Search phone或全iPad suite、不覆盖Session/Player。暂停状态由用户恢复指令解除，失败窄窗口现已解决。

## 实机反馈后的多选搜索方案

用户授权Search图标提交、顶栏Filters在Settings前、多Source/Type实际多选。实现将draft Sources/Kinds保存为集合，submit复制为固定集合；本地video/playlist与YouTube所选kind分组展示，各YouTube kind独立CatalogPager/cursor/error/retry。至少保留一个source/type；无API强制本地并去除Channels，混合源Channels只访问YouTube。本轮只改Search session/界面与Root Search toolbar入口，不触碰playerowner区域；单测覆盖实际请求kind、独立分页失败保留、submitted身份与重试、清除失效、无API/选择规范化。

多选首轮 unit4/4通过，UI普通/最大字号mixed source/type及draft清除3/3通过。UI截图保存multi-search-screenshots/{ordinary,maximum}-search-results.png，toolbar filter→settings实际frame顺序通过，submit icon AXSearch和44×44通过；提交both sources + video/playlist/channel，4项实际结果含local playlist、YouTube video/playlist/channel，切draft保留submitted heading。首屏各类型进一步改并行请求以避免慢组阻塞；Swift taskGroup触发本机编译器region isolation bug，改显式Task集合及取消传递后编译通过，最终unit4+UI3（含分页失败保留、Search videos shortcut）正在复验。没有修改Catalog解析/model owner区域。

集成编译反馈中的region-based isolation error已修：Search并行加载使用显式Task集合+cancel handler，编译成功（player owner可据当前源重新compile，不需要等待测试）。最终回归发现延迟响应test transport对两个old-kind均挂起、只有一continuation造成测试等待；修正为只挂起old video，旧playlist可独立完成，本线暂停自己对应xcresult的测试进程后重跑，不触碰他线sim/runner。

本轮Search生产与test源码已写完并冻结，主线可以build/QA；并行加载编译器问题已解决。当前只是最终4unit+4UI验证/截图，无计划中生产修改；如验证揭示具体问题再明确记录。Source/Type单选兼容测试通过selectSearchFilter helper先选目标再取消其它；实际多选UI测试直接toggle验证真实组合，不降级为单选实现。旧API `searchKind` 仅供Search videos快捷入口替换draft类型，不控制多选提交；session.searchSources/searchKinds是真实集合，submitted各集合独立复制。

## 多选Search完成与最终冻结

最终并行实现 `multi-search-final-verified.xcresult` 8/8passed、0failed/0skipped（103.4s）：4unit（实际多source/kind请求+独立分页失败保留+固定条件retry、至少一项/saved-only Channels规范化、迟返回隔离、原saved-only零网络retry）与4UI（ordinary/max实际mixed sources+3 kinds、分页失败保留与retry、Search videos快捷入口focus/no-submit）。没有重复整个无关suite。最终普通/最大字号图覆盖 `.artifacts/home-search-redesign/multi-search-screenshots/ordinary-search-results.png` 与 `maximum-search-results.png`，来自此最终并行版本；typed结果local/YouTube保留各来源身份并按各行count，不额外跨源去重。

最终源/test都冻结：Search session字段/方法、PublicSearchScreen全部、Root仅Search toolbar；PublicCatalogUITests新增多选普通/max并加入兼容单选场景helper，Import/iPad adapter用helper保持原单选意图，live Search error检查改per-kind id prefix。没有修改Catalog parser、category metadata或Player owner区域，没有commit/push。主线可基于当前工作区做最终集成/真机QA/CI。

## 多选菜单最后的交互完善

按主协调反馈，仅Search menu叶按钮加menuActionDismissBehavior(.disabled)，允许一次展开连续勾选；最后一个已选Source/Type呈disabled并提供至少一项AX hint，session仍保留集合非空校验。相关UIhelper改在同次展开内选择/取消，点击Search导航标题明确关闭菜单。普通/最大字号多选用例新增每次选择后menu仍在与最后选项disabled断言，测试源码已写完，3项针对性复验运行中。网络/session/parsing/Root未改；此前8项网络/布局验证仍记录为此前版本，不冒称新menu已通过。

Persistent菜单首轮已验证连续选择与last选项disabled，但导航标题tap不会关闭系统popover，后续输入被遮挡造成3项adapter失败。仅测试close helper改tap x=2%内容空白inset（位于菜单外且不触发row），并waitForNonExistence确认Source菜单项已移除；生产persistent/disabled保持不变。普通/最大字号+draft/clear针对性复验继续中。

Persistent-menu最终 targeted UI 3/3passed、0failed/0skipped，85.1s，bundle multi-search-persistent-menu-corrected.xcresult。普通/最大字号实际连续多选menu仍保持、最后Source/Typedisabled、混合结果4项、draft固定heading/clear通过。此前并行network/相关快捷入口与分页8/8保留，此次未改session/network。最新ordinary/max图片已从此bundle覆盖multi-search-screenshots目录，输入框fixture在最大字号仍正常显示，clear与44pt提交图标独立可操作。生产/test最终冻结，主线可集成；没有commit/push或编辑其它owner区域。

## 最新整合源 KeyboardDismissal 回归

针对旧9e CI唯一KeyboardDismissalTests失败，在当前完整工作区源（新Search persistent多选+其它owner当前改动）单独运行KeyboardDismissalTests.testOutsideTapDismissesHomeAndSearchKeyboard：1/1passed、0failed/0skipped，37.7s，bundle multi-search-keyboard-ui.xcresult。Home Open link sheet中实际点击public.linkHelp关闭键盘、Search实际点击public.searchIdle关闭键盘，两段原3秒断言均通过。没有放宽timeout、skip、sleep，没有改生产或测试；Search生产冻结持续。旧CI失败根因仍由CI证据分析，不把本机最新通过当旧source根因证明。

CIowner补充只读取证：旧run36773574420/head9e64b0e失败发生在第一次expectNoKeyboard（Home链接sheet），Search段通过；录屏74s键盘可见、76s/80s已视觉关闭并sheet回medium，但XCUI exists等待超时。这证实视觉关闭与AX存在报告不一致，未证明具体AX缓存原因，不据旧失败扩大生产修改。证据在 `/tmp/muses-hosted-36773574420/keyboard-after-help-76s.png`、`keyboard-timeout-80s.png` 与 `keyboard-activities.json`；本线没有重复fetch，保留当前新版实际1/1通过结论。

## b5157480 hosted keyboard间歇失败取证与拟修复

run36787236113失败仍在Home Open link首次expectNoKeyboard，Search段通过。public.log test t34.23点击public.linkHelp，事件plist实际点(151.333,259)对应说明文字；录屏31s键盘可见，36s及38s已消失并sheet回medium。证据文件/tmp/muses-hosted-36787236113/keyboard-{31,34,36,38}s.png与keyboard-activities.json。与9e旧失败相同视觉/AX不一致，add8及本机最新曾通过，不证明生产未dismiss。

t36.10通用predicate开始查询Keyboard.exists，t38.32内部retry1/retry2，t38.62外层3秒wait超时；嵌套隐式重试占据deadline，缺少及时无重试fresh absence评估。最小测试同步修复：改XCTest原生waitForNonExistence(timeout:3)，保持同一Keyboard查询、严格元素不存在、同3秒上限、原outside tap/keyboard出现/内容hittable断言，不改exists为hittable、删断言或加sleep，不改生产/布局/多选。此为可验证同步假设，尚待本机针对性复验及新hosted验证。

原生absence等待修复已完成，仅KeyboardDismissalTests.swift改3行。`keyboard-native-absence-wait.xcresult` SUCCEEDED；Xcode log明确Iteration1/3、2/3、3/3均passed（21.950s/21.626s/21.568s），每次实际Home帮助文字outside tap及Search idle outside tap两段、Keyboard先出现后严格nonexistence都通过。工具summary合并相同test identifier显示1passed，不把该summary误报成只执行一次。没有生产改动、timeout变更、skip、sleep、hittable替代不存在或布局修改。当前test source冻结、可集成；下一hosted需验证间歇同步失败是否消失，本机三次通过不等于已证实远程根因。未commit/push。

## 实机首次Open触摸保护最小生产修复

主线程授权，仅PublicKeyboardDismissal.swift增加轻量UIViewRepresentable marker及主线程弱UIView registry；delegate按同UIWindow、marker真实convert(bounds,to:window)判断触点，保护区return false。Root仅linkCard的public.open Button.background加marker。按钮action独占取消focus/关闭sheet/启动openLink，Help正文仍交给外点手势；既有UIControl、UITextView、alert过滤未动。没有SwiftUI global坐标猜测、AX/private类名、delay/sleep或全窗口手势泛改。

新增KeyboardDismissalTests.testFirstOpenTapWithKeyboardVisibleOpensPlayer：fixture fullURL输入后验证keyboard确实出现、按钮enabled，仅第一次tap public.open，原10s内iframe出现并3s内link sheet元素消失；没有第二tap或手动先收键盘。与原Help+SearchoutsideTap用例共两项sim验证运行中。生产修改意味着旧签名artifact不再匹配，QA/signed与真机操作由主线程重建负责。本线不操作device/commit/push；未触及Search/modes/Queue/palette/video区域。

Open保护修复验证完成：keyboard-protected-open-ui.xcresult 2/2passed、0failed/0skipped，55.3s。新首次Open用例在keyboard可见时一次点击直接进入iframe并关闭输入sheet；原Home帮助文字+Search idle外点后Keyboard严格nonexistence保持通过。当前keyboard生产/test源已冻结，无其它待修改项。Simulator证明回归路径正确，实机原失败根因的UIKit类型/触摸排序仍属推断，须主线程基于新签名QA复验一击Open。旧签名artifact不可当新marker代码验收。没有设备操作/commit/push。

## 首次Open实机证据更新与生产补丁撤销（2026-09-30 18:05 PDT）

本节更新上述保护区域方案的判断，保留先前记录作为历史。主线程实机 bundle `/tmp/muses-device-open-protected-live-20260930.xcresult` 中，fixture 首次Open用例通过（16.582s），三个live打开路径仍失败。只读附件 `.artifacts/remaining-quality/device-open-protected-attachments/manifest.json` 与事件archive发现：三个live Open实际触点均为(321.69,529.35)，失败AX中的按钮frame均为(293,161,68,58)，输入框仍Keyboard Focused且键盘存在。Queue输入值准确为M7lc1UVf-VE；另外两项发送完整URL，AX值截断，不能将发送字符串冒称完整AX字段值。

Queue录屏90E054E8-399D-42BE-B11F-4809B8E0A7C0.mp4在对应点击附近约10.38s显示键盘展开、Sheet从medium上移，按钮已移至约y=257…314，实际y=529.35触点落于按钮下方空白；11.2s时Sheet完全展开、键盘仍可见。因此有直接证据支持live在布局变化期间点击旧位置；没有证据据此归因网络或中文输入法组合状态。fixture输入后额外等待键盘存在并查询Open enabled，live原路径直接tap；成功fixture没有保存事件附件，不能提供其实际触点/frame作数值对照。

仅两个live测试文件修正布局同步：PublicLiveServiceUITests中的共享tapOpenLinkAfterKeyboardAppears helper等待Keyboard存在（原fixture同3秒），查询Open enabled/isHittable，读取当前按钮及窗口frame，保留几何附件，以当前frame中心转换为窗口坐标发送唯一一次tap；PublicLivePlaybackCommandUITests的Queue open helper及cycles打开路径均复用。无sleep、二次tap或提前dismiss，全部真实Playing/Paused、Queue、mode、横屏及前台生命周期断言保留。Swift语法解析及git diff --check通过；本线没有执行实机测试。

主线程随后报告当前frame同步修正后的实机结果：Queue真实actualPlaying与独立RealVisiblePlayer两项2/2通过；cycles/mode方法仅首Play pending阶段的AX bounds predicate失败，后续三轮均确认Playing/Paused，模式、横屏及前台要求均通过。因此不能把该方法或整组实机结果声明全部通过，剩余失败仍需主线程处理。

保护区域生产补丁缺少独立必要性证据：修前失败未排除同类旧坐标问题，修后fixture成功也不能单独证明marker因果。主线程已撤销未提交的PublicKeyboardDismissal保护区域35行及Root marker1行，Root/helper恢复HEAD；上述sim2/2与首次实机fixture通过仅代表当时含marker版本，不是撤销后生产源码验收。下一次实机验证将测试原生产源码配合已修正的live同步，尚未取得其结果。本线仅追加此文档，tests/production保持冻结，不再写入；实机操作、后续验证与集成均由主线程负责。

## 多选Search最终实机验收与冻结（2026-09-30 18:35 PDT）

实机菜单失败附件确认测试定位与菜单滚动问题，不需要生产修改。`.artifacts/remaining-quality/device-layout-final-attachments/` 的普通录屏AA2D3188-BA11-47A6-A572-774B426C2AC0.mp4在15.3s显示同一次展开连续勾选后五项全部选中、菜单持续打开；失败AX菜单按钮保留文字label却没有SwiftUI自定义identifier，菜单打开时背景Filters也未暴露。测试因此改用菜单实际文字按钮可点击状态验证连续选择，菜单内Channels移除/最后Source和Type禁用断言保持；关闭后原3秒等待文字菜单按钮消失，并检查Filters恢复exists/isHittable，再读取其value。

后续最大字号录屏 `.artifacts/remaining-quality/device-final-acceptance-attachments/F4C59272-E4A8-4D74-A254-9DC6B65B0FA7.mp4` 的15s画面确认菜单滚动至Type，固定顶部On this device已离屏，Playlists和Channels仍可见；仅将连续选择循环的post-tap检查目标改成刚刚点击的choice.isHittable。仍同次展开且无重开、无sleep，保留全部真实多source/type组合、四项结果、submitted身份、菜单内禁用和Channels移除断言。PublicQueuePlacementUITests.openPlayer同时复用此前当前frame唯一一次Open helper，生产和helper未再修改。

主线程最终实机验收报告11个distinct方法全部通过（多批针对性结果合计，不冒称单bundle全套）：普通多选31.114s、最大字号多选38.134s；撤销保护region后的原生产首次Open15.392s、Home/Search outside dismissal21.653s；Queue布局ordinary39.285s/max41.207s；三个真实player/Queue/严格几何/modes/lifecycle方法全部通过；Search11.386s；完整playlist最终125.232s。这更新上节撤销后待验证与cycles剩余失败状态，原生产首次Open和外点路径均已取得实机通过证据。真实播放及其它workstream详细附件由主线程质量记录负责，本线只引用其最终验收报告，不声明自己操作了实机。

QA已恢复normal启动，无fixture环境。本线production/tests/docs全部冻结，不再修改源码、测试或设备，不再发起验证；主线程可以基于当前工作区commit/push。本节仅追加最终证据，保留旧失败与旧版本验证记录及时间边界。
