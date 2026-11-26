import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'store.dart';

/// 烟花音效：运行时程序合成 WAV（爆炸"嘭"声 + 升空"嗖"声），离线可用
class SoundFx {
  static AudioPlayer? _boom;
  static AudioPlayer? _whoosh;
  static AudioPlayer? _chime;
  static AudioPlayer? _chew;
  static AudioPlayer? _lick;
  static String? _boomPath;
  static String? _whooshPath;
  static String? _chimePath;
  static String? _chewPath;
  static String? _lickPath;
  static bool _ready = false;

  static Future<void> _ensure() async {
    if (_ready) return;
    try {
      final dir = Directory.systemTemp.createTempSync('mathfx');
      _boomPath = dir.path + '/boom.wav';
      _whooshPath = dir.path + '/whoosh.wav';
      _chimePath = dir.path + '/chime.wav';
      _chewPath = dir.path + '/chew.wav';
      _lickPath = dir.path + '/lick.wav';
      await File(_boomPath!).writeAsBytes(_synthBoom());
      await File(_whooshPath!).writeAsBytes(_synthWhoosh());
      await File(_chimePath!).writeAsBytes(_synthChime());
      await File(_chewPath!).writeAsBytes(_synthChew());
      await File(_lickPath!).writeAsBytes(_synthLick());
      _boom = AudioPlayer();
      _whoosh = AudioPlayer();
      _chime = AudioPlayer();
      _chew = AudioPlayer();
      _lick = AudioPlayer();
      await _boom?.setVolume(0.9);
      await _whoosh?.setVolume(0.45);
      await _chime?.setVolume(0.6);
      await _chew?.setVolume(0.75);
      await _lick?.setVolume(0.7);
      _ready = true;
    } catch (_) {
      // 音频不可用时不影响游戏
    }
  }

