"""
AI 增强服务 — 云端增强可选功能
仅在用户主动联网 + 选择"升级完整版"时调用
MVP 阶段可以为空实现，所有 AI 在端侧处理
"""


async def enhance_music(audio_path: str, style: str) -> str:
    """
    使用云端 GPU 升级音频质量
    TODO: 集成 MusicGen / Stable Audio
    """
    # MVP: 直接返回原文件
    return audio_path


async def text_to_speech_with_music(text: str) -> str:
    """
    文字转语音 + 自动配乐
    用于父母文字回复 → AI 朗读 + 背景音乐
    """
    # TODO: TTS + AudioCraft 配乐
    return ""


async def auto_accompaniment(audio_path: str) -> str:
    """
    自动配伴奏
    用于父母语音回复 → AI 添加背景音乐
    """
    # TODO: Basic Pitch 音高检测 + 自动编曲
    return audio_path
