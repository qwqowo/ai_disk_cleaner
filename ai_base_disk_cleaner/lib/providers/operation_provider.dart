import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/operation_log.dart';
import '../models/cleaning_suggestion.dart';
import '../services/file_operator.dart';

/// 操作管理 Provider
/// 管理文件操作执行和历史记录
class OperationProvider extends ChangeNotifier {
  static const String _historyKey = 'operation_history';
  static const int _maxHistorySize = 500; // 最多保存500条记录

  final FileOperator _fileOperator = FileOperator();
  final List<OperationLog> _history = [];
  
  bool _isExecuting = false;
  String _currentOperation = '';
  int _currentProgress = 0;
  int _totalOperations = 0;

  // Getters
  List<OperationLog> get history => List.unmodifiable(_history);
  bool get isExecuting => _isExecuting;
  String get currentOperation => _currentOperation;
  int get currentProgress => _currentProgress;
  int get totalOperations => _totalOperations;
  double get progress => _totalOperations > 0 ? _currentProgress / _totalOperations : 0;
  FileOperator get fileOperator => _fileOperator;

  /// 初始化（加载历史记录）
  Future<void> initialize() async {
    await _loadHistory();
  }

  /// 执行选中的建议
  Future<ExecutionResult> executeSuggestions(
    List<CleaningSuggestion> suggestions, {
    String? archiveDirectory,
    void Function(int current, int total, String message)? onProgress,
  }) async {
    _isExecuting = true;
    _totalOperations = suggestions.length;
    _currentProgress = 0;
    notifyListeners();

    try {
      final result = await _fileOperator.executeSuggestions(
        suggestions,
        archiveDirectory: archiveDirectory,
        onProgress: (current, total, message) {
          _currentProgress = current;
          _currentOperation = message;
          notifyListeners();
          onProgress?.call(current, total, message);
        },
      );

      // 将日志添加到历史记录
      _history.insertAll(0, result.logs);
      
      // 限制历史记录大小
      while (_history.length > _maxHistorySize) {
        _history.removeLast();
      }
      
      // 保存历史记录
      await _saveHistory();

      return result;
    } finally {
      _isExecuting = false;
      _currentOperation = '';
      _currentProgress = 0;
      _totalOperations = 0;
      notifyListeners();
    }
  }

  /// 删除单个文件到回收站
  Future<OperationLog> deleteToRecycleBin(String filePath) async {
    final log = await _fileOperator.deleteToRecycleBin(filePath);
    _history.insert(0, log);
    await _saveHistory();
    notifyListeners();
    return log;
  }

  /// 归档文件
  Future<OperationLog> archiveTo(String sourcePath, String destinationDir) async {
    final log = await _fileOperator.archiveTo(sourcePath, destinationDir);
    _history.insert(0, log);
    await _saveHistory();
    notifyListeners();
    return log;
  }

  /// 压缩文件
  Future<OperationLog> compressToZip(String sourcePath, {bool deleteOriginal = false}) async {
    final log = await _fileOperator.compressToZip(sourcePath, deleteOriginal: deleteOriginal);
    _history.insert(0, log);
    await _saveHistory();
    notifyListeners();
    return log;
  }

  /// 获取统计信息
  Map<String, int> getStatistics() {
    int successCount = 0;
    int failedCount = 0;
    int totalSizeFreed = 0;
    
    for (final log in _history) {
      if (log.status == OperationStatus.success) {
        successCount++;
        totalSizeFreed += log.fileSize ?? 0;
      } else if (log.status == OperationStatus.failed) {
        failedCount++;
      }
    }
    
    return {
      'totalOperations': _history.length,
      'successCount': successCount,
      'failedCount': failedCount,
      'totalSizeFreed': totalSizeFreed,
    };
  }

  /// 清空历史记录
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  /// 加载历史记录
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _history.clear();
        _history.addAll(
          jsonList.map((json) => OperationLog.fromJson(json as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('Failed to load operation history: $e');
    }
    notifyListeners();
  }

  /// 保存历史记录
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((log) => log.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Failed to save operation history: $e');
    }
  }
}
