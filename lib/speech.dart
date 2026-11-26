import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'store.dart';

/// 诙谐语音鼓励（系统 TTS，中文）
class Speech {
  static FlutterTts? _tts;
  static bool _ready = false;

  static const List<String> _cheer = [
    '答对啦！真棒！',
    '哇，太厉害了！',
    '聪明！全对小天才！',
    '答对了，为你鼓掌！',
    '好厉害呀，再来一题！',
    '答对咯，奖励你一个小星星！',
  ];

  static const List<String> _encourage = [
    '哎呀，差一点点～',
    '不对哦，下次一定行！',
    '没关系，看讲解再来一次！',
    '错啦错啦，加油鸭！',
    '别灰心，你一定能做对！',
    '哎呀呀，这道题再想想～',
  ];

  static const List<String> _done = [
    '闯关成功，太棒了！',
    '全对！你是最棒的！',
    '搞定！可以去玩啦！',
  ];

  static String _pick(List<String> list) => list[Random().nextInt(list.length)];

  /// App 启动时预热 TTS 引擎，避免答题时首次初始化卡顿
  static Future<void> warmup() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
    } catch (_) {}
  }

  static Future<void> _ensure() async {
    if (_ready) return;
    _tts = FlutterTts();
    await _tts?.setLanguage('zh-CN');
    await _tts?.setSpeechRate(0.55);
    _ready = true;
  }

  static Future<void> cheer() => _speak(_pick(_cheer));

  static Future<void> encourage() => _speak(_pick(_encourage));

  static Future<void> done() => _speak(_pick(_done));

  /// 说一句指定的话（宠物饿了、提醒闯关等）
  static Future<void> say(String text) => _speak(text);

  static Future<void> _speak(String text) async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (_) {
      // 设备没有 TTS 引擎时静默失败，不影响答题
    }
  }
}
