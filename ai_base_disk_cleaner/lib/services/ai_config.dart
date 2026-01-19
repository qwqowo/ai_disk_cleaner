import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 服务提供商枚举
enum AIProvider {
  deepseek,
  openai,
}

/// AI 配置管理
class AIConfig {
  static const String _keyProvider = 'ai_provider';
  static const String _keyDeepseekApiKey = 'deepseek_api_key';
  static const String _keyOpenaiApiKey = 'openai_api_key';
  static const String _keyDeepseekBaseUrl = 'deepseek_base_url';
  static const String _keyOpenaiBaseUrl = 'openai_base_url';
  static const String _keyModel = 'ai_model';

  // 默认值
  static const String defaultDeepseekBaseUrl = 'https://api.deepseek.com';
  static const String defaultOpenaiBaseUrl = 'https://api.openai.com';
  static const String defaultDeepseekModel = 'deepseek-chat';
  static const String defaultOpenaiModel = 'gpt-4o';

  AIProvider _provider = AIProvider.deepseek;
  String _deepseekApiKey = '';
  String _openaiApiKey = '';
  String _deepseekBaseUrl = defaultDeepseekBaseUrl;
  String _openaiBaseUrl = defaultOpenaiBaseUrl;
  String _model = defaultDeepseekModel;

  // Getters
  AIProvider get provider => _provider;
  String get apiKey => _provider == AIProvider.deepseek ? _deepseekApiKey : _openaiApiKey;
  String get baseUrl => _provider == AIProvider.deepseek ? _deepseekBaseUrl : _openaiBaseUrl;
  String get model => _model;
  bool get isConfigured => apiKey.isNotEmpty;

  String get deepseekApiKey => _deepseekApiKey;
  String get openaiApiKey => _openaiApiKey;
  String get deepseekBaseUrl => _deepseekBaseUrl;
  String get openaiBaseUrl => _openaiBaseUrl;

  /// 从本地存储加载配置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final providerIndex = prefs.getInt(_keyProvider) ?? 0;
      _provider = AIProvider.values[providerIndex.clamp(0, AIProvider.values.length - 1)];
      
      _deepseekApiKey = prefs.getString(_keyDeepseekApiKey) ?? '';
      _openaiApiKey = prefs.getString(_keyOpenaiApiKey) ?? '';
      _deepseekBaseUrl = prefs.getString(_keyDeepseekBaseUrl) ?? defaultDeepseekBaseUrl;
      _openaiBaseUrl = prefs.getString(_keyOpenaiBaseUrl) ?? defaultOpenaiBaseUrl;
      _model = prefs.getString(_keyModel) ?? defaultDeepseekModel;
    } catch (e) {
      debugPrint('Failed to load AI config: $e');
    }
  }

  /// 保存配置到本地存储
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_keyProvider, _provider.index);
      await prefs.setString(_keyDeepseekApiKey, _deepseekApiKey);
      await prefs.setString(_keyOpenaiApiKey, _openaiApiKey);
      await prefs.setString(_keyDeepseekBaseUrl, _deepseekBaseUrl);
      await prefs.setString(_keyOpenaiBaseUrl, _openaiBaseUrl);
      await prefs.setString(_keyModel, _model);
    } catch (e) {
      debugPrint('Failed to save AI config: $e');
    }
  }

  /// 更新配置
  Future<void> update({
    AIProvider? provider,
    String? deepseekApiKey,
    String? openaiApiKey,
    String? deepseekBaseUrl,
    String? openaiBaseUrl,
    String? model,
  }) async {
    if (provider != null) _provider = provider;
    if (deepseekApiKey != null) _deepseekApiKey = deepseekApiKey;
    if (openaiApiKey != null) _openaiApiKey = openaiApiKey;
    if (deepseekBaseUrl != null) _deepseekBaseUrl = deepseekBaseUrl;
    if (openaiBaseUrl != null) _openaiBaseUrl = openaiBaseUrl;
    if (model != null) _model = model;
    
    await save();
  }

  /// 获取完整的 API 端点
  String get chatEndpoint {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base/v1/chat/completions';
  }
}

/// 用户清理原则
class CleaningPrinciples {
  static const String _keyPrinciples = 'cleaning_principles';

  List<String> _principles = [
    '如果是 node_modules 文件夹，且超过 3 个月未修改，建议删除。',
    '如果是 .tmp、.log、.cache 文件，直接建议删除。',
    '如果是 __pycache__、.pyc 文件，建议删除。',
    '如果是图片、文档、视频等用户文件，绝对不要建议删除。',
    '如果是系统文件夹（Windows、Program Files），绝对不要建议删除。',
    '对于 .git 文件夹，除非用户明确要求，否则不建议删除。',
  ];

  List<String> get principles => List.unmodifiable(_principles);

  /// 加载原则
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_keyPrinciples);
      if (saved != null && saved.isNotEmpty) {
        _principles = saved;
      }
    } catch (e) {
      debugPrint('Failed to load principles: $e');
    }
  }

  /// 保存原则
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyPrinciples, _principles);
    } catch (e) {
      debugPrint('Failed to save principles: $e');
    }
  }

  /// 更新原则
  Future<void> update(List<String> principles) async {
    _principles = principles;
    await save();
  }

  /// 添加原则
  Future<void> add(String principle) async {
    _principles.add(principle);
    await save();
  }

  /// 移除原则
  Future<void> remove(int index) async {
    if (index >= 0 && index < _principles.length) {
      _principles.removeAt(index);
      await save();
    }
  }

  /// 格式化为 Prompt 文本
  String toPromptText() {
    return _principles.asMap().entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
  }
}
