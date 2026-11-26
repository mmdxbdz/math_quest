import 'package:flutter/material.dart';
import 'app_info.dart';
import 'store.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressStore().load();
  // 错误兜底：任何渲染异常显示提示而不是白屏
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFFFFF8E7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😅 这里出错了',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('请把下面的文字告诉家长，重启 App 就好了',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Text(details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.red)),
              ],
            ),
          ),
        ),
      );
  runApp(const MathQuestApp());
}

class MathQuestApp extends StatelessWidget {
  const MathQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF9800)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
