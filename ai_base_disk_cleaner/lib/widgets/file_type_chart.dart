import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/file_item.dart';
import '../utils/format_utils.dart';

/// 文件类型分布图表
class FileTypeChart extends StatelessWidget {
  final List<FileTypeStats> stats;

  const FileTypeChart({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text('没有文件类型数据'),
      );
    }

    // 取前 10 个类型用于图表显示
    final chartData = stats.take(10).toList();
    final totalSize = stats.fold<int>(0, (sum, s) => sum + s.totalSize);

    return Column(
      children: [
        // 饼图
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: _buildPieSections(chartData, totalSize),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // 图例列表
        ...chartData.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final percentage = totalSize > 0 ? stat.totalSize / totalSize : 0.0;
          
          return _buildLegendItem(
            color: _getColor(index),
            extension: stat.extension,
            size: FormatUtils.formatSize(stat.totalSize),
            count: stat.fileCount,
            percentage: percentage,
          );
        }),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<FileTypeStats> data,
    int totalSize,
  ) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      final percentage = totalSize > 0 ? (stat.totalSize / totalSize * 100) : 0.0;
      
      return PieChartSectionData(
        color: _getColor(index),
        value: stat.totalSize.toDouble(),
        title: percentage > 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem({
    required Color color,
    required String extension,
    required String size,
    required int count,
    required double percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              extension,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '$count 个',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              size,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${(percentage * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(int index) {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }
}
