# 冻结播放器 / Queue 视觉复核

2026-09-30（America/Los_Angeles）。只读检查当前生产slice，直接查看 `.artifacts/session-player-layout/final7-attachments/manifest.json` 对应全部7张PNG；未运行模拟器/真机、不改生产、不提交。主协调报告的10 executions / 0 failures为行为证据，不代替本节视觉判断。

## 结论

**正常与最大字号竖屏播放器已明显收敛，没有从所查看截图确认新的P1布局问题。** 媒体→标题/creator→timeline/times→居中Play/Next/Queue→status的顺序清楚。长说明进入Playback info、notes进入sheet，不再主界面同时铺queue/notes/多段说明。Queue与notes控制图标直接可见，主Play最突出；当前源码将所有动态failure放controls之后，pending在同64pt按钮内overlay，符合“不随状态上下跳动”的要求。

推荐仅收敛以下小项，不新增功能、不要求重做架构：

| 项目 | 建议 | 证据与范围 |
| --- | --- | --- |
| [P2] Music封面呈窄竖条，像被裁切的重复视频 | 保留小而完整的方形/自然比例封面，外部200高容器内居中，而非把图本体强制60–160宽×200高scaledFill；iframe仍≥200×200，不扩大两块hero | `mediaSurface`当前artwork `.frame(width: artworkWidth,height:200)`；横屏附件可见封面被裁窄。属于cover视觉修饰，不需改变mode/engine |
| [P2] 常态status大字仍抢眼 | Ready/Playing/Paused可只保留辅助value或较低强调稳定status slot；pending/错误保留真实反馈。禁止缩小用户选择文字尺寸，建议减少重复内容而非强制小字 | 最大字号`98699185…png`的Ready占较大空间，普通`A4E18A0D…png`很轻。当前slot在controls后，不导致跳动；不属于状态逻辑缺陷 |
| [P2] Queue fallback仍称song | `Unavailable song`统一为`Video details unavailable`或`Unavailable item`，其余compact布局保持 | `PublicQueueTrackLabel`仍有song fallback；仅文案，不扩Library/Settings |

## 直接查看的截图与判断

- `A4E18A0D…png`普通字号Video、`98699185…png`最大字号Video：控件完整可见，没有大段说明插在slider与Play之前；最大字号长标题允许换行、creator单行，主控仍集中。底部留白可接受，不应为填白重新加无关卡片。
- `29FCB09D…png`真实Queue选择后的Playing：iframe与下方controls可见；title/creator清楚；不是Queue列表截图，不能据此签署Queue行密度视觉通过。
- `638F5BCF…png`普通、`E28C3BED…png`最大字号mini：Queue独立图标与Next可发现，title在mini允许截断；完整title由打开player读取。其他Library布局不在本次范围。
- `4384E0A6…png`最大字号Playback info：长说明仅在用户主动打开的sheet，符合从主页面移走长文目标；允许滚动，不应将其长文重新搬回播放器。
- `401E12B5…png`manifest标为Landscape Music and visible YouTube：本工具显示有大片黑区且右侧内容未完整呈现；原始附件为2736×1260，与工具呈现不一致，无法确定是捕获瞬间/预览方向/实际布局。**不以此附件签署横屏视觉通过，也不据此判定产品失败。** 建议主协调或owner直接打开原PNG核对，并给一张稳定横屏完整画面。已有viewport+controls几何断言通过记录继续有效，但不替代视觉证据。

## 代码复核与限制

- media mode使用同一`videoSurface`、frame随mode变化；声明≥200×200且无遮挡。两live切mode保持adapter/loadgen/pausedpos的测试由owner提供；本视觉复核没有重新执行。
- controls使用独立共享位置、pendingoverlay，错误之后；状态常态文字在controls后。普通内容切换导致title行数变化可能改变下方位置，这是换项内容变化，不能混同播放状态消息跳动。
- Queue upcoming行已有entry.id选中路径，compact封面40×40、subheadline/title+caption、6pt行inset、44pt点击区、独立overflow；重复occurrence选择不按videoID猜第一项。最大字号title不限行而自然长高，符合可达性；不能为密排固定高度截断。
- 这7附件不包含Queue列表的normal/maxtext画面，Queue compact实际视觉仍需owner/协调最新截图。原排序/删除/reopen与真实异video选择通过是行为证据；本检查不冒充已直接观察列表。
- 本次未覆盖Native新mode完整画面、iPad、VoiceOver焦点、真实手机横屏或状态切换的逐帧按钮位置；不声称所有平台视觉完成。Search仍待其owner最终freeze报告，不在本次签署范围。

冻结slice可继续集成验证；上述小项交主协调决定是否在本轮收敛，证据不足项准确保留限制，不扩大功能或默认请求新审批。
