import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/cleaning_suggestion.dart';
import '../models/operation_log.dart';

/// 执行进度对话框
class ExecutionProgressDialog extends StatefulWidget {
  final List<CleaningSuggestion> suggestions;
  final Future<ExecutionResult> Function(
    void Function(int current, int total, String message) onProgress,
  ) onExecute;

  const ExecutionProgressDialog({
    super.key,
    required this.suggestions,
    required this.onExecute,
  });

  /// 显示执行对话框
  static Future<ExecutionResult?> show(
    BuildContext context, {
    required List<CleaningSuggestion> suggestions,
    required Future<ExecutionResult> Function(
      void Function(int current, int total, String message) onProgress,
    ) onExecute,
  }) {
    return showDialog<ExecutionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExecutionProgressDialog(
        suggestions: suggestions,
        onExecute: onExecute,
      ),
    );
  }

  @override
  State<ExecutionProgressDialog> createState() => _ExecutionProgressDialogState();
}

class _ExecutionProgressDialogState extends State<ExecutionProgressDialog> {
  double _progress = 0;
  String _currentMessage = '准备执行...';
  int _current = 0;
  int _total = 0;
  bool _isExecuting = true;
  ExecutionResult? _result;

  @override
  void initState() {
    super.initState();
    _total = widget.suggestions.length;
    // 延迟到下一帧执行，避免在 build 期间调用 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExecution();
    });
  }

  Future<void> _startExecution() async {
    try {
      final result = await widget.onExecute((current, total, message) {
        if (mounted) {
          setState(() {
            _current = current;
            _total = total;
            _progress = current / total;
            _currentMessage = message;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isExecuting = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _currentMessage = '执行出错: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isExecuting
                ? Icons.sync
                : (_result?.allSuccess ?? false)
                    ? Icons.check_circle
                    : Icons.warning,
            color: _isExecuting
                ? Colors.blue
                : (_result?.allSuccess ?? false)
                    ? Colors.green
                    : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(_isExecuting ? '执行中...' : '执行完成'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExecuting) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 16),
              Text('进度: $_current / $_total'),
              const SizedBox(height: 8),
              Text(
                _currentMessage,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (_result != null) ...[
              _buildResultSummary(_result!),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isExecuting)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('确定'),
          ),
      ],
    );
  }

  Widget _buildResultSummary(ExecutionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: result.allSuccess
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                '成功',
                result.successCount.toString(),
                Colors.green,
              ),
              _buildStatItem(
                '失败',
                result.failedCount.toString(),
                Colors.red,
              ),
              _buildStatItem(
                '释放空间',
                _formatSize(result.totalSizeFreed),
                Colors.blue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 耗时
        Text(
          '耗时: ${result.duration.inSeconds}.${result.duration.inMilliseconds % 1000}秒',
          style: Theme.of(context).textTheme.bodySmall,
        ),

        // 失败列表
        if (result.hasFailures) ...[
          const SizedBox(height: 16),
          Text(
            '失败项目:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.red,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: result.logs.where((l) => l.status == OperationStatus.failed).length,
              itemBuilder: (context, index) {
                final failedLog = result.logs
                    .where((l) => l.status == OperationStatus.failed)
                    .elementAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          path.basename(failedLog.originalPath),
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 执行确认对话框
class ExecutionConfirmDialog extends StatelessWidget {
  final List<CleaningSuggestion> suggestions;
  final int totalSize;

  const ExecutionConfirmDialog({
    super.key,
    required this.suggestions,
    required this.totalSize,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<CleaningSuggestion> suggestions,
  }) {
    final totalSize = suggestions.fold<int>(
      0,
      (sum, s) => sum + (s.estimatedSize ?? 0),
    );

    return showDialog<bool>(
      context: context,
      builder: (context) => ExecutionConfirmDialog(
        suggestions: suggestions,
        totalSize: totalSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deleteCount = suggestions.where((s) => s.operation == 'delete').length;
    final archiveCount = suggestions.where((s) => s.operation == 'archive').length;
    final compressCount = suggestions.where((s) => s.operation == 'compress').length;

    final highRiskCount = suggestions.where((s) => s.riskLevel == 'high').length;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('确认执行'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即将执行以下操作：'),
            const SizedBox(height: 16),
            _buildOperationRow(Icons.delete, '删除', deleteCount, Colors.red),
            _buildOperationRow(Icons.archive, '归档', archiveCount, Colors.blue),
            _buildOperationRow(Icons.compress, '压缩', compressCount, Colors.green),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('总计：'),
                Text(
                  '${suggestions.length} 个项目',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('预计释放：'),
                Text(
                  _formatSize(totalSize),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (highRiskCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '包含 $highRiskCount 个高风险操作，请确认后再执行',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '删除的文件将移动到回收站，可在回收站中恢复。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: highRiskCount > 0 ? Colors.red : null,
          ),
          child: const Text('确认执行'),
        ),
      ],
    );
  }

  Widget _buildOperationRow(IconData icon, String label, int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            '$count 个',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
