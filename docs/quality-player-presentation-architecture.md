# 音乐 / 视频统一呈现架构建议

日期：2026-09-30（America/Los_Angeles）。只读设计建议，用户正在选择 Public 封面+可见视频与 Native 纯封面的边界；本文不替用户作该决定、不实施依赖 mode 的代码、不改共享生产文件、不测试真机、不提交 Git。

**已确认更新：用户选择 Public Cover focus 同时保留 visible video，Video focus 强调视频。** 此选择已授权owner实施，不再等待或增加审批。Network owner提供可选 `Track.contentKind`，取自YouTube category metadata并兼容旧Codable/metadata expiry；unknown默认Video。本文件保留分类与播放能力分离规则，music category不能推导audio-only。以下旧“待选择”描述由本更新和末尾落地意见覆盖。

## 推荐架构

**一个播放运行时、一个状态快照、两种呈现模式。** `cover/video` 是 presentation mode；`embedded/native` 是 engine route。切呈现模式不能隐式切 engine、重建WebView、重复记录history、清队列或再次open视频。现有 `PublicPlayerView` 按 nativePlaybackEnabled 分支并创建各自页面，可以先统一 shell/控件/state adapter，保留底层路由，不同时重写网络和持久化。

| 层 | 责任 |
| --- | --- |
| Playback runtime | current queue occurrence、engine、position/duration、confirmed state、pending command、failure、generation。当前曲目的engine与WebView/AVPlayer实例由runtime拥有 |
| Presentation state | `cover/video`、用户本次覆盖、metadata default来源、当前asset支持哪些mode；不发播放命令 |
| Stable media host | 持有一个iframe surface或AVPlayer rendering host，按mode改变frame/layout；保持identity，不在if cover / else video里各造一个播放器 |
| Player shell | 顶部模式选择、媒体呈现区、标题、时间轴、固定controls、Queue/notes；错误和解释在后方辅助区。Public/Native共享层级，各自capability决定可见选项 |

模式切换路径：检查当前asset capability → 更新presentation → 原实例重新布局。**没有** detach/attach、factory.make、load/cue/seek、engine停止或恢复播放。队列换项才进行必要load；用户点同队列行需要明确选择对应entry/occurrence并播放，不能把“打开详情”当选中播放，重复视频应按entry ID定位而不是video ID首匹配。

运行时可以由session/controller拥有；一个persistent host是实现要求，不强制引入新的顶级service。`UIViewRepresentable.makeUIView`只做构建，updateUIView不因mode发播放命令。避免`.id(mode)`、跨不同NavigationStack移view、mode变化的onDisappear调用detach。关闭播放器/后台暂停仍遵循当前Public生命周期规则，不能将模式切换混同真正关闭。

## 默认模式与真实媒体类型

模式优先级：**当前项用户明确选择 → 可靠媒体标记默认 → capability允许的保守fallback**。当前项选择保持到其queue occurrence结束；下一项重新计算default，除非用户另有已确认的全局偏好。异步metadata晚到时不在播放中突然改变已经呈现的mode；只更新下次default/解释，尊重用户覆盖。

- 可靠输入可来自明确provider media kind、已验证音轨/视频轨信息、用户显式标记Music/Video。存储时保留provenance，API展示元数据保留期限沿现有政策，不能为默认mode无条件永久缓存API响应。
- YouTube category Music只能说明provider分类，不证明asset是audio-only；music video仍有video track。Search的Videos分类不是音乐/非音乐内容分类；歌曲标题、artist字符串、频道名、缩略图方形、时长均不能推断类型。
- 当前链路如果没有明确music标记，值为unknown；Public fallback Video，Native audio-only fallback Cover。不要为了“按类型默认”引入猜title规则。是否增加用户“Default to cover for this item”可在主协调决定后做，不扩大本轮设置范围。
- 建议独立枚举：content classification `music/video/unknown` + provenance；playable capability `audioOnly/videoAvailable/embeddedVisibleRequired`。它们不能用同一个布尔isMusic表示。

