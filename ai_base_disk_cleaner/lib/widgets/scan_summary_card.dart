import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../utils/format_utils.dart';

/// 扫描摘要卡片
class ScanSummaryCard extends StatelessWidget {
  final ScanSummary summary;

  const ScanSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '扫描摘要',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildSummaryItem(
              icon: Icons.folder,
              label: '扫描路径',
              value: summary.rootPath,
              iconColor: Colors.amber,
            ),
            _buildSummaryItem(
              icon: Icons.storage,
              label: '总大小',
              value: FormatUtils.formatSize(summary.totalSize),
              iconColor: Colors.red,
              highlight: true,
            ),
            _buildSummaryItem(
              icon: Icons.insert_drive_file,
              label: '文件数量',
              value: FormatUtils.formatNumber(summary.totalFiles),
              iconColor: Colors.blue,
            ),
            _buildSummaryItem(
              icon: Icons.folder_copy,
              label: '文件夹数量',
              value: FormatUtils.formatNumber(summary.totalFolders),
              iconColor: Colors.orange,
            ),
            _buildSummaryItem(
              icon: Icons.timer,
              label: '扫描耗时',
              value: FormatUtils.formatDuration(summary.scanDuration),
              iconColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              fontSize: highlight ? 16 : 14,
              color: highlight ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
