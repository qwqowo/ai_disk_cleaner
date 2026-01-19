import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import '../models/operation_log.dart';
import '../utils/format_utils.dart';

/// 操作历史记录页面
class HistoryPage extends StatefulWidget {
  final List<OperationLog> logs;

  const HistoryPage({
    super.key,
    required this.logs,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _filterOperation = 'all';
  String _filterStatus = 'all';

  List<OperationLog> get _filteredLogs {
    return widget.logs.where((log) {
      if (_filterOperation != 'all' && log.operation != _filterOperation) {
        return false;
      }
      if (_filterStatus != 'all' && log.status.name != _filterStatus) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('操作历史'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 筛选菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onSelected: (value) {
              final parts = value.split(':');
              setState(() {
                if (parts[0] == 'op') {
                  _filterOperation = parts[1];
                } else if (parts[0] == 'st') {
                  _filterStatus = parts[1];
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('按操作类型', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildFilterItem('op:all', '全部', _filterOperation == 'all'),
              _buildFilterItem('op:delete', '删除', _filterOperation == 'delete'),
              _buildFilterItem('op:archive', '归档', _filterOperation == 'archive'),
              _buildFilterItem('op:compress', '压缩', _filterOperation == 'compress'),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('按状态', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildFilterItem('st:all', '全部', _filterStatus == 'all'),
              _buildFilterItem('st:success', '成功', _filterStatus == 'success'),
              _buildFilterItem('st:failed', '失败', _filterStatus == 'failed'),
            ],
          ),
        ],
      ),
      body: widget.logs.isEmpty
          ? _buildEmptyView()
          : _filteredLogs.isEmpty
              ? _buildNoResultsView()
              : _buildLogList(),
    );
  }

  PopupMenuItem<String> _buildFilterItem(String value, String label, bool isSelected) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check, size: 18, color: Colors.blue)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无操作记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '执行清理操作后，历史记录会显示在这里',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '没有匹配的记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _filterOperation = 'all';
                _filterStatus = 'all';
              });
            },
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    final logs = _filteredLogs;
    
    // 按日期分组
    final groupedLogs = <String, List<OperationLog>>{};
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    for (final log in logs) {
      final dateKey = dateFormat.format(log.executedAt);
      groupedLogs.putIfAbsent(dateKey, () => []).add(log);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedLogs.length,
      itemBuilder: (context, index) {
        final dateKey = groupedLogs.keys.elementAt(index);
        final dayLogs = groupedLogs[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _formatDateHeader(dateKey),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            // 该日期的日志
            ...dayLogs.map((log) => _buildLogItem(log)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _formatDateHeader(String dateKey) {
    final date = DateFormat('yyyy-MM-dd').parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) {
      return '今天';
    } else if (date == yesterday) {
      return '昨天';
    } else {
      return DateFormat('MM月dd日 EEEE', 'zh_CN').format(date);
    }
  }

  Widget _buildLogItem(OperationLog log) {
    final statusColor = _getStatusColor(log.status);
    final operationIcon = _getOperationIcon(log.operation);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(operationIcon, color: statusColor, size: 20),
        ),
        title: Text(
          path.basename(log.originalPath),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.originalPath,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTag(log.operationText, Colors.blue),
                const SizedBox(width: 8),
                _buildTag(log.statusText, statusColor),
                if (log.fileSize != null) ...[
                  const Spacer(),
                  Text(
                    FormatUtils.formatSize(log.fileSize!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Text(
          DateFormat('HH:mm:ss').format(log.executedAt),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        onTap: () => _showLogDetails(context, log),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(OperationStatus status) {
    switch (status) {
      case OperationStatus.pending:
        return Colors.grey;
      case OperationStatus.running:
        return Colors.blue;
      case OperationStatus.success:
        return Colors.green;
      case OperationStatus.failed:
        return Colors.red;
      case OperationStatus.reverted:
        return Colors.orange;
    }
  }

  IconData _getOperationIcon(String operation) {
    switch (operation) {
      case 'delete':
        return Icons.delete;
      case 'archive':
        return Icons.archive;
      case 'compress':
        return Icons.compress;
      default:
        return Icons.help_outline;
    }
  }

  void _showLogDetails(BuildContext context, OperationLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getOperationIcon(log.operation)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.operationText,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('状态', log.statusText, _getStatusColor(log.status)),
              _buildDetailRow('原路径', log.originalPath),
              if (log.targetPath != null)
                _buildDetailRow('目标路径', log.targetPath!),
              if (log.fileSize != null)
                _buildDetailRow('大小', FormatUtils.formatSize(log.fileSize!)),
              _buildDetailRow('类型', log.isDirectory ? '目录' : '文件'),
              _buildDetailRow('可恢复', log.isReversible ? '是' : '否'),
              _buildDetailRow(
                '执行时间',
                DateFormat('yyyy-MM-dd HH:mm:ss').format(log.executedAt),
              ),
              if (log.errorMessage != null) ...[
                const Divider(),
                Text(
                  '错误信息:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
