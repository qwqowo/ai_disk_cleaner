import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/file_item.dart';
import '../models/operation_log.dart';
import '../providers/ai_provider.dart' as provider;
import '../providers/operation_provider.dart';
import '../services/ai_analysis_service.dart';
import '../services/archive_config.dart';
import '../utils/format_utils.dart';

/// 文件树列表视图
class FileTreeView extends StatelessWidget {
  final List<FileItem> items;
  final int totalSize;

  const FileTreeView({
    super.key,
    required this.items,
    required this.totalSize,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('没有找到文件'),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _FileItemTile(
          item: item,
          index: index + 1,
          totalSize: totalSize,
        );
      },
    );
  }
}

class _FileItemTile extends StatelessWidget {
  final FileItem item;
  final int index;
  final int totalSize;

  const _FileItemTile({
    required this.item,
    required this.index,
    required this.totalSize,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = totalSize > 0 ? item.size / totalSize : 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 排名
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getRankColor(index),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 图标
              Icon(
                item.isDirectory ? Icons.folder : _getFileIcon(item.extension),
                color: item.isDirectory ? Colors.amber : Colors.blue.shade400,
                size: 28,
              ),
              const SizedBox(width: 12),
              
              // 名称和路径
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.path,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 占比进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          _getProgressColor(percentage),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // 大小信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatSize(item.size),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FormatUtils.formatPercentage(item.size, totalSize),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (item.isDirectory) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${FormatUtils.formatNumber(item.fileCount)} 文件',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
              
              // 操作按钮
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (context) {
                  final isLargeFolder = item.isDirectory && item.size > 10 * 1024 * 1024 * 1024; // > 10GB
                  final archiveConfig = context.read<ArchiveConfig>();
                  final isResourceFile = !item.isDirectory && archiveConfig.isResourceFile(item.path);
                  
                  return [
                    const PopupMenuItem(
                      value: 'copy',
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('复制路径'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'open',
                      child: ListTile(
                        leading: Icon(Icons.folder_open),
                        title: Text('打开位置'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuDivider(),
                    // 资源文件显示归档选项
                    if (isResourceFile && archiveConfig.isConfigured)
                      const PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.drive_file_move, color: Colors.green),
                          title: Text('转移归档'),
                          subtitle: Text('移动到归档目录'),
                          dense: true,
                        ),
                      ),
                    // 资源文件但未配置归档目录
                    if (isResourceFile && !archiveConfig.isConfigured)
                      const PopupMenuItem(
                        value: 'archive_setup',
                        child: ListTile(
                          leading: Icon(Icons.drive_file_move, color: Colors.grey),
                          title: Text('转移归档'),
                          subtitle: Text('请先在设置中配置归档目录'),
                          dense: true,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'ai_analyze',
                      child: ListTile(
                        leading: Icon(Icons.psychology, color: Colors.blue),
                        title: Text('AI 分析'),
                        dense: true,
                      ),
                    ),
                    // 大文件夹显示智能拆分选项
                    if (isLargeFolder)
                      const PopupMenuItem(
                        value: 'ai_split',
                        child: ListTile(
                          leading: Icon(Icons.account_tree, color: Colors.purple),
                          title: Text('AI 智能拆分'),
                          subtitle: Text('识别内部内容分组'),
                          dense: true,
                        ),
                      ),
                  ];
                },
                onSelected: (value) => _handleAction(context, value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.red;
    if (rank == 2) return Colors.orange;
    if (rank == 3) return Colors.amber.shade700;
    if (rank <= 10) return Colors.blue;
    return Colors.grey;
  }

  Color _getProgressColor(double percentage) {
    if (percentage > 0.5) return Colors.red;
    if (percentage > 0.2) return Colors.orange;
    if (percentage > 0.1) return Colors.amber;
    return Colors.blue;
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
        return Icons.movie;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.music_note;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.archive;
      case 'exe':
      case 'msi':
        return Icons.apps;
      case 'log':
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              item.isDirectory ? Icons.folder : Icons.insert_drive_file,
              color: item.isDirectory ? Colors.amber : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('路径', item.path),
            _buildDetailRow('大小', FormatUtils.formatSize(item.size)),
            _buildDetailRow('类型', item.isDirectory ? '文件夹' : '文件'),
            if (!item.isDirectory)
              _buildDetailRow('扩展名', item.extension.isEmpty ? '无' : '.${item.extension}'),
            if (item.isDirectory) ...[
              _buildDetailRow('文件数', FormatUtils.formatNumber(item.fileCount)),
              _buildDetailRow('文件夹数', FormatUtils.formatNumber(item.folderCount)),
            ],
            if (item.modifiedTime != null)
              _buildDetailRow('修改时间', FormatUtils.formatDateTime(item.modifiedTime)),
          ],
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

  Widget _buildDetailRow(String label, String value) {
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
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'copy':
        Clipboard.setData(ClipboardData(text: item.path));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('路径已复制到剪贴板'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'open':
        _openFileLocation(context);
        break;
      case 'ai_analyze':
        _showAIAnalysis(context);
        break;
      case 'ai_split':
        _showAISplit(context);
        break;
      case 'archive':
        _archiveFile(context);
        break;
      case 'archive_setup':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先在设置中配置归档目录'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
    }
  }

  /// 归档文件到配置的目录
  Future<void> _archiveFile(BuildContext context) async {
    final archiveConfig = context.read<ArchiveConfig>();
    final operationProvider = context.read<OperationProvider>();
    
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认归档'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要将以下文件转移到归档目录吗？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '大小: ${FormatUtils.formatSize(item.size)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.folder, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '目标: ${archiveConfig.archiveBasePath}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.drive_file_move),
            label: const Text('确认归档'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 执行归档
    try {
      final result = await operationProvider.fileOperator.smartArchive(
        item.path,
        archiveConfig,
      );

      if (context.mounted) {
        if (result.status == OperationStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已归档到: ${result.targetPath}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('归档失败: ${result.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('归档出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 打开文件所在位置
  Future<void> _openFileLocation(BuildContext context) async {
    try {
      if (Platform.isWindows) {
        // Windows: 使用 explorer /select 选中文件
        if (item.isDirectory) {
          await Process.run('explorer', [item.path]);
        } else {
          await Process.run('explorer', ['/select,', item.path]);
        }
      } else if (Platform.isMacOS) {
        // macOS: 使用 open -R 在 Finder 中显示
        if (item.isDirectory) {
          await Process.run('open', [item.path]);
        } else {
          await Process.run('open', ['-R', item.path]);
        }
      } else if (Platform.isLinux) {
        // Linux: 使用 xdg-open 打开父目录
        final parentDir = item.isDirectory ? item.path : File(item.path).parent.path;
        await Process.run('xdg-open', [parentDir]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开文件位置: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示 AI 分析结果
  void _showAIAnalysis(BuildContext context) {
    final aiProvider = context.read<provider.AIProvider>();
    
    if (!aiProvider.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在设置中配置 AI API'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AIAnalysisDialog(item: item, aiProvider: aiProvider),
    );
  }

  /// 显示 AI 智能拆分
  void _showAISplit(BuildContext context) {
    final aiProvider = context.read<provider.AIProvider>();
    
    if (!aiProvider.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先在设置中配置 AI API'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AISplitDialog(item: item, aiProvider: aiProvider),
    );
  }
}

/// AI 分析对话框
class _AIAnalysisDialog extends StatefulWidget {
  final FileItem item;
  final provider.AIProvider aiProvider;

  const _AIAnalysisDialog({
    required this.item,
    required this.aiProvider,
  });

  @override
  State<_AIAnalysisDialog> createState() => _AIAnalysisDialogState();
}

class _AIAnalysisDialogState extends State<_AIAnalysisDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _analysis;

  @override
  void initState() {
    super.initState();
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    try {
      final service = AIAnalysisService(
        config: widget.aiProvider.config,
        principles: widget.aiProvider.principles,
      );

      final result = await service.analyzeItem(widget.item);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _analysis = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI 分析: ${widget.item.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _buildContent(),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _performAnalysis();
            },
            child: const Text('重试'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI 正在分析...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                '分析失败',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_analysis == null) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('无分析结果')),
      );
    }

    final description = _analysis!['description'] as String? ?? '无描述';
    final canDelete = _analysis!['canDelete'] as bool? ?? false;
    final riskLevel = _analysis!['riskLevel'] as String? ?? 'medium';
    final reason = _analysis!['reason'] as String? ?? '';
    final suggestion = _analysis!['suggestion'] as String? ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息
          _buildInfoCard(
            icon: widget.item.isDirectory ? Icons.folder : Icons.insert_drive_file,
            iconColor: widget.item.isDirectory ? Colors.amber : Colors.blue,
            title: '文件信息',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('路径: ${widget.item.path}'),
                const SizedBox(height: 4),
                Text('大小: ${FormatUtils.formatSize(widget.item.size)}'),
                if (widget.item.isDirectory) ...
                  [const SizedBox(height: 4), Text('包含 ${widget.item.fileCount} 个文件')],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // AI 分析内容
          _buildInfoCard(
            icon: Icons.description,
            iconColor: Colors.blue,
            title: '内容描述',
            content: Text(description),
          ),
          const SizedBox(height: 12),

          // 删除建议
          _buildInfoCard(
            icon: canDelete ? Icons.check_circle : Icons.warning,
            iconColor: canDelete ? Colors.green : Colors.orange,
            title: '删除建议',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      canDelete ? '可以删除' : '不建议删除',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canDelete ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildRiskBadge(riskLevel),
                  ],
                ),
                if (reason.isNotEmpty) ...[const SizedBox(height: 8), Text(reason)],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 建议操作
          if (suggestion.isNotEmpty)
            _buildInfoCard(
              icon: Icons.lightbulb,
              iconColor: Colors.amber,
              title: '建议操作',
              content: Text(suggestion),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color color;
    String text;
    switch (riskLevel.toLowerCase()) {
      case 'low':
        color = Colors.green;
        text = '低风险';
        break;
      case 'high':
        color = Colors.red;
        text = '高风险';
        break;
      default:
        color = Colors.orange;
        text = '中风险';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// AI 智能拆分对话框
class _AISplitDialog extends StatefulWidget {
  final FileItem item;
  final provider.AIProvider aiProvider;

  const _AISplitDialog({
    required this.item,
    required this.aiProvider,
  });

  @override
  State<_AISplitDialog> createState() => _AISplitDialogState();
}

class _AISplitDialogState extends State<_AISplitDialog> {
  bool _isLoading = true;
  bool _isScanning = true;
  String? _error;
  List<ContentGroup>? _groups;
  List<_SubfolderInfo> _subfolders = [];

  @override
  void initState() {
    super.initState();
    _scanAndAnalyze();
  }

  /// 扫描子文件夹并分析
  Future<void> _scanAndAnalyze() async {
    try {
      // 第一步：扫描子文件夹
      setState(() {
        _isScanning = true;
      });
      
      final subfolders = await _scanSubfolders();
      
      setState(() {
        _subfolders = subfolders;
        _isScanning = false;
      });

      // 第二步：调用 AI 分析分组
      final groups = await _analyzeWithAI(subfolders);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _groups = groups;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 扫描子文件夹
  Future<List<_SubfolderInfo>> _scanSubfolders() async {
    final dir = Directory(widget.item.path);
    final subfolders = <_SubfolderInfo>[];
    
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final size = await _calculateDirSize(entity);
        final name = entity.path.split(Platform.pathSeparator).last;
        subfolders.add(_SubfolderInfo(
          name: name,
          path: entity.path,
          size: size,
        ));
      }
    }
    
    // 按大小排序
    subfolders.sort((a, b) => b.size.compareTo(a.size));
    return subfolders;
  }

  Future<int> _calculateDirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (_) {}
    return size;
  }

  /// 调用 AI 分析分组
  Future<List<ContentGroup>> _analyzeWithAI(List<_SubfolderInfo> subfolders) async {
    final service = AIAnalysisService(
      config: widget.aiProvider.config,
      principles: widget.aiProvider.principles,
    );

    // 构建子文件夹摘要
    final subfoldersText = subfolders.take(50).map((sf) {
      final sizeMB = (sf.size / 1024 / 1024).toStringAsFixed(2);
      return '- ${sf.name}: $sizeMB MB';
    }).join('\n');

    final result = await service.analyzeFolderGroups(
      folderPath: widget.item.path,
      totalSize: widget.item.size,
      subfoldersSummary: subfoldersText,
    );

    // 将 AI 返回的分组与实际子文件夹匹配
    final groups = <ContentGroup>[];
    for (final group in result) {
      final groupName = group['groupName'] as String? ?? '未分类';
      final description = group['description'] as String? ?? '';
      final folderNames = (group['folders'] as List?)?.cast<String>() ?? [];
      final canDelete = group['canDelete'] as bool? ?? false;
      final riskLevel = group['riskLevel'] as String? ?? 'medium';

      // 匹配实际的子文件夹
      final matchedFolders = subfolders.where((sf) {
        return folderNames.any((name) => 
          sf.name.toLowerCase().contains(name.toLowerCase()) ||
          name.toLowerCase().contains(sf.name.toLowerCase())
        );
      }).toList();

      if (matchedFolders.isNotEmpty) {
        final totalSize = matchedFolders.fold<int>(0, (sum, sf) => sum + sf.size);
        groups.add(ContentGroup(
          name: groupName,
          description: description,
          folders: matchedFolders,
          totalSize: totalSize,
          canDelete: canDelete,
          riskLevel: riskLevel,
        ));
      }
    }

    // 添加未分类的文件夹
    final categorizedPaths = groups.expand((g) => g.folders.map((f) => f.path)).toSet();
    final uncategorized = subfolders.where((sf) => !categorizedPaths.contains(sf.path)).toList();
    
    if (uncategorized.isNotEmpty) {
      final totalSize = uncategorized.fold<int>(0, (sum, sf) => sum + sf.size);
      groups.add(ContentGroup(
        name: '其他/未分类',
        description: '无法自动识别的文件夹',
        folders: uncategorized,
        totalSize: totalSize,
        canDelete: false,
        riskLevel: 'medium',
      ));
    }

    // 按大小排序
    groups.sort((a, b) => b.totalSize.compareTo(a.totalSize));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_tree, color: Colors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 智能拆分',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  widget.item.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: _buildContent(),
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _scanAndAnalyze();
            },
            child: const Text('重试'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_isScanning ? '正在扫描子文件夹...' : 'AI 正在分析内容分组...'),
            if (!_isScanning && _subfolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '发现 ${_subfolders.length} 个子文件夹',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              '分析失败',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_groups == null || _groups!.isEmpty) {
      return const Center(child: Text('未能识别出内容分组'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 总览
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '识别到 ${_groups!.length} 个内容分组，总大小 ${FormatUtils.formatSize(widget.item.size)}',
                  style: TextStyle(color: Colors.purple.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 分组列表
        Expanded(
          child: ListView.builder(
            itemCount: _groups!.length,
            itemBuilder: (context, index) {
              final group = _groups![index];
              return _buildGroupCard(group, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(ContentGroup group, int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
    ];
    final color = colors[index % colors.length];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.folder, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _buildRiskBadge(group.riskLevel),
          ],
        ),
        subtitle: Text(
          '${FormatUtils.formatSize(group.totalSize)} · ${group.folders.length} 个文件夹',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 描述
                if (group.description.isNotEmpty) ...[
                  Text(
                    group.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 删除建议
                Row(
                  children: [
                    Icon(
                      group.canDelete ? Icons.check_circle : Icons.warning,
                      size: 16,
                      color: group.canDelete ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      group.canDelete ? '可以安全删除' : '不建议删除',
                      style: TextStyle(
                        fontSize: 12,
                        color: group.canDelete ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 子文件夹列表
                const Divider(),
                ...group.folders.take(10).map((sf) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sf.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        FormatUtils.formatSize(sf.size),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )),
                if (group.folders.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '... 还有 ${group.folders.length - 10} 个文件夹',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color color;
    String text;
    switch (riskLevel.toLowerCase()) {
      case 'low':
        color = Colors.green;
        text = '低风险';
        break;
      case 'high':
        color = Colors.red;
        text = '高风险';
        break;
      default:
        color = Colors.orange;
        text = '中风险';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// 子文件夹信息
class _SubfolderInfo {
  final String name;
  final String path;
  final int size;

  _SubfolderInfo({
    required this.name,
    required this.path,
    required this.size,
  });
}

/// 内容分组
class ContentGroup {
  final String name;
  final String description;
  final List<_SubfolderInfo> folders;
  final int totalSize;
  final bool canDelete;
  final String riskLevel;

  ContentGroup({
    required this.name,
    required this.description,
    required this.folders,
    required this.totalSize,
    required this.canDelete,
    required this.riskLevel,
  });
}
