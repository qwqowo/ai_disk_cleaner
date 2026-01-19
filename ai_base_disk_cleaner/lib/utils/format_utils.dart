import 'package:intl/intl.dart';

/// 文件大小格式化工具
class FormatUtils {
  static final _numberFormat = NumberFormat('#,##0.##');

  /// 将字节数格式化为可读的大小字符串
  static String formatSize(int bytes) {
    if (bytes < 0) return '0 B';
    
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    if (unitIndex == 0) {
      return '${bytes.toInt()} ${units[unitIndex]}';
    }
    
    return '${_numberFormat.format(size)} ${units[unitIndex]}';
  }

  /// 格式化数字（添加千分位分隔符）
  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  /// 格式化时长
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds} 毫秒';
    } else if (duration.inMinutes < 1) {
      return '${duration.inSeconds} 秒';
    } else if (duration.inHours < 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '$minutes 分 $seconds 秒';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '$hours 小时 $minutes 分';
    }
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  /// 计算百分比
  static String formatPercentage(int part, int total) {
    if (total == 0) return '0%';
    final percentage = (part / total * 100);
    if (percentage < 0.01) return '<0.01%';
    return '${percentage.toStringAsFixed(2)}%';
  }
}
