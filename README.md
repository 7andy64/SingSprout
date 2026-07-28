# 声芽 SingSprout

AI 音乐启蒙创作工具 — 为 9-12 岁乡村留守儿童打造

## 项目简介

声芽是一款完全离线、适配低配安卓手机的 AI 音乐启蒙创作工具，让孩子通过采集生活与自然中的声音、AI 辅助生成音乐作品，在实现音乐零门槛启蒙的同时，为情感表达与亲子沟通提供创作性载体。

## 产品架构（六瓣花）

```
         🧠 端侧 + 云端 AI 能力层
  哼唱识别 | 自动编曲 | 音乐生成 | 隐私加密

  🎵 哼唱花园    🎭 心情收音机    🎧 田野声音实验室
  🎮 节奏部落    🌳 我的音乐树    📮 声音邮局
```

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端 | Flutter 3.16+, Dart 3.2+ |
| 端侧 DSP | 纯 Dart YIN 音高检测 + 规则编曲引擎 + WAV 多轨合成（0MB 模型，完全离线） |
| 云端 AI | 阿里云 DashScope qwen-plus（编曲生成，可选增强） |
| 后端 | Python FastAPI, PostgreSQL 16 |
| 存储 | 阿里云 OSS / 本地加密存储 |
| 部署 | Docker Compose |

## 项目结构

```
SingSprout/
├── sing_sprout/           # Flutter 客户端
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── core/          # 主题、路由、配置
│       ├── features/      # 六瓣花功能模块
│       │   ├── humming_garden/   # 🎵 哼唱花园 (P0)
│       │   ├── voice_post_office/ # 📮 声音邮局 (P0)
│       │   ├── music_tree/       # 🌳 我的音乐树 (P0)
│       │   ├── mood_radio/       # 🎭 心情收音机 (P1)
│       │   ├── field_sound_lab/  # 🎧 田野声音实验室 (P1)
│       │   ├── rhythm_tribe/     # 🎮 节奏部落 (P2)
│       │   └── profile/          # 👤 个人中心 (P0)
│       └── shared/        # 共享组件、模型、服务
├── backend/               # Python FastAPI 后端
│   └── app/
│       ├── main.py
│       ├── api/routes/    # share, messages, health
│       ├── core/          # config, security
│       ├── models/        # SQLAlchemy models
│       ├── schemas/       # Pydantic schemas
│       └── services/      # AI enhance, etc.
└── docker-compose.yml
```

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

## 伦理与合规

- AI 角色为"音乐陪伴者"，非心理咨询师
- 心情功能由孩子主动选择，不做 AI 自动判断
- 所有个人数据默认本地加密存储
- 不采集儿童生物特征与身份信息

---

**让每一个乡村孩子，都被世界听见。**
