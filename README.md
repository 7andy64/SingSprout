# 声芽 SingSprout

AI 音乐启蒙创作工具 — 为 9-12 岁乡村留守儿童打造

## 项目简介

声芽是一款完全离线、适配低配安卓手机的 AI 音乐启蒙创作工具，让孩子通过哼唱创作音乐，在实现音乐零门槛启蒙的同时，为情感表达与亲子沟通提供创作性载体。

v0.9.2 新增金松果经济系统和音乐游戏功能，通过玩游戏赚取金松果兑换虚拟物品，激励孩子持续创作。

## 产品架构（六瓣花 + 经济系统）

```
         🧠 端侧 + 云端 AI 能力层
  哼唱识别 | 自动编曲 | 音乐生成 | 隐私加密

  🎵 哼唱花园    🎭 心情电台    🎧 田野声景实验室
  🎮 节奏部落    🌳 音乐树      📮 声音邮局
  
         🌰 金松果经济系统
  钱包 | 森林集市 | 背包 | 每日挑战
```

## 功能模块

### P0 核心功能
| 模块 | 说明 |
|---|---|
| 🎵 哼唱花园 | 哼唱→音高检测→自动编曲→WAV 合成→编辑→保存 |
| 📮 声音邮局 | 音乐明信片收发，语音祝福，微信分享 |
| 🌳 音乐树 | 成长可视化，五阶段生命周期，双维成长（技能+心情） |
| 👤 个人中心 | 作品集、声库、家庭账本、角色切换、隐私设置 |

### P1 进阶功能
| 模块 | 说明 |
|---|---|
| 🎧 田野声景实验室 | 环境录音 + YAMNet 声音分类（521 类） |
| 🎭 心情电台 | 6 色情绪记录 + 哼唱 + 30 天时间线 |

### P2 新增功能 (v0.9.2)
| 模块 | 说明 |
|---|---|
| 🎮 节奏部落 | 游戏大厅：节奏游戏 + 旋律闯关 + 每日挑战 |
| 🥁 节奏游戏 | 3 轨道下落式，CustomPainter 渲染，Perfect/Good/Miss 判定 |
| 🎤 旋律闯关 | 目标旋律模仿哼唱，音高梯子可视化，音高匹配评分 |
| 🌰 金松果系统 | 虚拟货币，玩游戏/发现声音/每日挑战获得，每日上限 100 颗 |
| 🛍️ 森林集市 | 20 件虚拟物品：头像框、动物皮肤、树挂饰、信纸、乐器音色 |
| 🎒 我的背包 | 物品管理、装备/卸下 |

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端 | Flutter 3.16+, Dart 3.2+ |
| 端侧 DSP | 纯 Dart YIN 音高检测 + 规则编曲引擎 + WAV 多轨合成（0MB 模型，完全离线） |
| 端侧 AI | TFLite Basic Pitch（多音高检测，843KB）+ YAMNet（声音分类，4MB） |
| 云端 AI | 阿里云 DashScope qwen-plus（编曲生成，可选增强） |
| 后端 | Python FastAPI, PostgreSQL 16 |
| 存储 | SQLite 本地持久化 / 阿里云 OSS |
| 状态管理 | Provider（5 个 ChangeNotifier） |
| 路由 | go_router（5 Tab ShellRoute + 21 独立路由） |
| 部署 | Docker Compose |

## 项目结构

```
SingSprout/
├── sing_sprout/           # Flutter 客户端
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── core/          # 主题、路由、配置、枚举
│       ├── features/      # 六瓣花 + 商店功能模块
│       │   ├── humming_garden/   # 🎵 哼唱花园 (P0)
│       │   ├── voice_post_office/ # 📮 声音邮局 (P0)
│       │   ├── music_tree/       # 🌳 我的音乐树 (P0)
│       │   ├── mood_radio/       # 🎭 心情电台 (P1)
│       │   ├── field_sound_lab/  # 🎧 田野声景实验室 (P1)
│       │   ├── rhythm_tribe/     # 🎮 节奏部落 (P2)
│       │   │   ├── rhythm_tribe_page.dart   # 游戏大厅
│       │   │   ├── rhythm_game_page.dart    # 节奏游戏
│       │   │   └── melody_challenge_page.dart # 旋律闯关
│       │   ├── shop/             # 🛍️ 森林集市
│       │   │   ├── shop_page.dart          # 商品页
│       │   │   └── inventory_page.dart     # 背包页
│       │   ├── profile/          # 👤 个人中心 (P0)
│       │   └── onboarding/       # 引导页
│       └── shared/        # 共享组件、模型、服务、Provider
│           ├── models/    # 数据模型（含 economy_models）
│           ├── providers/ # 状态管理（含 EconomyProvider）
│           ├── repositories/ # 本地持久化（含 EconomyRepository）
│           ├── services/  # 音频、AI、DSP、数据库等
│           └── widgets/   # 通用组件
├── backend/               # Python FastAPI 后端
│   └── app/
│       ├── main.py
│       ├── api/routes/    # share, messages, health
│       ├── core/          # config, security, database
│       ├── models/        # SQLAlchemy models
│       ├── schemas/       # Pydantic schemas
│       └── services/      # OSS, TTS, WeChat, STS
└── docker-compose.yml
```

## 设计原则

- **离线优先**：核心音乐功能和游戏判定均在本地完成，无需网络
- **隐私安全**：所有数据默认本地加密，不采集设备指纹、不设排行榜
- **低端适配**：<2GB RAM 设备自动降级到 DSP 方案，CustomPainter 游戏渲染
- **儿童友好**：每日金松果获取上限替代防作弊、明码标价无盲盒、无社交比较
- **AI 角色**：AI 为"音乐陪伴者"，非心理咨询师；心情由孩子主动选择

## MVP 最小闭环

```
孩子哼唱 → AI 生成音乐 → 保存作品 → 一键生成音乐明信片
→ 微信发给父母 → 父母 H5 收听并语音回复 → 孩子收到回信
```

## 快速开始

### 后端

```bash
cd backend
cp .env.example .env
docker compose up -d
```

### 客户端

```bash
cd sing_sprout
flutter pub get
flutter run
```

### 构建 APK

```bash
cd sing_sprout
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

## 伦理与合规

- AI 角色为"音乐陪伴者"，非心理咨询师
- 心情功能由孩子主动选择，不做 AI 自动判断
- 所有个人数据默认本地加密存储
- 不采集儿童生物特征与身份信息
- 无设备指纹、无排行榜、无第三方埋点 SDK

---

**让每一个乡村孩子，都被世界听见。**
