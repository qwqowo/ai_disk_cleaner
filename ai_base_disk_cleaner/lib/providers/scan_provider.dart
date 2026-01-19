import 'package:flutter/foundation.dart';

import '../models/file_item.dart';
import '../services/scanner_service.dart';

/// 扫描状态枚举
enum ScanState {
  idle,      // 空闲
  scanning,  // 扫描中
  completed, // 完成
  cancelled, // 已取消
  error,     // 出错
}

/// 扫描状态管理 Provider
class ScanProvider extends ChangeNotifier {
  final ScannerService _scannerService = ScannerService();

  ScanState _state = ScanState.idle;
  ScanSummary? _summary;
  String? _errorMessage;
  String _currentPath = '';
  int _scannedCount = 0;
  String? _selectedPath;

  // Getters
  ScanState get state => _state;
  ScanSummary? get summary => _summary;
  String? get errorMessage => _errorMessage;
  String get currentPath => _currentPath;
  int get scannedCount => _scannedCount;
  String? get selectedPath => _selectedPath;
  bool get isScanning => _state == ScanState.scanning;

  /// 设置选中的目录路径
  void setSelectedPath(String? path) {
    _selectedPath = path;
    notifyListeners();
  }

  /// 开始扫描
  Future<void> startScan(String path) async {
    if (_state == ScanState.scanning) return;

    _state = ScanState.scanning;
    _summary = null;
    _errorMessage = null;
    _scannedCount = 0;
    _currentPath = path;
    _selectedPath = path;
    notifyListeners();

    try {
      final summary = await _scannerService.scanDirectory(
        path,
        onProgress: (count, currentPath) {
          _scannedCount = count;
          _currentPath = currentPath;
          notifyListeners();
        },
      );

      if (_scannerService.isCancelled) {
        _state = ScanState.cancelled;
      } else {
        _state = ScanState.completed;
        _summary = summary;
      }
    } catch (e) {
      _state = ScanState.error;
      _errorMessage = e.toString();
      debugPrint('Scan error: $e');
    }

    notifyListeners();
  }

  /// 取消扫描
  void cancelScan() {
    _scannerService.cancel();
    _state = ScanState.cancelled;
    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _scannerService.reset();
    _state = ScanState.idle;
    _summary = null;
    _errorMessage = null;
    _currentPath = '';
    _scannedCount = 0;
    notifyListeners();
  }
}
