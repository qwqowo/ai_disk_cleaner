/// 操作日志模型
class OperationLog {
  final String id;
  final String operation; // 'delete', 'move', 'compress'
  final String originalPath;
  final String? targetPath; // 回收站路径或归档路径
  final int? fileSize;
  final DateTime executedAt;
  final bool isReversible;
  final bool isDirectory;
  final String? errorMessage;
  final OperationStatus status;

  OperationLog({
    required this.id,
    required this.operation,
    required this.originalPath,
    this.targetPath,
    this.fileSize,
    required this.executedAt,
    this.isReversible = true,
    this.isDirectory = false,
    this.errorMessage,
    this.status = OperationStatus.pending,
  });

  OperationLog copyWith({
    String? id,
    String? operation,
    String? originalPath,
    String? targetPath,
    int? fileSize,
    DateTime? executedAt,
    bool? isReversible,
    bool? isDirectory,
    String? errorMessage,
    OperationStatus? status,
  }) {
    return OperationLog(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      originalPath: originalPath ?? this.originalPath,
      targetPath: targetPath ?? this.targetPath,
      fileSize: fileSize ?? this.fileSize,
      executedAt: executedAt ?? this.executedAt,
      isReversible: isReversible ?? this.isReversible,
      isDirectory: isDirectory ?? this.isDirectory,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation,
      'originalPath': originalPath,
      'targetPath': targetPath,
      'fileSize': fileSize,
      'executedAt': executedAt.toIso8601String(),
      'isReversible': isReversible,
      'isDirectory': isDirectory,
      'errorMessage': errorMessage,
      'status': status.name,
    };
  }

  factory OperationLog.fromJson(Map<String, dynamic> json) {
    return OperationLog(
      id: json['id'],
      operation: json['operation'],
      originalPath: json['originalPath'],
      targetPath: json['targetPath'],
      fileSize: json['fileSize'],
      executedAt: DateTime.parse(json['executedAt']),
      isReversible: json['isReversible'] ?? true,
      isDirectory: json['isDirectory'] ?? false,
      errorMessage: json['errorMessage'],
      status: OperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OperationStatus.pending,
      ),
    );
  }

  String get operationText {
    switch (operation) {
      case 'delete':
        return '删除';
      case 'move':
        return '移动';
      case 'compress':
        return '压缩';
      case 'archive':
        return '归档';
      default:
        return operation;
    }
  }

  String get statusText {
    switch (status) {
      case OperationStatus.pending:
        return '等待中';
      case OperationStatus.running:
        return '执行中';
      case OperationStatus.success:
        return '成功';
      case OperationStatus.failed:
        return '失败';
      case OperationStatus.reverted:
        return '已撤销';
    }
  }
}

/// 操作状态
enum OperationStatus {
  pending,  // 等待执行
  running,  // 执行中
  success,  // 成功
  failed,   // 失败
  reverted, // 已撤销
}

/// 批量操作执行结果
class ExecutionResult {
  final List<OperationLog> logs;
  final int successCount;
  final int failedCount;
  final int totalSizeFreed;
  final Duration duration;

  ExecutionResult({
    required this.logs,
    required this.successCount,
    required this.failedCount,
    required this.totalSizeFreed,
    required this.duration,
  });

  bool get hasFailures => failedCount > 0;
  bool get allSuccess => failedCount == 0 && successCount > 0;
  int get totalCount => successCount + failedCount;
}
