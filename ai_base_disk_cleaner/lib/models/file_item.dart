/// 文件/文件夹数据模型
class FileItem {
  final String path;
  final String name;
  final int size;
  final bool isDirectory;
  final DateTime? modifiedTime;
  final DateTime? accessedTime;
  final List<FileItem> children;
  final int fileCount;
  final int folderCount;

  FileItem({
    required this.path,
    required this.name,
    required this.size,
    required this.isDirectory,
    this.modifiedTime,
    this.accessedTime,
    this.children = const [],
    this.fileCount = 0,
    this.folderCount = 0,
  });

  /// 获取文件扩展名
  String get extension {
    if (isDirectory) return '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  /// 复制并更新属性
  FileItem copyWith({
    String? path,
    String? name,
    int? size,
    bool? isDirectory,
    DateTime? modifiedTime,
    DateTime? accessedTime,
    List<FileItem>? children,
    int? fileCount,
    int? folderCount,
  }) {
    return FileItem(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      isDirectory: isDirectory ?? this.isDirectory,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      accessedTime: accessedTime ?? this.accessedTime,
      children: children ?? this.children,
      fileCount: fileCount ?? this.fileCount,
      folderCount: folderCount ?? this.folderCount,
    );
  }

  @override
  String toString() {
    return 'FileItem(name: $name, size: $size, isDir: $isDirectory)';
  }

  /// 转换为 JSON 格式（用于 AI 分析）
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'isDirectory': isDirectory,
      'modifiedTime': modifiedTime?.toIso8601String(),
      'fileCount': fileCount,
      'folderCount': folderCount,
    };
  }
}

/// 文件类型统计
class FileTypeStats {
  final String extension;
  final int totalSize;
  final int fileCount;

  FileTypeStats({
    required this.extension,
    required this.totalSize,
    required this.fileCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'extension': extension,
      'totalSize': totalSize,
      'fileCount': fileCount,
    };
  }
}

/// 扫描结果摘要
class ScanSummary {
  final String rootPath;
  final int totalSize;
  final int totalFiles;
  final int totalFolders;
  final List<FileItem> topLargestFolders;
  final List<FileItem> topLargestFiles;
  final List<FileTypeStats> fileTypeStats;
  final Duration scanDuration;
  final FileItem? rootItem;  // 完整的文件树，用于 Treemap
  final int skippedCount;     // 跳过的系统目录数量

  ScanSummary({
    required this.rootPath,
    required this.totalSize,
    required this.totalFiles,
    required this.totalFolders,
    required this.topLargestFolders,
    required this.topLargestFiles,
    required this.fileTypeStats,
    required this.scanDuration,
    this.rootItem,
    this.skippedCount = 0,
  });

  /// 转换为 JSON 格式（用于 AI 分析）
  Map<String, dynamic> toJson() {
    return {
      'rootPath': rootPath,
      'totalSize': totalSize,
      'totalFiles': totalFiles,
      'totalFolders': totalFolders,
      'topLargestFolders': topLargestFolders.map((f) => f.toJson()).toList(),
      'topLargestFiles': topLargestFiles.map((f) => f.toJson()).toList(),
      'fileTypeStats': fileTypeStats.map((s) => s.toJson()).toList(),
    };
  }
}
