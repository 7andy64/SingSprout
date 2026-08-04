# 声芽 SingSprout

> 为乡村儿童打造的音乐创作与自然探索应用

声芽是一株生长在童年记忆里的音乐小苗。孩子们在这里录音哼唱，AI 帮忙编曲配器，再把创作的音乐装进明信片寄给远方的家人——也可以走进田野录制鸟鸣水声，在节奏游戏中快乐律动。

## 核心功能

### 音乐树 Music Tree
录下你的哼唱旋律，AI 自动检测音高并生成完整伴奏（和弦、贝斯、鼓组），让简单的哼唱变成丰富的乐曲。

### 声音邮局 Voice Post Office
将创作的音乐作品制作成声音明信片，分享给家人朋友。支持文字留言和语音问候。

### 节奏部落 Rhythm Tribe
- **节奏游戏**：AI 根据你选择的风格（欢快/舒缓/动感/电子）生成专属音乐，音符从轨道落下，精准点击得分
- **旋律挑战**：实时音高检测，跟着旋律演唱
- **田野声音实验室**：录制自然环境声音，AI 自动识别分类

### 情绪电台 Mood Radio
根据你的心情推荐适合的音乐内容。

### 嗡嗡花园 Humming Garden
用音乐创作浇灌你的守护动物花园。

## 技术架构

| 模块 | 技术方案 |
|------|----------|
| 框架 | Flutter 3.x + Dart |
| 状态管理 | Provider |
| 路由 | GoRouter (ShellRoute 底部导航) |
| 本地存储 | SQLite (sqflite) |
| AI 引擎 | 阿里云百炼 DashScope (qwen-plus) |
| 音频处理 | YIN 音高检测 / WAV 合成 / just_audio |
| 安全存储 | flutter_secure_storage |
| 平台 | iOS / Android |

## 项目结构

```
lib/
├── app.dart                    # 应用入口
├── main.dart                   # main + Provider 注入
├── core/
│   ├── constants/              # 路由常量
│   ├── routes/                 # GoRouter 配置
│   └── theme/                  # 主题定义
├── features/
│   ├── humming_garden/         # 嗡嗡花园
│   ├── mood_radio/             # 情绪电台
│   ├── music_tree/             # 音乐树（录音+编辑）
│   ├── profile/                # 个人中心/账本/观察
│   ├── rhythm_tribe/           # 节奏游戏+旋律挑战+田野实验室
│   └── voice_post_office/      # 声音邮局（发件+写卡片）
└── shared/
    ├── models/                 # 数据模型
    ├── providers/              # 状态管理
    ├── repositories/           # 数据库仓库
    ├── services/               # AI 服务/音频处理/导出
    └── widgets/                # 共享组件
```

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行
flutter run

# 测试
flutter test

# 构建
flutter build apk   # Android
flutter build ios   # iOS
```

## 环境要求

- Flutter SDK >= 3.7.0
- Dart >= 3.0.0
- Android Studio / Xcode
- 阿里云百炼 API Key（用于 AI 编曲和语音功能）

> 在应用内"设置 → API 配置"中填入你的 DashScope API Key。
