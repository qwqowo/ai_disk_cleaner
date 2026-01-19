import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/file_item.dart';

/// 扫描进度回调
typedef ScanProgressCallback = void Function(int scannedCount, String currentPath);

/// 磁盘扫描服务
class ScannerService {
  bool _isCancelled = false;
  
  /// 是否已取消
  bool get isCancelled => _isCancelled;
  
  /// 取消扫描
  void cancel() {
    _isCancelled = true;
  }
  
  /// 重置取消状态
  void reset() {
    _isCancelled = false;
  }

  /// 需要跳过的系统/重要目录（Windows）
  static final Set<String> _windowsSkipPaths = {
    r'C:\Windows',
    r'C:\$Recycle.Bin',
    r'C:\$WinREAgent',
    r'C:\System Volume Information',
    r'C:\ProgramData\Microsoft\Windows\Containers',
    r'C:\ProgramData\Microsoft\Windows Defender',
    r'C:\ProgramData\Packages',
    r'C:\Recovery',
    r'C:\hiberfil.sys',
    r'C:\pagefile.sys',
    r'C:\swapfile.sys',
  };

  /// 需要跳过的目录名称模式
  static final Set<String> _skipDirNames = {
    r'$Recycle.Bin',
    r'System Volume Information',
    r'$WinREAgent',
    r'.git',  // Git 仓库内部文件夹（可选）
  };

  /// 需要"浅扫描"的目录名称（只统计总大小，不展开内部文件）
  /// 这些通常是依赖/缓存目录，包含大量小文件
  static final Set<String> _shallowScanDirNames = {
    'node_modules',      // Node.js 依赖
    '.gradle',           // Gradle 缓存
    '.m2',               // Maven 本地仓库
    '__pycache__',       // Python 缓存
    '.venv',             // Python 虚拟环境
    'venv',              // Python 虚拟环境
    '.tox',              // Python tox 测试环境
    'site-packages',     // Python 包目录
    'target',            // Rust/Maven 构建输出
    '.dart_tool',        // Dart 工具缓存
    '.pub-cache',        // Dart/Flutter 包缓存
    'vendor',            // PHP/Go 依赖
    'packages',          // 各种包目录
    '.cache',            // 通用缓存目录
    '.npm',              // npm 缓存
    '.yarn',             // Yarn 缓存
    'bower_components',  // Bower 依赖
    '.nuget',            // NuGet 缓存
    'obj',               // .NET 编译输出
    '.cargo',            // Rust cargo 缓存
  };

  /// 检查是否应该浅扫描（只统计大小）
  bool _shouldShallowScan(String dirName) {
    return _shallowScanDirNames.contains(dirName) ||
           _shallowScanDirNames.contains(dirName.toLowerCase());
  }

