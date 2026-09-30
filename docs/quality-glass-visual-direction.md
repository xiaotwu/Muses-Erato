# Muses 磨砂悬浮视觉方向

2026-09-30。设计 owner 文档；当前 CI 冻结，本轮仅写此文件。依据用户参考图、Liqui 文档、现有 Public 页面源码与此前 final9 / Search 截图复核。以下是下一轮实现方向，不是当前构建的视觉验收结论。

## 设计主张与范围

**封面先被看见，内容沉入深墨绿底，导航和播放控制轻浮在上方。** 参考图提供了大封面、安静文字、轻薄控制层的方向。Muses 的具体辨识点是同一播放器中封面与真实可见视频共同服务播放，而不是把参考图的纯音乐海报整页复制过来。

保留 Home / Search / Library 三个 tab；Home 右上是图标 `+` 与 Settings；Search 的 Filters 在 Settings 前，单一菜单分 Source / Type 两组多选，图标提交；Queue 只在 full / mini player；播放器主控先于状态与错误，长说明和 notes 在 sheet。Public iframe 的真实可见 viewport 至少 200×200，无遮挡，mode 切换仍使用同一播放实例。不得为了封面排版隐藏视频或改 playback 行为。

参考图中的 New Album、Popular Song、随机、重复、Previous、通知和个人中心只在现有功能确实具备时才可呈现。本轮不新增这些入口，不编造问候、推荐、专辑或内容数据，也不增加颜色设置项。

## 共用色彩与材质

金色点缀为**暂定推荐，尚未代替用户配色选择**；完全黑白绿方案共用结构。采用系统明暗外观，浅色使用轻微绿灰纸面，不强制全 app 深色。

| 角色 | Dark 候选 | Light 候选 | 使用 |
| --- | --- | --- | --- |
| canvas | `#101714` | `#F3F6F2` | 内容背景；深色顶部允许非常轻的静态墨绿渐变，底部回到 canvas |
| contentSurface | `#182722` | 系统 secondarySystemBackground | 内容分组与减少透明度 fallback；普通行可直接落在 canvas |
| primary | `#F3F6F4` | `#17251F` | 不透明品牌色面上的文字候选；原生玻璃优先 semantic primary / label |
| secondary | `#B7C4BD` | `#52645A` | creator、数量、来源；原生玻璃优先 semantic secondary / secondaryLabel |
| accent A（金色） | `#D7BA78` | `#765519` | 单一主动作实心底色、选中强调；深色金底使用 `#101714` 图标 |
| accent B（黑白绿） | primary | primary | 主动作使用明暗相反的实心面；墨绿仍来自 canvas，不使用低对比深绿文字 |

本地计算的 WCAG 静态对比：dark primary / secondary / gold 在 `#182722` 上分别 14.27:1 / 8.61:1 / 8.27:1；`#101714` 在深色金底上 9.69:1。light primary / secondary / gold 在 `#F3F6F2` 上分别 14.59:1 / 5.79:1 / 6.25:1。这些仅为不透明候选组合，不能声称截图、透明材质或真实原生控件对比度已通过；透明面需要在明亮封面、暗封面和滚动内容上测量。

材质分工：原生 tab / toolbar / menu / sheet 使用系统外观；自定义 mini player 使用一层 regular glass，已有 system accessory 时由系统承载，不再包第二层；主 Play 可以实心强调，其他动作单色。封面、结果行、Queue 行、Settings 内容组使用图片、实心底或标准 material，**不把所有卡片做成 Liquid Glass**。不使用网页 SVG 折射、彩虹边、持续光晕或重阴影；旧系统 fallback 为标准 material，Reduce Transparency 为不透明 contentSurface。

## 各页面可执行方向

以下尺寸是设计起点，不是 Apple 强制值。沿用页面水平 inset 20pt，主要模块间 24pt，模块内部 8–12pt；封面圆角 16–22pt，mini 圆角约 24pt，控制 hit area 至少 44×44pt。原生 bar / menu 尺寸交系统处理。

