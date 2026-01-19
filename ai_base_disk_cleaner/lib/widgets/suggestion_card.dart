import 'package:flutter/material.dart';

import '../models/cleaning_suggestion.dart';
import '../utils/format_utils.dart';

/// AI 清理建议卡片
class SuggestionCard extends StatelessWidget {
  final CleaningSuggestion suggestion;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback? onExecute;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getRiskColor(suggestion.riskLevel).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 选择框
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              
              // 风险等级指示器
              Container(
                width: 8,
                height: 50,
                decoration: BoxDecoration(
                  color: _getRiskColor(suggestion.riskLevel),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              
              // 操作图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getOperationColor(suggestion.operation).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getOperationIcon(suggestion.operation),
                  color: _getOperationColor(suggestion.operation),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // 内容区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 路径
                    Text(
                      suggestion.targetPath,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // 理由
                    Text(
                      suggestion.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // 标签行
                    Row(
                      children: [
                        // 操作类型
                        _buildTag(
                          suggestion.operationText,
                          _getOperationColor(suggestion.operation),
                        ),
                        const SizedBox(width: 6),
                        
                        // 风险等级
                        _buildTag(
                          suggestion.riskLevelText,
                          _getRiskColor(suggestion.riskLevel),
                        ),
                        
                        // 分类
                        if (suggestion.category != null) ...[
                          const SizedBox(width: 6),
                          _buildTag(
                            _getCategoryText(suggestion.category!),
                            Colors.grey,
                          ),
                        ],
                        
                        const Spacer(),
                        
                        // 大小
                        if (suggestion.estimatedSize != null)
                          Text(
                            FormatUtils.formatSize(suggestion.estimatedSize!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 单独执行按钮
              if (onExecute != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: suggestion.isHighRisk
                      ? () => _showHighRiskConfirm(context)
                      : onExecute,
                  icon: const Icon(Icons.play_arrow),
                  tooltip: '立即执行',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getOperationColor(String operation) {
    switch (operation) {
      case 'delete':
        return Colors.red;
      case 'archive':
        return Colors.blue;
      case 'compress':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getOperationIcon(String operation) {
    switch (operation) {
      case 'delete':
        return Icons.delete_outline;
      case 'archive':
        return Icons.archive_outlined;
      case 'compress':
        return Icons.compress;
      default:
        return Icons.help_outline;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'cache':
        return '缓存';
      case 'temp':
        return '临时文件';
      case 'log':
        return '日志';
      case 'build':
        return '构建产物';
      default:
        return category;
    }
  }

  void _showHighRiskConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('高风险操作'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此操作被标记为高风险，可能会影响系统或应用程序的正常运行。'),
            const SizedBox(height: 12),
            Text(
              '目标: ${suggestion.targetPath}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('原因: ${suggestion.reason}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onExecute?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认执行'),
          ),
        ],
      ),
    );
  }
}

/// AI 分析结果面板
class AnalysisResultPanel extends StatelessWidget {
  final AnalysisResult result;
  final Set<int> selectedIndices;
  final Function(int) onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectLowRisk;
  final VoidCallback onExecuteSelected;

  const AnalysisResultPanel({
    super.key,
    required this.result,
    required this.selectedIndices,
    required this.onToggle,
    required this.onSelectAll,
    required this.onSelectLowRisk,
    required this.onExecuteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部统计栏
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'AI 建议 (${result.suggestions.length} 项)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onSelectLowRisk,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('选择低风险'),
              ),
              TextButton.icon(
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(
                  selectedIndices.length == result.suggestions.length
                      ? '取消全选'
                      : '全选',
                ),
              ),
            ],
          ),
        ),
        
        // 摘要信息
        if (result.summary != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Text(
              result.summary!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        
        // 建议列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: result.suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = result.suggestions[index];
              return SuggestionCard(
                suggestion: suggestion,
                index: index,
                isSelected: selectedIndices.contains(index),
                onToggle: () => onToggle(index),
              );
            },
          ),
        ),
        
        // 底部操作栏
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                '已选择 ${selectedIndices.length} 项',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (result.estimatedTotalSavings > 0) ...[
                const SizedBox(width: 16),
                Text(
                  '预计可释放: ${FormatUtils.formatSize(result.estimatedTotalSavings)}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                onPressed: selectedIndices.isEmpty ? null : onExecuteSelected,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('执行选中项'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
