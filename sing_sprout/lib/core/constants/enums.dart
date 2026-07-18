/// 心情颜色枚举 — 孩子主动选择，不做 AI 自动判断
enum MoodColor {
  red('开心', '🔴'),
  yellow('兴奋', '🟡'),
  green('平静', '🟢'),
  blue('想念', '🔵'),
  purple('不开心', '🟣'),
  grey('说不清', '⚪');

  const MoodColor(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// 音乐风格种子
enum StyleSeed {
  morningDew('晨露', '🌿', '温柔钢琴治愈'),
  mountainStream('山溪', '🌊', '自然空灵'),
  frogDrum('蛙鼓', '🥁', '欢快律动'),
  random('随机惊喜', '🎨', '每次都不一样');

  const StyleSeed(this.label, this.icon, this.description);

  final String label;
  final String icon;
  final String description;
}

/// 音乐树状态
enum TreeState {
  blooming('🌸 盛开', '创作活跃'),
  growing('🌱 成长中', '稳步积累'),
  quiet('🍂 落叶', '最近较少活动'),
  thinking('🤔 沉思', '保存但较少分享'),
  sprouting('🌰 萌芽', '新手上路');

  const TreeState(this.label, this.description);

  final String label;
  final String description;
}

/// 声音样本类型
enum SoundType {
  humanVoice('人声'),
  animal('动物'),
  nature('自然'),
  mechanical('机械'),
  unknown('未知');

  const SoundType(this.label);

  final String label;
}
