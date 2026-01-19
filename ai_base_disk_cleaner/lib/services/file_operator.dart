import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../models/operation_log.dart';
import '../models/cleaning_suggestion.dart';
import 'archive_config.dart';

/// 文件操作服务
/// 负责执行实际的文件删除、移动、压缩等操作
class FileOperator {
  /// 操作历史记录
  final List<OperationLog> _operationHistory = [];

  List<OperationLog> get operationHistory => List.unmodifiable(_operationHistory);

  /// 删除文件到回收站
  /// Windows: 使用 Shell32 API
  /// macOS/Linux: 移动到 Trash 目录
  Future<OperationLog> deleteToRecycleBin(String filePath) async {
    final file = File(filePath);
    final dir = Directory(filePath);
    final isDir = await dir.exists();
    final exists = isDir || await file.exists();

    if (!exists) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '文件或目录不存在',
        isDirectory: false,
      );
      _operationHistory.add(log);
      return log;
    }

    int? fileSize;
    if (!isDir) {
      fileSize = await file.length();
    } else {
      fileSize = await _calculateDirectorySize(dir);
    }

    try {
      String? trashPath;
      
      if (Platform.isWindows) {
        // Windows: 使用 shell32 SHFileOperation 移动到回收站
        final success = await _deleteToWindowsRecycleBin(filePath);
        if (!success) {
          throw Exception('无法移动到回收站');
        }
        trashPath = '回收站';
      } else if (Platform.isMacOS) {
        // macOS: 移动到 ~/.Trash
        trashPath = await _moveToMacOSTrash(filePath, isDir);
      } else if (Platform.isLinux) {
        // Linux: 移动到 ~/.local/share/Trash
        trashPath = await _moveToLinuxTrash(filePath, isDir);
      } else {
        throw UnsupportedError('不支持的操作系统');
      }

      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        targetPath: trashPath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.success,
        isReversible: true,
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    } catch (e) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: e.toString(),
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    }
  }

  /// 永久删除（危险操作，需要确认）
  Future<OperationLog> permanentDelete(String filePath) async {
    final file = File(filePath);
    final dir = Directory(filePath);
    final isDir = await dir.exists();
    final exists = isDir || await file.exists();

    if (!exists) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '文件或目录不存在',
        isReversible: false,
      );
      _operationHistory.add(log);
      return log;
    }

    int? fileSize;
    if (!isDir) {
      fileSize = await file.length();
    } else {
      fileSize = await _calculateDirectorySize(dir);
    }

    try {
      if (isDir) {
        await dir.delete(recursive: true);
      } else {
        await file.delete();
      }

      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.success,
        isReversible: false, // 永久删除不可恢复
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    } catch (e) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'delete',
        originalPath: filePath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: e.toString(),
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    }
  }

  /// 移动文件到指定目录（归档）
  Future<OperationLog> archiveTo(String sourcePath, String destinationDir) async {
    final file = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final isDir = await sourceDir.exists();
    final exists = isDir || await file.exists();

    if (!exists) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'archive',
        originalPath: sourcePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '文件或目录不存在',
      );
      _operationHistory.add(log);
      return log;
    }

    // 确保目标目录存在
    final destDir = Directory(destinationDir);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final fileName = path.basename(sourcePath);
    final targetPath = path.join(destinationDir, fileName);

    int? fileSize;
    if (!isDir) {
      fileSize = await file.length();
    } else {
      fileSize = await _calculateDirectorySize(sourceDir);
    }

    try {
      // 检查目标是否已存在
      final targetFile = File(targetPath);
      final targetDir = Directory(targetPath);
      if (await targetFile.exists() || await targetDir.exists()) {
        // 添加时间戳避免冲突
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ext = path.extension(fileName);
        final nameWithoutExt = path.basenameWithoutExtension(fileName);
        final newName = '${nameWithoutExt}_$timestamp$ext';
        final newTargetPath = path.join(destinationDir, newName);
        
        if (isDir) {
          await _copyDirectory(sourceDir, Directory(newTargetPath));
          await sourceDir.delete(recursive: true);
        } else {
          await file.copy(newTargetPath);
          await file.delete();
        }

        final log = OperationLog(
          id: _generateId(),
          operation: 'archive',
          originalPath: sourcePath,
          targetPath: newTargetPath,
          fileSize: fileSize,
          executedAt: DateTime.now(),
          status: OperationStatus.success,
          isReversible: true,
          isDirectory: isDir,
        );
        _operationHistory.add(log);
        return log;
      }

      if (isDir) {
        await _copyDirectory(sourceDir, Directory(targetPath));
        await sourceDir.delete(recursive: true);
      } else {
        await file.rename(targetPath);
      }

      final log = OperationLog(
        id: _generateId(),
        operation: 'archive',
        originalPath: sourcePath,
        targetPath: targetPath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.success,
        isReversible: true,
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    } catch (e) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'archive',
        originalPath: sourcePath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: e.toString(),
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    }
  }

  /// 智能归档 - 根据配置自动组织文件到归档目录
  /// 
  /// 按类型分文件夹（图片/视频/音频等）
  /// 可选按日期分子文件夹（年/月）
  Future<OperationLog> smartArchive(
    String sourcePath, 
    ArchiveConfig config,
  ) async {
    final file = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final isDir = await sourceDir.exists();
    final exists = isDir || await file.exists();

    if (!exists) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'archive',
        originalPath: sourcePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '文件或目录不存在',
      );
      _operationHistory.add(log);
      return log;
    }

    if (!config.isConfigured) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'archive',
        originalPath: sourcePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '未配置归档目录，请在设置中配置',
      );
      _operationHistory.add(log);
      return log;
    }

    // 构建目标目录路径
    String targetDir = config.archiveBasePath;

    // 按类型组织
    if (config.organizeByType && !isDir) {
      final subfolder = config.getSubfolderForFile(sourcePath);
      if (subfolder != null) {
        targetDir = path.join(targetDir, subfolder);
      } else {
        targetDir = path.join(targetDir, '其他');
      }
    }

    // 按日期组织
    if (config.organizeByDate) {
      final now = DateTime.now();
      final dateFolder = DateFormat('yyyy/MM').format(now);
      targetDir = path.join(targetDir, dateFolder);
    }

    // 调用基础归档方法
    return archiveTo(sourcePath, targetDir);
  }

  /// 压缩文件或目录为 zip（使用系统命令）
  Future<OperationLog> compressToZip(String sourcePath, {bool deleteOriginal = false}) async {
    final file = File(sourcePath);
    final sourceDir = Directory(sourcePath);
    final isDir = await sourceDir.exists();
    final exists = isDir || await file.exists();

    if (!exists) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'compress',
        originalPath: sourcePath,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: '文件或目录不存在',
      );
      _operationHistory.add(log);
      return log;
    }

    int? fileSize;
    if (!isDir) {
      fileSize = await file.length();
    } else {
      fileSize = await _calculateDirectorySize(sourceDir);
    }

    final zipPath = '$sourcePath.zip';

    try {
      ProcessResult result;

      if (Platform.isWindows) {
        // Windows: 使用 PowerShell 的 Compress-Archive
        result = await Process.run(
          'powershell',
          [
            '-Command',
            'Compress-Archive',
            '-Path', '"$sourcePath"',
            '-DestinationPath', '"$zipPath"',
            '-Force',
          ],
          runInShell: true,
        );
      } else {
        // macOS/Linux: 使用 zip 命令
        final parent = path.dirname(sourcePath);
        final name = path.basename(sourcePath);
        result = await Process.run(
          'zip',
          ['-r', path.basename(zipPath), name],
          workingDirectory: parent,
        );
      }

      if (result.exitCode != 0) {
        throw Exception('压缩失败: ${result.stderr}');
      }

      // 可选：删除原文件
      if (deleteOriginal) {
        if (isDir) {
          await sourceDir.delete(recursive: true);
        } else {
          await file.delete();
        }
      }

      final zipFile = File(zipPath);
      final zipSize = await zipFile.exists() ? await zipFile.length() : null;

      final log = OperationLog(
        id: _generateId(),
        operation: 'compress',
        originalPath: sourcePath,
        targetPath: zipPath,
        fileSize: zipSize,
        executedAt: DateTime.now(),
        status: OperationStatus.success,
        isReversible: !deleteOriginal, // 如果删除了原文件则不可逆
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    } catch (e) {
      final log = OperationLog(
        id: _generateId(),
        operation: 'compress',
        originalPath: sourcePath,
        fileSize: fileSize,
        executedAt: DateTime.now(),
        status: OperationStatus.failed,
        errorMessage: e.toString(),
        isDirectory: isDir,
      );
      _operationHistory.add(log);
      return log;
    }
  }

  /// 批量执行建议的操作
  Future<ExecutionResult> executeSuggestions(
    List<CleaningSuggestion> suggestions, {
    String? archiveDirectory,
    void Function(int current, int total, String message)? onProgress,
  }) async {
    final logs = <OperationLog>[];
    int successCount = 0;
    int failedCount = 0;
    int totalSizeFreed = 0;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < suggestions.length; i++) {
      final suggestion = suggestions[i];
      onProgress?.call(i + 1, suggestions.length, '处理: ${path.basename(suggestion.targetPath)}');

      OperationLog log;

      switch (suggestion.operation) {
        case 'delete':
          log = await deleteToRecycleBin(suggestion.targetPath);
          break;
        case 'archive':
          if (archiveDirectory == null) {
            log = OperationLog(
              id: _generateId(),
              operation: 'archive',
              originalPath: suggestion.targetPath,
              executedAt: DateTime.now(),
              status: OperationStatus.failed,
              errorMessage: '未指定归档目录',
            );
            _operationHistory.add(log);
          } else {
            log = await archiveTo(suggestion.targetPath, archiveDirectory);
          }
          break;
        case 'compress':
          log = await compressToZip(suggestion.targetPath, deleteOriginal: true);
          break;
        default:
          log = OperationLog(
            id: _generateId(),
            operation: suggestion.operation,
            originalPath: suggestion.targetPath,
            executedAt: DateTime.now(),
            status: OperationStatus.failed,
            errorMessage: '未知操作类型',
          );
          _operationHistory.add(log);
      }

      logs.add(log);

      if (log.status == OperationStatus.success) {
        successCount++;
        totalSizeFreed += log.fileSize ?? 0;
      } else {
        failedCount++;
      }
    }

    stopwatch.stop();

    return ExecutionResult(
      logs: logs,
      successCount: successCount,
      failedCount: failedCount,
      totalSizeFreed: totalSizeFreed,
      duration: stopwatch.elapsed,
    );
  }

  // === 私有方法 ===

  String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  /// 计算目录大小
  Future<int> _calculateDirectorySize(Directory dir) async {
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

  /// Windows 回收站删除
  Future<bool> _deleteToWindowsRecycleBin(String filePath) async {
    // 使用 Microsoft.VisualBasic.FileIO 的 FileSystem
    // 这是最可靠的移动到回收站的方法
    // 使用 -EncodedCommand 来支持中文路径
    try {
      // 先判断是文件还是目录
      final isDirectory = await Directory(filePath).exists();
      final isFile = await File(filePath).exists();
      
      if (!isDirectory && !isFile) {
        debugPrint('Path does not exist: $filePath');
        return false;
      }
      
      String command;
      if (isDirectory) {
        // 使用 DeleteDirectory 删除目录
        command = '''
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
  "$filePath",
  [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
  [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
)
''';
      } else {
        // 使用 DeleteFile 删除文件
        command = '''
Add-Type -AssemblyName Microsoft.VisualBasic
[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
  "$filePath",
  [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
  [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
)
''';
      }
      
      debugPrint('Deleting ${isDirectory ? "directory" : "file"}: $filePath');
      
      // 将命令转换为 UTF-16LE 编码，然后 Base64
      // Dart 字符串的 codeUnits 就是 UTF-16
      final utf16CodeUnits = command.codeUnits;
      final utf16Bytes = <int>[];
      for (var codeUnit in utf16CodeUnits) {
        // Little-endian: 低位在前
        utf16Bytes.add(codeUnit & 0xFF);
        utf16Bytes.add((codeUnit >> 8) & 0xFF);
      }
      final encoded = base64.encode(utf16Bytes);
      
      final result = await Process.run(
        'powershell',
        ['-EncodedCommand', encoded],
      );

      debugPrint('Delete result: exitCode=${result.exitCode}, stdout=${result.stdout}, stderr=${result.stderr}');
      
      // 验证文件是否真的被删除了
      final stillExists = isDirectory 
          ? await Directory(filePath).exists() 
          : await File(filePath).exists();
      
      if (!stillExists) {
        debugPrint('Successfully deleted to recycle bin: $filePath');
        return true;
      }
      
      debugPrint('Failed to delete, file still exists');
      return false;
    } catch (e) {
      debugPrint('Failed to delete to recycle bin: $e');
      return false;
    }
  }

  /// macOS 回收站移动
  Future<String> _moveToMacOSTrash(String filePath, bool isDir) async {
    final trashDir = Directory('${Platform.environment['HOME']}/.Trash');
    if (!await trashDir.exists()) {
      await trashDir.create();
    }

    final fileName = path.basename(filePath);
    var trashPath = path.join(trashDir.path, fileName);

    // 处理重名
    int counter = 1;
    while (await File(trashPath).exists() || await Directory(trashPath).exists()) {
      final ext = path.extension(fileName);
      final nameWithoutExt = path.basenameWithoutExtension(fileName);
      trashPath = path.join(trashDir.path, '${nameWithoutExt}_$counter$ext');
      counter++;
    }

    if (isDir) {
      await Directory(filePath).rename(trashPath);
    } else {
      await File(filePath).rename(trashPath);
    }

    return trashPath;
  }

  /// Linux 回收站移动（符合 FreeDesktop 标准）
  Future<String> _moveToLinuxTrash(String filePath, bool isDir) async {
    final home = Platform.environment['HOME'] ?? '';
    final trashDir = Directory('$home/.local/share/Trash/files');
    final trashInfoDir = Directory('$home/.local/share/Trash/info');

    if (!await trashDir.exists()) {
      await trashDir.create(recursive: true);
    }
    if (!await trashInfoDir.exists()) {
      await trashInfoDir.create(recursive: true);
    }

    final fileName = path.basename(filePath);
    var trashPath = path.join(trashDir.path, fileName);

    // 处理重名
    int counter = 1;
    while (await File(trashPath).exists() || await Directory(trashPath).exists()) {
      final ext = path.extension(fileName);
      final nameWithoutExt = path.basenameWithoutExtension(fileName);
      trashPath = path.join(trashDir.path, '${nameWithoutExt}_$counter$ext');
      counter++;
    }

    // 创建 .trashinfo 文件（用于恢复）
    final trashInfoFile = File(path.join(trashInfoDir.path, '${path.basename(trashPath)}.trashinfo'));
    final trashInfo = '''
[Trash Info]
Path=${Uri.encodeFull(filePath)}
DeletionDate=${DateTime.now().toIso8601String()}
''';
    await trashInfoFile.writeAsString(trashInfo);

    if (isDir) {
      await Directory(filePath).rename(trashPath);
    } else {
      await File(filePath).rename(trashPath);
    }

    return trashPath;
  }

  /// 复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(followLinks: false)) {
      final newPath = path.join(destination.path, path.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  /// 清空历史记录
  void clearHistory() {
    _operationHistory.clear();
  }
}
