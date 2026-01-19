import 'package:flutter/foundation.dart';

import '../models/file_item.dart';
import '../models/cleaning_suggestion.dart';
import '../services/ai_config.dart';
import '../services/ai_analysis_service.dart';

/// AI 分析状态管理 Provider
class AIProvider extends ChangeNotifier {
  final AIConfig config = AIConfig();
  final CleaningPrinciples principles = CleaningPrinciples();
  
  late final AIAnalysisService _analysisService;

  AnalysisState _state = AnalysisState.idle;
  AnalysisResult? _result;
  String? _errorMessage;
  
  // 用户选中的建议（用于批量执行）
  final Set<int> _selectedSuggestions = {};

  AIProvider() {
    _analysisService = AIAnalysisService(
      config: config,
      principles: principles,
    );
  }

  // Getters
  AnalysisState get state => _state;
  AnalysisResult? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get isAnalyzing => _state == AnalysisState.analyzing;
  bool get isConfigured => config.isConfigured;
  Set<int> get selectedSuggestions => _selectedSuggestions;

  /// 初始化（加载配置）
  Future<void> initialize() async {
    await config.load();
    await principles.load();
    notifyListeners();
  }

  /// 更新 AI 配置
  Future<void> updateConfig({
    AIProvider? aiProvider,
    String? deepseekApiKey,
    String? openaiApiKey,
    String? deepseekBaseUrl,
    String? openaiBaseUrl,
    String? model,
  }) async {
    await config.update(
      deepseekApiKey: deepseekApiKey,
      openaiApiKey: openaiApiKey,
      deepseekBaseUrl: deepseekBaseUrl,
      openaiBaseUrl: openaiBaseUrl,
      model: model,
    );
    notifyListeners();
  }

  /// 开始 AI 分析
  Future<void> analyze(ScanSummary summary) async {
    if (_state == AnalysisState.analyzing) return;

    _state = AnalysisState.analyzing;
    _result = null;
    _errorMessage = null;
    _selectedSuggestions.clear();
    notifyListeners();

    try {
      final result = await _analysisService.analyze(summary);
      _state = AnalysisState.completed;
      _result = result;
    } catch (e) {
      _state = AnalysisState.error;
      _errorMessage = e.toString();
      debugPrint('AI analysis error: $e');
    }

    notifyListeners();
  }

  /// 测试 API 连接
  Future<bool> testConnection() async {
    return await _analysisService.testConnection();
  }

  /// 切换建议选中状态
  void toggleSuggestion(int index) {
    if (_selectedSuggestions.contains(index)) {
      _selectedSuggestions.remove(index);
    } else {
      _selectedSuggestions.add(index);
    }
    notifyListeners();
  }

  /// 全选/取消全选
  void selectAll(bool selected) {
    if (selected && _result != null) {
      _selectedSuggestions.addAll(
        List.generate(_result!.suggestions.length, (i) => i),
      );
    } else {
      _selectedSuggestions.clear();
    }
    notifyListeners();
  }

  /// 选择所有低风险建议
  void selectLowRisk() {
    if (_result == null) return;
    _selectedSuggestions.clear();
    for (var i = 0; i < _result!.suggestions.length; i++) {
      if (_result!.suggestions[i].riskLevel == 'low') {
        _selectedSuggestions.add(i);
      }
    }
    notifyListeners();
  }

  /// 获取选中的建议列表
  List<CleaningSuggestion> getSelectedSuggestionsList() {
    if (_result == null) return [];
    return _selectedSuggestions
        .where((i) => i < _result!.suggestions.length)
        .map((i) => _result!.suggestions[i])
        .toList();
  }

  /// 清除选择（但保留分析结果）
  void clearSelection() {
    _selectedSuggestions.clear();
    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _state = AnalysisState.idle;
    _result = null;
    _errorMessage = null;
    _selectedSuggestions.clear();
    notifyListeners();
  }
}