  /// 检查路径是否应该跳过
  bool _shouldSkip(String path) {
    final normalizedPath = path.replaceAll('/', r'\');
    
    // 检查完整路径匹配
    for (final skipPath in _windowsSkipPaths) {
      if (normalizedPath.toLowerCase() == skipPath.toLowerCase() ||
          normalizedPath.toLowerCase().startsWith('${skipPath.toLowerCase()}\\')) {
        return true;
      }
    }
    
    // 检查目录名匹配
    final dirName = p.basename(path);
    if (_skipDirNames.contains(dirName)) {
      return true;
    }
    
    // 跳过隐藏的系统文件（以 $ 开头）
    if (dirName.startsWith(r'$')) {
      return true;
    }
    
    return false;
  }

  /// 扫描指定目录
  /// 
  /// [path] 要扫描的目录路径
  /// [onProgress] 进度回调
  /// [maxDepth] 最大递归深度，-1 表示无限制
  /// [skipSystemDirs] 是否跳过系统目录
  Future<ScanSummary> scanDirectory(
    String path, {
    ScanProgressCallback? onProgress,
    int maxDepth = -1,
    bool skipSystemDirs = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _isCancelled = false;
    
    int scannedCount = 0;
    int skippedCount = 0;
    final allFiles = <FileItem>[];
    final allFolders = <FileItem>[];
    final extensionStats = <String, _ExtensionAccumulator>{};

    // 递归扫描
    Future<FileItem?> scanRecursive(String dirPath, int depth) async {
      if (_isCancelled) return null;
      
      // 检查是否应该跳过此目录
      if (skipSystemDirs && _shouldSkip(dirPath)) {
        skippedCount++;
        debugPrint('Skipped system directory: $dirPath');
        return null;
      }
      
      final dir = Directory(dirPath);
      if (!await dir.exists()) return null;

      int totalSize = 0;
      int fileCount = 0;
      int folderCount = 0;
      final children = <FileItem>[];

      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (_isCancelled) break;
          
          // 跳过系统文件/目录
          if (skipSystemDirs && _shouldSkip(entity.path)) {
            skippedCount++;
            continue;
          }
          
          scannedCount++;
          if (scannedCount % 100 == 0) {
            onProgress?.call(scannedCount, entity.path);
          }

          try {
            final stat = await entity.stat();
            final name = p.basename(entity.path);

            if (entity is File) {
              final fileItem = FileItem(
                path: entity.path,
                name: name,
                size: stat.size,
                isDirectory: false,
                modifiedTime: stat.modified,
                accessedTime: stat.accessed,
              );
              
              children.add(fileItem);
              allFiles.add(fileItem);
              totalSize += stat.size;
              fileCount++;

              // 统计扩展名
              final ext = fileItem.extension.isEmpty ? '(无扩展名)' : fileItem.extension;
              extensionStats.putIfAbsent(ext, () => _ExtensionAccumulator());
              extensionStats[ext]!.add(stat.size);
              
            } else if (entity is Directory) {
              final dirName = p.basename(entity.path);
              
              // 检查是否需要浅扫描（node_modules 等）
              if (_shouldShallowScan(dirName)) {
                // 浅扫描：只快速统计大小，不展开内部文件
                final shallowResult = await _shallowScanDirectory(entity.path);
                final folderItem = FileItem(
                  path: entity.path,
                  name: name,
                  size: shallowResult.size,
                  isDirectory: true,
                  modifiedTime: stat.modified,
                  accessedTime: stat.accessed,
                  fileCount: shallowResult.fileCount,
                  folderCount: shallowResult.folderCount,
                  children: const [], // 不展开子项
                );
                children.add(folderItem);
                allFolders.add(folderItem);
                totalSize += shallowResult.size;
                fileCount += shallowResult.fileCount;
                folderCount += shallowResult.folderCount + 1;
                debugPrint('Shallow scanned: $dirName (${shallowResult.fileCount} files, ${shallowResult.size} bytes)');
              } else if (maxDepth == -1 || depth < maxDepth) {
                final subItem = await scanRecursive(entity.path, depth + 1);
                if (subItem != null) {
                  children.add(subItem);
                  allFolders.add(subItem);
                  totalSize += subItem.size;
                  fileCount += subItem.fileCount;
                  folderCount += subItem.folderCount + 1;
                }
              } else {
                // 达到最大深度，只记录文件夹本身
                final folderItem = FileItem(
                  path: entity.path,
                  name: name,
                  size: 0,
                  isDirectory: true,
                  modifiedTime: stat.modified,
                  accessedTime: stat.accessed,
                );
                children.add(folderItem);
                folderCount++;
              }
            }
          } catch (e) {
            // 忽略无权限或其他错误的文件
            debugPrint('Error accessing ${entity.path}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error listing directory $dirPath: $e');
      }

      // 按大小排序子项
      children.sort((a, b) => b.size.compareTo(a.size));

      return FileItem(
        path: dirPath,
        name: p.basename(dirPath),
        size: totalSize,
        isDirectory: true,
        children: children,
        fileCount: fileCount,
        folderCount: folderCount,
      );
    }

    final rootItem = await scanRecursive(path, 0);
    stopwatch.stop();

    if (rootItem == null || _isCancelled) {
      return ScanSummary(
        rootPath: path,
        totalSize: 0,
        totalFiles: 0,
        totalFolders: 0,
        topLargestFolders: [],
        topLargestFiles: [],
        fileTypeStats: [],
        scanDuration: stopwatch.elapsed,
      );
    }

    // 获取最大的文件夹 (Top 50)
    allFolders.sort((a, b) => b.size.compareTo(a.size));
    
    // 智能过滤：移除冗余的父文件夹
    // 如果一个文件夹的最大子文件夹占其总大小的 90% 以上，则该父文件夹是冗余的
    final filteredFolders = _filterRedundantFolders(allFolders.take(100).toList());
    final topFolders = filteredFolders.take(50).toList();

    // 获取最大的文件 (Top 50)
    allFiles.sort((a, b) => b.size.compareTo(a.size));
    final topFiles = allFiles.take(50).toList();

    // 生成扩展名统计
    final typeStats = extensionStats.entries
        .map((e) => FileTypeStats(
              extension: e.key,
              totalSize: e.value.totalSize,
              fileCount: e.value.count,
            ))
        .toList()
      ..sort((a, b) => b.totalSize.compareTo(a.totalSize));

    return ScanSummary(
      rootPath: path,
      totalSize: rootItem.size,
      totalFiles: rootItem.fileCount,
      totalFolders: rootItem.folderCount,
      topLargestFolders: topFolders,
      topLargestFiles: topFiles,
      fileTypeStats: typeStats.take(20).toList(),
      scanDuration: stopwatch.elapsed,
      rootItem: rootItem,
      skippedCount: skippedCount,
    );
  }

  /// 智能过滤冗余的父文件夹
  /// 
  /// 如果一个文件夹的最大子文件夹占其总大小的 [threshold] 以上，
  /// 且该子文件夹也在列表中，则该父文件夹被视为冗余并移除。
  /// 
  /// 例如：Users (97GB) 的子文件夹 15pro (97GB) 占比 99%+，
  /// 那么 Users 就是冗余的，因为查看 15pro 就够了。
  List<FileItem> _filterRedundantFolders(List<FileItem> folders, {double threshold = 0.90}) {
    if (folders.isEmpty) return folders;
    
    // 建立路径到文件夹的映射
    final pathToFolder = <String, FileItem>{};
    for (final folder in folders) {
      pathToFolder[folder.path] = folder;
    }
    
    // 标记需要移除的冗余文件夹
    final redundantPaths = <String>{};
    
    for (final folder in folders) {
      if (folder.size == 0 || folder.children.isEmpty) continue;
      
      // 找到最大的子文件夹
      final subFolders = folder.children.where((c) => c.isDirectory).toList();
      if (subFolders.isEmpty) continue;
      
      subFolders.sort((a, b) => b.size.compareTo(a.size));
      final largestChild = subFolders.first;
      
      // 计算最大子文件夹占父文件夹的比例
      final ratio = largestChild.size / folder.size;
      
      // 如果最大子文件夹占比超过阈值，且该子文件夹也在结果列表中
      // 则父文件夹是冗余的
      if (ratio >= threshold && pathToFolder.containsKey(largestChild.path)) {
        redundantPaths.add(folder.path);
        debugPrint('Filtered redundant folder: ${folder.name} (${(ratio * 100).toStringAsFixed(1)}% from ${largestChild.name})');
      }
    }
    
    // 返回过滤后的列表
    return folders.where((f) => !redundantPaths.contains(f.path)).toList();
  }

  /// 快速获取目录大小（不递归展开所有子项）
  Future<int> getDirectorySize(String path) async {
    int totalSize = 0;
    final dir = Directory(path);
    
    if (!await dir.exists()) return 0;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}

    return totalSize;
  }

  /// 浅扫描目录 - 快速统计大小和文件数，不记录每个文件详情
  /// 适用于 node_modules 等包含大量小文件的目录
  Future<_ShallowScanResult> _shallowScanDirectory(String path) async {
    int totalSize = 0;
    int fileCount = 0;
    int folderCount = 0;
    final dir = Directory(path);
    
    if (!await dir.exists()) {
      return _ShallowScanResult(size: 0, fileCount: 0, folderCount: 0);
    }

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (_isCancelled) break;
        
        if (entity is File) {
          try {
            totalSize += await entity.length();
            fileCount++;
          } catch (_) {}
        } else if (entity is Directory) {
          folderCount++;
        }
      }
    } catch (_) {}

    return _ShallowScanResult(
      size: totalSize,
      fileCount: fileCount,
      folderCount: folderCount,
    );
  }
}

/// 浅扫描结果
class _ShallowScanResult {
  final int size;
  final int fileCount;
  final int folderCount;
  
  _ShallowScanResult({
    required this.size,
    required this.fileCount,
    required this.folderCount,
  });
}

/// 扩展名统计累加器
class _ExtensionAccumulator {
  int totalSize = 0;
  int count = 0;

  void add(int size) {
    totalSize += size;
    count++;
  }
}
