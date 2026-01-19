/// 清理建议模型
class CleaningSuggestion {
  final String targetPath;
  final String operation; // 'delete', 'archive', 'compress'
  final String reason;
  final String riskLevel; // 'low', 'medium', 'high'
  final int? estimatedSize;
  final String? category; // 'cache', 'temp', 'log', 'build', 'other'

  CleaningSuggestion({
    required this.targetPath,
    required this.operation,
    required this.reason,
    required this.riskLevel,
    this.estimatedSize,
    this.category,
  });

  /// 从 AI 返回的 JSON 解析
  factory CleaningSuggestion.fromJson(Map<String, dynamic> json) {
    return CleaningSuggestion(
      targetPath: json['path'] ?? json['targetPath'] ?? '',
      operation: json['action'] ?? json['operation'] ?? 'delete',
      reason: json['reason'] ?? '',
      riskLevel: json['risk'] ?? json['riskLevel'] ?? 'medium',
      estimatedSize: json['size'] ?? json['estimatedSize'],
      category: json['category'],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'path': targetPath,
      'action': operation,
      'reason': reason,
      'risk': riskLevel,
      'size': estimatedSize,
      'category': category,
    };
  }

  /// 获取操作的中文描述
  String get operationText {
    switch (operation) {
      case 'delete':
        return '删除';
      case 'archive':
        return '归档';
      case 'compress':
        return '压缩';
      default:
        return operation;
    }
  }

  /// 获取风险等级的中文描述
  String get riskLevelText {
    switch (riskLevel) {
      case 'low':
        return '低风险';
      case 'medium':
        return '中风险';
      case 'high':
        return '高风险';
      default:
        return riskLevel;
    }
  }

  /// 是否为高风险操作
  bool get isHighRisk => riskLevel == 'high';

  @override
  String toString() {
    return 'CleaningSuggestion(path: $targetPath, op: $operation, risk: $riskLevel)';
  }
}

/// AI 分析结果
class AnalysisResult {
  final List<CleaningSuggestion> suggestions;
  final String? summary;
  final int? totalSavings;
  final String? rawResponse;
  final DateTime analyzedAt;

  AnalysisResult({
    required this.suggestions,
    this.summary,
    this.totalSavings,
    this.rawResponse,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  /// 从 AI 返回的 JSON 解析
  factory AnalysisResult.fromJson(Map<String, dynamic> json, {String? rawResponse}) {
    final suggestionsJson = json['suggestions'] ?? json['recommendations'] ?? [];
    final suggestions = (suggestionsJson as List)
        .map((s) => CleaningSuggestion.fromJson(s as Map<String, dynamic>))
        .toList();

    return AnalysisResult(
      suggestions: suggestions,
      summary: json['summary'] ?? json['analysis'],
      totalSavings: json['totalSavings'] ?? json['estimatedSavings'],
      rawResponse: rawResponse,
    );
  }

  /// 获取低风险建议
  List<CleaningSuggestion> get lowRiskSuggestions =>
      suggestions.where((s) => s.riskLevel == 'low').toList();

  /// 获取中风险建议
  List<CleaningSuggestion> get mediumRiskSuggestions =>
      suggestions.where((s) => s.riskLevel == 'medium').toList();

  /// 获取高风险建议
  List<CleaningSuggestion> get highRiskSuggestions =>
      suggestions.where((s) => s.riskLevel == 'high').toList();

  /// 计算预估可释放空间
  int get estimatedTotalSavings {
    if (totalSavings != null) return totalSavings!;
    return suggestions
        .where((s) => s.estimatedSize != null)
        .fold(0, (sum, s) => sum + s.estimatedSize!);
  }
}

/// AI 分析状态
enum AnalysisState {
  idle,      // 空闲
  analyzing, // 分析中
  completed, // 完成
  error,     // 出错
}