  /// 爆炸"嘭"
  static Future<void> boom() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _boom?.stop();
      await _boom?.play(DeviceFileSource(_boomPath!), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// 火箭升空"嗖"
  static Future<void> whoosh() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _whoosh?.stop();
      await _whoosh?.play(DeviceFileSource(_whooshPath!), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// 得到新贴纸的"叮铃"
  static Future<void> chime() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _chime?.stop();
      await _chime?.play(DeviceFileSource(_chimePath!), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// 宠物吃饭的"咔嚓咔嚓"+ 满足的哼声
  static Future<void> chew() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _chew?.stop();
      await _chew?.play(DeviceFileSource(_chewPath!), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// 宠物凑过来舔一口的"啵啧"声
  static Future<void> lick() async {
    if (!ProgressStore().soundOn) return;
    try {
      await _ensure();
      await _lick?.stop();
      await _lick?.play(DeviceFileSource(_lickPath!), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// 舔一口：一下黏糊糊的"啵啧"（噪声包络 + 下滑的小音）
  static Uint8List _synthLick() {
    const rate = 44100;
    const ms = 300;
    final n = rate * ms ~/ 1000;
    final rnd = Random(21);
    final out = List<double>.filled(n, 0);
    // 前半：舌头贴上来的"啵"
    final len1 = (rate * 0.10).round();
    for (var i = 0; i < len1; i++) {
      final t = i / len1;
      final env = sin(pi * pow(t, 0.6).toDouble());
      final noise = rnd.nextDouble() * 2 - 1;
      out[i] += noise * env * 0.45;
    }
    // 后半：往回缩的"啧"（频率往下滑）
    final start2 = (rate * 0.12).round();
    final len2 = (rate * 0.16).round();
    for (var i = 0; i < len2; i++) {
      final idx = start2 + i;
      if (idx >= n) break;
      final t = i / rate;
      final p = i / len2;
      final env = sin(pi * p);
      final f = 900 - 560 * p;
      final tone = sin(2 * pi * f * t) * 0.5 + (rnd.nextDouble() * 2 - 1) * 0.25;
      out[idx] += tone * env * 0.5;
    }
    final peak = out.fold<double>(0, (a, v) => max(a, v.abs()));
    if (peak > 0.9) {
      for (var i = 0; i < n; i++) {
        out[i] *= 0.9 / peak;
      }
    }
    return _wav(out, rate);
  }

  /// 咀嚼声：4 下短促的"咔嚓"（噪声 + 一点低频），最后一声满足的"嗯～"
  static Uint8List _synthChew() {
    const rate = 44100;
    const ms = 820;
    final n = rate * ms ~/ 1000;
    final rnd = Random(9);
    final out = List<double>.filled(n, 0);

    // 咔嚓
    for (final startSec in const [0.03, 0.21, 0.38, 0.54]) {
      final start = (startSec * rate).round();
      final len = (rate * 0.085).round();
      for (var i = 0; i < len; i++) {
        final idx = start + i;
        if (idx >= n) break;
        final t = i / len;
        final env = pow(1 - t, 2.2).toDouble();
        final noise = rnd.nextDouble() * 2 - 1;
        final thud = sin(2 * pi * 95 * i / rate);
        out[idx] += (noise * 0.85 + thud * 0.30) * env * 0.55;
      }
    }
    // 满足的"嗯～"
    final start2 = (0.62 * rate).round();
    final tail = n - start2;
    for (var i = 0; i < tail; i++) {
      final t = i / rate;
      final env = exp(-t * 5.5) * (1 - i / tail);
      final f = 210 + 30 * sin(2 * pi * 5.5 * t);
      out[start2 + i] += sin(2 * pi * f * t) * 0.22 * env;
    }
    final peak = out.fold<double>(0, (a, v) => max(a, v.abs()));
    if (peak > 0.95) {
      for (var i = 0; i < n; i++) {
        out[i] *= 0.95 / peak;
      }
    }
    return _wav(out, rate);
  }

  /// 爆炸声：噪声 + 低频轰隆（160→60Hz），快速衰减
  static Uint8List _synthBoom() {
    const rate = 44100;
    const ms = 500;
    final n = rate * ms ~/ 1000;
    final rnd = Random(42);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final sec = i / rate;
      final decay = pow(1 - t, 2.4).toDouble();
      final noise = rnd.nextDouble() * 2 - 1;
      final freq = 160 - 100 * t;
      final low = sin(2 * pi * freq * sec);
      out[i] = ((noise * 0.9 + low * 0.85) * decay).clamp(-1.0, 1.0);
    }
    return _wav(out, rate);
  }

  /// 升空声：频率快速上升的 chirp + 轻噪声
  static Uint8List _synthWhoosh() {
    const rate = 44100;
    const ms = 300;
    final n = rate * ms ~/ 1000;
    final rnd = Random(7);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final sec = i / rate;
      final env = sin(pi * t);
      final freq = 300 + 1800 * t;
      final chirp = sin(2 * pi * freq * sec);
      final noise = (rnd.nextDouble() * 2 - 1) * 0.3;
      out[i] = ((chirp * 0.7 + noise) * env * 0.8).clamp(-1.0, 1.0);
    }
    return _wav(out, rate);
  }

  /// 贴纸"叮铃"：C6 → E6 → G6 三个音，快速衰减
  static Uint8List _synthChime() {
    const rate = 44100;
    const ms = 900;
    final n = rate * ms ~/ 1000;
    final out = List<double>.filled(n, 0);
    final notes = <List<double>>[
      [0.0, 1046.5],
      [0.12, 1318.5],
      [0.26, 1568.0],
    ];
    for (final note in notes) {
      final start = (note[0] * rate).round();
      final f = note[1];
      final len = rate ~/ 3;
      for (var i = 0; i < len; i++) {
        final idx = start + i;
        if (idx >= n) break;
        final t = i / rate;
        final env = exp(-t * 7.0);
        final s = sin(2 * pi * f * t) * 0.7 + sin(2 * pi * f * 2 * t) * 0.18;
        out[idx] += s * env * 0.6;
      }
    }
    // 防止削波
    final peak = out.fold<double>(0, (a, v) => max(a, v.abs()));
    if (peak > 1.0) {
      for (var i = 0; i < n; i++) {
        out[i] /= peak;
      }
    }
    return _wav(out, rate);
  }

  /// 16-bit 单声道 PCM WAV
  static Uint8List _wav(List<double> samples, int rate) {
    final b = BytesBuilder();
    void u16(int v) {
      b.addByte(v & 0xFF);
      b.addByte((v >> 8) & 0xFF);
    }
    void u32(int v) {
      b.addByte(v & 0xFF);
      b.addByte((v >> 8) & 0xFF);
      b.addByte((v >> 16) & 0xFF);
      b.addByte((v >> 24) & 0xFF);
    }
    b.add([0x52, 0x49, 0x46, 0x46]); // RIFF
    u32(36 + samples.length * 2);
    b.add([0x57, 0x41, 0x56, 0x45]); // WAVE
    b.add([0x66, 0x6D, 0x74, 0x20]); // fmt
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    b.add([0x64, 0x61, 0x74, 0x61]); // data
    u32(samples.length * 2);
    for (final s in samples) {
      final v = (s.clamp(-1.0, 1.0) * 32767).round();
      b.addByte(v & 0xFF);
      b.addByte((v >> 8) & 0xFF);
    }
    return b.toBytes();
  }
}