## Public 音乐封面布局：可见视频作为硬约束

YouTube嵌入播放器要求至少200×200 viewport，controls需完整；不要用封面遮住、hidden/opacity、屏幕外或滚动出viewport的iframe来实现纯封面播放。尺寸按WebView实际CSS viewport核对，不能把200物理像素误当正确布局单位。[YouTube IFrame requirements](https://developers.google.com/youtube/iframe_api_reference)、[Required minimum functionality](https://developers.google.com/youtube/terms/required-minimum-functionality)

若用户选择Public“封面+可见视频”，推荐**cover模式强调音乐信息，不堆两个大hero**：

- 普通窄屏：顶部 Cover / Video selector；一个可见iframe保留在媒体区；其下是紧凑“封面缩略图 + 标题/creator”行（封面约64–80pt），时间轴与固定主控紧接。Cover模式不再另放全宽方形大封面；Video模式可增大同一iframe，其余行不重复标题。
- 若确实需要大封面，优先iPad横向分区（封面/信息一侧、可见视频另一侧），不要把视频塞到下方看不见的位置。小屏不足以同时展示大封面、≥200高视频和controls时，降低封面装饰尺寸，不降低视频或关键controls。
- 最大字号：可见video与controls组成稳定播放区，封面降为装饰小图或移除；标题和长说明可在下面可滚动details阅读。不把长标题、失败说明插在播放按钮之前导致按钮跳动。Landscape空间不足时采用side-by-side media/controls或可达布局，不自动hidden视频。
- 如果Public保持visible video无法满足用户想要的“纯封面”，界面应诚实称Cover layout（保留YouTube可见播放器），不暗示已切audio-only。纯封面仅在被确认支持的Native route考虑；不在mode点击时偷偷切Native。

这是受约束的推荐折中，不是用户选择的替代。首启和Playback文案也必须与最终选项一致。

## Native capability与统一控件

- Native仅解析到audio asset时，Cover可用；Video选项禁用并附短理由 **Video is unavailable for this source**，或仅提供Cover而不制造失效toggle。不能用封面动画、黑框或链接WebView假装video。
- Native确有video asset/rendering capability才允许Video，同一AVPlayer实例/position/intent不变。若从audio-only route切embedded必须换engine，那是明确的播放route操作，需单独加载/position移交/失败处理，不能包装成无缝presentation toggle。
- 顶部selector仅两项Cover / Video，当前项selected trait；capability unavailable时可解释。普通/大字都≥44pt，不给每项再增加介绍段。VoiceOver名称区分“Presentation mode”与播放源。
- controls固定在动态消息前。Play/Pause pending在同64ptframe内spinner或overlay，保留button identity、焦点与辅助label；时间monospacedDigit。模式切换不改playing/pending state，也不让status文字驱动controls位移。
- Queue从主控附近直接打开，行紧凑：小封面、两行标题/creator、当前选中标记、必要的overflow；tap行选择该occurrence并播放，拖动handle和delete为独立动作，不能因密排缩小44pt交互区。Queue reopen应反映当前排序和选中entry，现有重排/删除正确行为保留。

## 参考应用的使用边界

已打开用户指定的准确AppStore对象：[Demus](https://apps.apple.com/us/app/demus-easy-music-streaming/id6474685600)、[Lyra](https://apps.apple.com/us/app/lyra-music-radio-esound/id6747066887)。Demus介绍组织歌曲/音乐视频/播放列表；Lyra是音乐产品参考。可借鉴音乐中心的信息密度、媒体/标题/controls层级，不据营销文案推断Muses可用后台播放、无需账号或其他API能力；本检查没有安装操作两app，不把商店介绍当实机交互验证。

## 集成契约与验收

最小交付：一个observed playback snapshot；presentation mode；classification provenance；per-asset capabilities；stable host identity；只改变presentation的selectMode action。mode不得设置showPlayer false/nativePlaybackEnabled或调用open/attach。业务按队列entry ID选择播放的action由queue owner实现，不让UI自行重建队列。

owner交付后核对：

1. Playing/Paused/Buffering各状态反复切mode，engine实例和WebView identity保持，position连续、queue/history不重复；切mode没有网络/embedding重复校验。真正换项仍校验权限并失效旧响应。
2. Unknown metadata保守default；异步metadata不强切mode；music video与audio-only各自capability准确；禁止title猜测。
3. Public cover实际video可见、无遮挡、CSS viewport≥200×200、controls可操作；正常/最大字号、小屏/横屏布局分别验。本文未做真机/模拟器验证。
4. Native audio-only没有假video；Native video capability需真实asset验证，不能靠build flag就声称支持。
5. Queue tap播放正确occurrence，排序/删除/reopen继续通过；主controls在pending/error和mode切换时不跳，VoiceOver当前mode/选中entry可读。

当前选择已确认，owner可直接落实shared state、stable host、metadata/capability contracts与cover/video UI。Native video仍以实际asset capability为准，不因Public布局获确认就宣称Native有video。

## 已确认方案的落地检查意见

1. **Public两mode只改同一媒体区布局。** 模式selector在顶部。窄屏Cover focus用紧凑cover/title行（约64–80pt封面）与同一个可见iframe，Video focus提高video占比、减少cover装饰。不要两个全宽hero叠放。建议共享稳定media host在同一父路径，mode只传layout参数；当前源码`.onAppear`创建adapter、`.onDisappear`detach，不能让mode分支触发这两个生命周期。还需旋转/宽窄分支核对host不被重建。
2. **按实际viewport制定尺寸。** iframe可用宽W，目标高度至少`max(200, W*9/16)`，宽也≥200；以WebView CSS viewport读回验，不只检查SwiftUI外frame。小屏16:9原始height可能低于200，直接`.aspectRatio`后再`.frame(minHeight:200)`需确认内容host真实height而非仅外框空白。不要裁切YouTube controls/branding或加封面overlay；播放器本身的留黑可接受。保证title、controls与video可见的总空间预算，先缩cover装饰和间距，不能缩iframe违规。
3. **主控固定，错误在其后。** Cover/Video都共享同一timeline和Play/Pause row；同mode状态变化不改row位置/identity。最多一条稳定status slot，pending在64ptbutton里spinner；notes和长播放说明仍在单独sheet，queue失败/保存失败属于下方辅助区。若mode切换本身改变媒体区高度，可有一次可预测布局变化，但状态事件不得持续上下跳动。
4. **最大字号/横屏用明确降级。** Cover缩小或移除装饰图，长title在详情完整可读，控件≥44pt。横屏优先video与controls并列，辅助区滚动；不能滚动长正文把正在播放iframe推离可见区。必要时减少次要按钮，Queue与Play仍直接可达；不强行固定整页高度截字。
5. **contentKind是default提示。** `.music`默认Cover focus，`.video`/nil默认Video focus；按category而非title判断。metadata晚到/过期不在当前项播放途中突然切mode；用户当前项覆盖优先。metadata过期后按networkowner契约清classification，旧库缺字段正常decode nil，当前会话手动选择继续保持。
6. **Queue row选择必须完成播放意图。** 当前已有`selectQueueEntry(entry.id)`路径，owner需确认随后提交真实Play并等待确认状态，不只是更新current标记。按occurrence ID选择保留重复视频，pending/loading给同一行小状态，不跳变尺寸；其他row仍compact两行+overflow，重排handle与row播放点击区域分开。即使同video另一occurrence，也正确更新queue identity和后续顺序。

以上建议不阻塞已授权实施。本次读取仍是旧mode结构与正在集成的queue代码，尚无新mode截图/实例identity证据；owner最终产物到达后以其源码与回归复核，不将中间快照报告成最终失败。
