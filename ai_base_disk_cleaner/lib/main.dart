import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/scan_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/operation_provider.dart';
import 'services/archive_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 AI 配置
  final aiProvider = AIProvider();
  await aiProvider.initialize();
  
  // 初始化操作管理
  final operationProvider = OperationProvider();
  await operationProvider.initialize();
  
  // 初始化归档配置
  final archiveConfig = ArchiveConfig();
  await archiveConfig.load();
  
  runApp(MyApp(
    aiProvider: aiProvider, 
    operationProvider: operationProvider,
    archiveConfig: archiveConfig,
  ));
}

class MyApp extends StatelessWidget {
  final AIProvider aiProvider;
  final OperationProvider operationProvider;
  final ArchiveConfig archiveConfig;
  
  const MyApp({
    super.key,
    required this.aiProvider,
    required this.operationProvider,
    required this.archiveConfig,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider.value(value: aiProvider),
        ChangeNotifierProvider.value(value: operationProvider),
        ChangeNotifierProvider.value(value: archiveConfig),
      ],
      child: MaterialApp(
        title: 'AI 磁盘清理器',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.light,
        home: const HomePage(),
      ),
    );
  }
}

