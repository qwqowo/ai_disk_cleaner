import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/file_item.dart';
import '../models/cleaning_suggestion.dart';
import '../providers/scan_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/operation_provider.dart';
import '../utils/format_utils.dart';
import '../widgets/file_tree_view.dart';
import '../widgets/scan_summary_card.dart';
import '../widgets/file_type_chart.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/execution_dialog.dart';
import '../widgets/treemap_chart.dart';
import 'settings_page.dart';
import 'history_page.dart';

/// 主页面 - 磁盘扫描器
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 磁盘清理器'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 操作历史按钮
          Consumer<OperationProvider>(
            builder: (context, opProvider, child) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: opProvider.history.isNotEmpty,
                  label: Text(
                    opProvider.history.length > 99 
                        ? '99+' 
                        : opProvider.history.length.toString(),
                  ),
                  child: const Icon(Icons.history),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistoryPage(logs: opProvider.history),
                    ),
                  );
                },
                tooltip: '操作历史',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // 顶部控制栏
            _buildControlBar(context, provider),
            
            // 扫描进度
            if (provider.isScanning) _buildProgressBar(provider),
            
            // 主内容区
            Expanded(
              child: _buildMainContent(context, provider),
            ),
            
            // 底部状态栏
            _buildStatusBar(context, provider),
          ],
        );
      },
    );
  }

  Widget _buildControlBar(BuildContext context, ScanProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 目录选择
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.selectedPath ?? '请选择要扫描的目录...',
                      style: TextStyle(
                        color: provider.selectedPath != null
                            ? Colors.black87
                            : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 选择目录按钮
          ElevatedButton.icon(
            onPressed: provider.isScanning ? null : () => _selectDirectory(context),
            icon: const Icon(Icons.folder_open),
            label: const Text('选择目录'),
          ),
          const SizedBox(width: 8),
          
          // 扫描/取消按钮
          if (provider.isScanning)
            ElevatedButton.icon(
              onPressed: () => provider.cancelScan(),
              icon: const Icon(Icons.stop),
              label: const Text('取消'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: provider.selectedPath != null
                  ? () => provider.startScan(provider.selectedPath!)
                  : null,
              icon: const Icon(Icons.search),
              label: const Text('开始扫描'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ScanProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                '已扫描 ${FormatUtils.formatNumber(provider.scannedCount)} 个项目',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            provider.currentPath,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ScanProvider provider) {
    if (provider.state == ScanState.idle) {
      return _buildWelcomeView();
    }

    if (provider.state == ScanState.scanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描文件系统...'),
          ],
        ),
      );
    }

    if (provider.state == ScanState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('扫描出错: ${provider.errorMessage}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.reset(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (provider.state == ScanState.cancelled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('扫描已取消'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.reset(),
              child: const Text('重新开始'),
            ),
          ],
        ),
      );
    }

    // 扫描完成，显示结果
    final summary = provider.summary;
    if (summary == null) return const SizedBox.shrink();

    return Row(
      children: [
        // 左侧：文件列表
        Expanded(
          flex: 3,
          child: _buildLeftPanel(context, summary),
        ),
        
        // 右侧：统计信息
        Expanded(
          flex: 2,
          child: _buildRightPanel(context, summary),
        ),
      ],
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            '欢迎使用 AI 磁盘清理器',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选择一个目录开始扫描，分析磁盘占用情况',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, ScanSummary summary) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              tabs: [
                Tab(text: '最大文件夹', icon: Icon(Icons.folder)),
                Tab(text: '最大文件', icon: Icon(Icons.insert_drive_file)),
                Tab(text: '空间视图', icon: Icon(Icons.grid_view)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 最大文件夹列表
                FileTreeView(
                  items: summary.topLargestFolders,
                  totalSize: summary.totalSize,
                ),
                // 最大文件列表
                FileTreeView(
                  items: summary.topLargestFiles,
                  totalSize: summary.totalSize,
                ),
                // Treemap 视图
                summary.rootItem != null
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return TreemapChart(
                            rootItem: summary.rootItem!,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            onItemTap: (item) {
                              // 可以显示详细信息
                              _showItemDetails(context, item);
                            },
                          );
                        },
                      )
                    : const Center(
                        child: Text('无法生成空间视图'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(BuildContext context, ScanSummary summary) {
    return Consumer<AIProvider>(
      builder: (context, aiProvider, child) {
        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              // AI 分析按钮
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade50,
                child: _buildAIAnalysisButton(context, summary, aiProvider),
              ),
              
              // AI 分析结果或统计信息
              Expanded(
                child: aiProvider.state == AnalysisState.completed && aiProvider.result != null
                    ? AnalysisResultPanel(
                        result: aiProvider.result!,
                        selectedIndices: aiProvider.selectedSuggestions,
                        onToggle: (index) => aiProvider.toggleSuggestion(index),
                        onSelectAll: () => aiProvider.selectAll(
                          aiProvider.selectedSuggestions.length != aiProvider.result!.suggestions.length,
                        ),
                        onSelectLowRisk: () => aiProvider.selectLowRisk(),
                        onExecuteSelected: () => _showExecuteConfirm(context, aiProvider),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 扫描摘要卡片
                            ScanSummaryCard(summary: summary),
                            const SizedBox(height: 16),
                            
                            // 文件类型分布
                            const Text(
                              '文件类型分布',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FileTypeChart(stats: summary.fileTypeStats),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAIAnalysisButton(BuildContext context, ScanSummary summary, AIProvider aiProvider) {
    if (aiProvider.isAnalyzing) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('AI 正在分析...'),
        ],
      );
    }

    if (aiProvider.state == AnalysisState.error) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '分析失败: ${aiProvider.errorMessage}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => aiProvider.analyze(summary),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      );
    }

    if (!aiProvider.isConfigured) {
      return Column(
        children: [
          const Text(
            '请先配置 AI API',
            style: TextStyle(color: Colors.orange),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('前往设置'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => aiProvider.analyze(summary),
            icon: const Icon(Icons.psychology),
            label: const Text('AI 智能分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (aiProvider.state == AnalysisState.completed) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => aiProvider.reset(),
            icon: const Icon(Icons.close),
            tooltip: '清除分析结果',
          ),
        ],
      ],
    );
  }

  void _showExecuteConfirm(BuildContext context, AIProvider aiProvider) async {
    final selected = aiProvider.getSelectedSuggestionsList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择要执行的建议'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 显示确认对话框
    final confirmed = await ExecutionConfirmDialog.show(
      context,
      suggestions: selected,
    );

    if (confirmed != true || !context.mounted) return;

    // 获取操作管理器
    final operationProvider = context.read<OperationProvider>();

    // 显示执行进度对话框
    final result = await ExecutionProgressDialog.show(
      context,
      suggestions: selected,
      onExecute: (onProgress) => operationProvider.executeSuggestions(
        selected,
        onProgress: onProgress,
      ),
    );

    if (result != null && context.mounted) {
      // 显示结果通知
      if (result.allSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '成功执行 ${result.successCount} 项操作，释放 ${FormatUtils.formatSize(result.totalSizeFreed)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '完成 ${result.successCount} 项，${result.failedCount} 项失败',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // 清除已执行的选择
      aiProvider.clearSelection();
    }
  }

  Widget _buildStatusBar(BuildContext context, ScanProvider provider) {
    final summary = provider.summary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          if (summary != null) ...[
            Text(
              '已扫描 ${FormatUtils.formatNumber(summary.totalFiles)} 个文件',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 16),
            Text(
              '${FormatUtils.formatNumber(summary.totalFolders)} 个文件夹',
              style: const TextStyle(fontSize: 13),
            ),
            if (summary.skippedCount > 0) ...[
              const SizedBox(width: 16),
              Tooltip(
                message: '已跳过系统目录以加速扫描',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.skip_next, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '跳过 ${summary.skippedCount} 项',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 16),
            Text(
              '总大小: ${FormatUtils.formatSize(summary.totalSize)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '扫描耗时: ${FormatUtils.formatDuration(summary.scanDuration)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ] else
            Text(
              '就绪',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择要扫描的目录',
    );
    
    if (result != null && context.mounted) {
      context.read<ScanProvider>().setSelectedPath(result);
    }
  }

  void _showItemDetails(BuildContext context, FileItem item) {
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
            if (item.isDirectory) ...[
              _buildDetailRow('文件数', FormatUtils.formatNumber(item.fileCount)),
              _buildDetailRow('文件夹数', FormatUtils.formatNumber(item.folderCount)),
            ],
            if (item.modifiedTime != null)
              _buildDetailRow('修改时间', FormatUtils.formatDateTime(item.modifiedTime!)),
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
}
