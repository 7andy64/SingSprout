# AI 节奏游戏 — 设计规格

**日期:** 2026-08-02
**项目:** 声芽 SingSprout v0.9.3
**模块:** 节奏部落 → 节奏游戏（AI 增强）

## 概述

在现有节奏游戏基础上新增"AI 创作模式"：用户选择音乐风格，AI（DashScope qwen-plus）生成音乐数据结构，本地 WavSynthesizer 合成音频，音符数据映射为游戏下落谱面。实现"AI 生成音乐 → 音频合成 → 谱面排列 → 节奏游戏"的完整闭环。

## 用户流程

```
节奏部落大厅 → 节奏游戏入口
  ├── 经典模式 → 选难度 → 随机音符 + 节拍音效（现有逻辑，不改动）
  └── AI 创作模式 → 选风格标签 → 生成中(加载动画) → 直接开始游戏
```

### 风格标签

| 标签 | 情绪 | BPM 范围 | 音乐特征 |
|---|---|---|---|
| 😄 欢快 | 明亮活泼 | 100-130 | 大调、密集节奏、跳跃旋律 |
| 🌙 舒缓 | 温柔宁静 | 60-85 | 长音、柔和和声、稀疏节奏 |
| ⚡ 动感 | 强烈节奏 | 120-150 | 重鼓点、附点节奏、电子感 |
| 🎹 电子 | 现代合成 | 100-140 | 锯齿波/方波、琶音、电子鼓 |

## 架构

```
┌─────────────────────────────────────────────────────┐
│                   RhythmGamePage                     │
│  ┌──────────────┐  ┌──────────────────────────────┐ │
│  │  经典模式      │  │  AI 创作模式                  │ │
│  │  (现有逻辑)    │  │  ① 风格选择 → ② 生成 → ③ 游戏 │ │
│  └──────────────┘  └───────────────┬──────────────┘ │
│                                     │                │
│                           AiMusicService             │
│                          ┌─────┴─────┐              │
│                          │ DashScope  │              │
│                          │ qwen-plus  │              │
│                          └─────┬─────┘              │
│                                │ JSON               │
│                          ┌─────┴─────┐              │
│                          │ 解析 +     │              │
│                          │ WAV 合成   │              │
│                          └─────┬─────┘              │
│                                │                    │
│                     AiMusicResult                   │
│                     ├── wavPath: String             │
│                     ├── notes: List<AiGameNote>     │
│                     └── tempo: double               │
└─────────────────────────────────────────────────────┘
```

## 数据模型

### AiGameNote（新增）

```dart
class AiGameNote {
  final int pitch;       // MIDI 音高 (0-127)
  final double startTime; // 开始时间（秒）
  final double duration;  // 持续时长（秒）
  final bool isPercussion; // 是否为打击乐
  final String? percussionType; // kick / snare / hh
}
```

### AiMusicResult（新增）

```dart
class AiMusicResult {
  final String wavPath;           // 合成 WAV 文件路径
  final List<AiGameNote> notes;   // 音符列表
  final double tempo;             // BPM
  final String mood;              // 情绪描述
}
```

## AI 提示词设计

System prompt 指导 AI 输出纯 JSON，包含旋律音符和打击乐：

```json
{
  "tempo": 110,
  "mood": "欢快跳跃",
  "melody": [
    {"pitch": 64, "startTime": 0.0, "duration": 0.5},
    {"pitch": 67, "startTime": 0.5, "duration": 0.5}
  ],
  "percussion": [
    {"type": "kick", "startTime": 0.0},
    {"type": "snare", "startTime": 0.5}
  ]
}
```

约束：
- 总时长固定 30 秒
- 旋律音高范围 MIDI 55-84（G3-C6，适合儿童）
- 五声音阶为主，避免不和谐音程
- 打击乐按 BPM 节奏框架排列
- 难度与风格联动：欢快/动感密度高，舒缓密度低

## 谱面映射规则

AI 音符 → 游戏下落音符的映射：

```
音高 → 轨道分配:
  MIDI 55-62 → 轨道 0（低音区）
  MIDI 63-70 → 轨道 1（中音区）
  MIDI 71-78 → 轨道 2（高音区）
  MIDI 79-84 → 轨道 3（最高音区，仅 4 轨难度）

startTime → 下落时间（直接映射）
打击乐 → 对应轨道额外增加同步音符（增强节奏感）
```

AI 模式下难度选择仍然可用，影响轨道数和下落速度，但不影响已生成的音乐内容。默认普通难度（3 轨）。

## 音频合成

利用现有 `WavSynthesizer`：
- 旋律音符 → 正弦波合成（`_WaveType.sine`）
- kick → 低频衰减正弦波
- snare → 噪声+正弦混合
- hihat → 高频噪声

采样率 22050Hz，16-bit 单声道 WAV。使用 `audioplayers` 播放。

## 错误处理与降级

| 场景 | 处理 |
|---|---|
| 未配置 API Key | 提示"需要设置 AI Key"，引导到设置页 |
| API 超时/网络错误 | 显示"AI 音乐家正在休息，先试试经典模式吧 🌱" |
| JSON 解析失败 | 降级到经典模式随机音符 + 节拍音效 |
| WAV 合成失败 | 降级到经典模式，仅用 AI 音符做谱面（无声） |
| 设备性能不足 | 直接用经典模式，不显示 AI 选项 |

## 文件变更清单

| 文件 | 操作 | 说明 |
|---|---|---|
| `lib/shared/services/ai_music_service.dart` | 新增 | AI 音乐生成服务，调用现有 DashScopeService.chatCompletion() |
| `lib/shared/models/ai_music_models.dart` | 新增 | AiGameNote, AiMusicResult 数据模型 |
| `lib/features/rhythm_tribe/rhythm_game_page.dart` | 修改 | 新增模式选择、AI 风格选择、加载状态、AI 音符渲染 |
| `lib/features/rhythm_tribe/rhythm_tribe_page.dart` | 修改 | 节奏游戏入口区分"经典模式"和"AI 创作" |

## 不做的

- 不修改经典模式逻辑
- 不动经济系统（AI 模式奖励与经典模式一致）
- 不动旋律闯关和声音收集
- 不做实时流式生成
- 不做用户哼唱转谱面（那是旋律闯关的功能）