| 页面 | 结构与具体改变 | 必须保留 |
| --- | --- | --- |
| Home | 标题与 `+` / Settings 保持紧凑；首个已有内容区用大封面建立重心。Recently Played 与现有 playlist / saved 区继续以真实数据排列，横向卡片露出下一项边缘；以封面与间距分组，移除不必要外框。标题优先放封面下；已有封面叠字只用底部局部渐变保证可读，不把整张图压暗 | 现有数据来源、区块顺序、See all 和真实恢复入口；没有数据时现有空状态，不放虚构精选 |
| Library | 类别控件保持独立于内容；仅 selected 类别可用现有 glass 选择反馈。grid 用封面+下方标题，list 用紧凑封面+title/creator；播放/加入 Queue/更多仍是清晰独立动作。playlist hero 使用现有封面信息，背景墨绿强度低于图片 | Saved、Favorites、History 的独立含义与现有 list/grid 行为，最大字号允许标题增长 |
| Search | 顶部 Filters / Settings 由原生 toolbar 承载；输入框是稳定浅层内容面，清除与 44pt 图标提交独立。结果标题、已提交范围摘要、来源/类型分组以字重和间距区分，普通结果不逐行套玻璃胶囊；分页与错误留在所属组 | draft 与 submitted 状态分离，Source / Type 多选，组级分页/错误，最大字号摘要自然换行；不缩字来挤首屏 |
| Full player | 保留 final9 媒体区→title/creator→timeline/times→Play/Next/Queue/notes→status/errors。Music 的封面保持自然比例，视频单独可见；Video 以真实视频为首。标题可用 title2 semibold，creator 用 subheadline，时间用 caption+monospacedDigit。主 Play 沿用约 64pt 强调，其他动作沿用至少 44pt；不要为每个控制添加重边框 | Public 可见 iframe ≥200×200；同一 surface / runtime；主控不随 pending/error 上下跳动。真实视频周围及其上方不得加磨砂遮罩 |
| Mini player | 单层浅磨砂，封面沿用 46pt / 8pt 圆角，title 与实际支持的 creator 放左，Queue / Next 保留独立点击区域。Public 与 Native 按实际播放能力保留现有差异，不凭参考图给 Public mini 增加虚假的 Play | 已有 Queue 可发现性；tab 标签与 mini 不重叠；末条内容可完整滚到浮层上方 |
| Queue | 使用原生 sheet / List，背景比 full player 更平静；40pt 封面、title/creator、单独 overflow；当前项用符号/文字及弱选中实心面强调，不只变颜色。不做每行折射或大封面卡片 | occurrence entry.id 选择、排序/删除、自然行高与至少 44pt 点击区；Queue 不搬回全局 toolbar |
| Settings | 保留 insetGrouped、账户身份与 Library & data / Playback / Privacy & support / About 层级；内容组使用系统或实心面，行以 icon、label、chevron 组织。仅导航控制轻浮，状态文字维持 semantic label，危险动作使用系统 destructive | 用户能辨识现有状态与恢复动作；技术长信息保留在相应详情，不做账户封面 hero |

字体统一系统 SF：页面标题用原生 navigation title，区块 title2 semibold，正文 body，creator subheadline 或 caption，辅助说明 footnote。现有局部 serif 可在这轮视觉实现中统一成系统 title2，使封面承担个性；此项是设计判断，不是可达性失败。

Compact player 示意：`toolbar → mode → [cover + visible video / visible video] → title/creator → timeline → controls → feedback`。横屏保留 `左侧 mode+media | 右侧 details+controls`；宽屏可沿用现有独立 Queue 栏。宽度不足或大字号以堆叠与滚动处理，不靠缩字、裁切视频或压小点击区。

## 原生实现与交付边界

优先从 `PublicStyle` 提供语义 token，沿用原生 NavigationStack / TabView / Menu / Picker / List；复用已有 `PublicFloatingPlayerSurface` 和 Library 类别 glass，支持相应系统版本时使用原生 `glassEffect(.regular)`。用户参考图的轮廓高光与模糊只借鉴视觉，不移植 Liqui React / Base UI / Tailwind 依赖，也不修改 WKWebView 内容。

实现顺序建议：先统一 semantic token 与不透明 fallback，再校准 Home / Library 封面与文字层次，随后统一 mini / player 的控制材质，最后处理 Search / Queue / Settings 的面层一致性。这轮文档不授权改动冻结构建；实际实现由主协调安排。

实现后的验收由各 owner 执行：普通与最大 Dynamic Type、窄屏/横屏、light/dark、Reduce Transparency / Increase Contrast / Reduce Motion。大字号标题/行高增长，最后一条不被 mini/tab 遮挡；icon-only 动作有 VoiceOver 名称；选择除了颜色还有 checkmark/selected 语义。仅使用原生过渡，减少运动时不追加形变、漂浮或封面视差。iframe 尺寸与主控位置按原有行为验收继续验证。本轮未执行测试或声称这些已通过。

## 依据与来源

应用 [Apple design skill](/Users/xiaotwu/.agents/skills/apple-design/SKILL.md)，读取 accessibility、layout、typography、color、designing-for-ios、liquid-glass、materials、tab-bars、buttons、search-fields 共十份参考。引用遵循对应文件和标题：

- `materials.md › Liquid Glass`：“Don’t use Liquid Glass in the content layer.” 导航/控制与内容分层，玻璃克制使用。见 [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)。
- `color.md › Liquid Glass color`：“Apply color sparingly” 支持少量主动作强调、其他控件单色；语义色优先。见 [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color)。
- `typography.md › Supporting Dynamic Type`：“Make sure your app’s layout adapts to all font sizes.” 大字号改布局并允许内容增长。见 [Apple Typography](https://developer.apple.com/design/human-interface-guidelines/typography)。
- `tab-bars.md › Best practices`：“Include tab labels to help with navigation.” 三 tab 保留文字，不复制参考图只有图标的导航。见 [Apple Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)。
- `accessibility.md › Mobility / Vision` 的控制尺寸、对比与多重信息表达指导 hit area、fallback 和非颜色选择反馈。见 [Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。
- `layout.md › Visual hierarchy / Adaptability` 与 `search-fields.md › Best practices` 支持用间距组织内容、适配文字尺寸及分类结果。见 [Apple Layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[Apple Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)。
- [Liqui Quick start](https://liqui.design/docs) 是 React / Base UI 组件体系；[Liqui Glass](https://liqui.design/docs/handbook/glass) 说明背景、材质层次与玻璃使用克制。这里只将其作为视觉参考，iOS 使用原生能力。

参考图由用户提供：`/var/folders/k0/yh3b0gh10gjc2npv5kppjg4h0000gn/T/codex-clipboard-a6d2559b-ce3f-4ea6-8037-f8ad0d48fe34.png`。色彩、间距、圆角与本产品取舍是本设计判断，并非从截图精确量取或 Apple 强制规范。
