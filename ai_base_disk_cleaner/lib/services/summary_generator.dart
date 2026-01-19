import '../models/file_item.dart';
import '../utils/format_utils.dart';

/// 磁盘摘要生成器
/// 
/// 将扫描结果转换为 AI 能理解的文本摘要，
/// 控制 Token 数量，避免超出上下文限制
class SummaryGenerator {
  /// 生成完整的磁盘摘要（用于 AI 分析）
  static String generateSummary(ScanSummary summary, {int maxItems = 20}) {
    final buffer = StringBuffer();

    // 1. 基本信息
    buffer.writeln('## 磁盘扫描摘要');
    buffer.writeln();
    buffer.writeln('- 扫描路径: ${summary.rootPath}');
    buffer.writeln('- 总大小: ${FormatUtils.formatSize(summary.totalSize)}');
    buffer.writeln('- 文件数量: ${FormatUtils.formatNumber(summary.totalFiles)}');
    buffer.writeln('- 文件夹数量: ${FormatUtils.formatNumber(summary.totalFolders)}');
    buffer.writeln();

    // 2. 最大的文件夹
    buffer.writeln('## 占用空间最大的文件夹 (Top $maxItems)');
    buffer.writeln();
    final topFolders = summary.topLargestFolders.take(maxItems);
    for (var i = 0; i < topFolders.length; i++) {
      final folder = topFolders.elementAt(i);
      final percentage = FormatUtils.formatPercentage(folder.size, summary.totalSize);
      buffer.writeln('${i + 1}. ${folder.path}');
      buffer.writeln('   - 大小: ${FormatUtils.formatSize(folder.size)} ($percentage)');
      buffer.writeln('   - 文件数: ${folder.fileCount}');
      if (folder.modifiedTime != null) {
        buffer.writeln('   - 最后修改: ${FormatUtils.formatDateTime(folder.modifiedTime)}');
      }
    }
    buffer.writeln();

    // 3. 最大的文件
    buffer.writeln('## 占用空间最大的文件 (Top $maxItems)');
    buffer.writeln();
    final topFiles = summary.topLargestFiles.take(maxItems);
    for (var i = 0; i < topFiles.length; i++) {
      final file = topFiles.elementAt(i);
      final percentage = FormatUtils.formatPercentage(file.size, summary.totalSize);
      buffer.writeln('${i + 1}. ${file.path}');
      buffer.writeln('   - 大小: ${FormatUtils.formatSize(file.size)} ($percentage)');
      if (file.modifiedTime != null) {
        buffer.writeln('   - 最后修改: ${FormatUtils.formatDateTime(file.modifiedTime)}');
      }
    }
    buffer.writeln();

    // 4. 文件类型统计
    buffer.writeln('## 文件类型分布 (按占用空间)');
    buffer.writeln();
    final topTypes = summary.fileTypeStats.take(15);
    for (var i = 0; i < topTypes.length; i++) {
      final stat = topTypes.elementAt(i);
      final percentage = FormatUtils.formatPercentage(stat.totalSize, summary.totalSize);
      buffer.writeln('${i + 1}. .${stat.extension}: ${FormatUtils.formatSize(stat.totalSize)} ($percentage, ${stat.fileCount} 个文件)');
    }
    buffer.writeln();

    // 5. 潜在可清理项目检测
    buffer.writeln('## 检测到的潜在可清理项目');
    buffer.writeln();
    final suspicious = _detectSuspiciousFolders(summary);
    if (suspicious.isEmpty) {
      buffer.writeln('未检测到明显的可清理项目。');
    } else {
      for (final item in suspicious) {
        buffer.writeln('- $item');
      }
    }

    return buffer.toString();
  }

  /// 检测可疑的可清理文件夹
  static List<String> _detectSuspiciousFolders(ScanSummary summary) {
    final suspicious = <String>[];
    final keywords = [
      'node_modules',
      '__pycache__',
      '.cache',
      'cache',
      'temp',
      'tmp',
      '.tmp',
      'logs',
      '.logs',
      'build',
      'dist',
      '.gradle',
      '.dart_tool',
      'bin/Debug',
      'bin/Release',
      'obj',
      '.vs',
      '.idea',
    ];

    for (final folder in summary.topLargestFolders) {
      final lowerPath = folder.path.toLowerCase();
      final lowerName = folder.name.toLowerCase();
      
      for (final keyword in keywords) {
        if (lowerName == keyword || lowerPath.contains('/$keyword/') || lowerPath.contains('\\$keyword\\')) {
          suspicious.add('${folder.path} (${FormatUtils.formatSize(folder.size)}) - 可能是 $keyword 缓存目录');
          break;
        }
      }
    }

    // 检测大型日志文件
    for (final file in summary.topLargestFiles) {
      if (file.extension == 'log' && file.size > 100 * 1024 * 1024) { // > 100MB
        suspicious.add('${file.path} (${FormatUtils.formatSize(file.size)}) - 大型日志文件');
      }
      if (file.extension == 'tmp' || file.extension == 'temp') {
        suspicious.add('${file.path} (${FormatUtils.formatSize(file.size)}) - 临时文件');
      }
    }

    return suspicious.take(20).toList();
  }

  /// 生成精简的 JSON 摘要（用于 API 调用）
  static Map<String, dynamic> generateJsonSummary(ScanSummary summary, {int maxItems = 20}) {
    return {
      'rootPath': summary.rootPath,
      'totalSize': summary.totalSize,
      'totalSizeFormatted': FormatUtils.formatSize(summary.totalSize),
      'totalFiles': summary.totalFiles,
      'totalFolders': summary.totalFolders,
      'topFolders': summary.topLargestFolders.take(maxItems).map((f) => {
        'path': f.path,
        'name': f.name,
        'size': f.size,
        'sizeFormatted': FormatUtils.formatSize(f.size),
        'fileCount': f.fileCount,
        'modifiedTime': f.modifiedTime?.toIso8601String(),
      }).toList(),
      'topFiles': summary.topLargestFiles.take(maxItems).map((f) => {
        'path': f.path,
        'name': f.name,
        'size': f.size,
        'sizeFormatted': FormatUtils.formatSize(f.size),
        'extension': f.extension,
        'modifiedTime': f.modifiedTime?.toIso8601String(),
      }).toList(),
      'fileTypes': summary.fileTypeStats.take(15).map((s) => {
        'extension': s.extension,
        'totalSize': s.totalSize,
        'sizeFormatted': FormatUtils.formatSize(s.totalSize),
        'fileCount': s.fileCount,
      }).toList(),
      'suspiciousItems': _detectSuspiciousFolders(summary),
    };
  }
}
