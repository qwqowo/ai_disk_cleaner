import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 资源文件类型定义
class ResourceFileType {
  final String name;
  final String displayName;
  final List<String> extensions;
  final String defaultSubfolder;
  bool enabled;

  ResourceFileType({
    required this.name,
    required this.displayName,
    required this.extensions,
    required this.defaultSubfolder,
    this.enabled = true,
  });

  /// 检查文件是否属于此类型
  bool matches(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return extensions.contains(ext);
  }
}

/// 归档配置管理
class ArchiveConfig extends ChangeNotifier {
  static const String _keyArchiveBasePath = 'archive_base_path';
  static const String _keyEnabledTypes = 'archive_enabled_types';
  static const String _keyOrganizeByDate = 'archive_organize_by_date';
  static const String _keyOrganizeByType = 'archive_organize_by_type';

  String _archiveBasePath = '';
  bool _organizeByDate = true;
  bool _organizeByType = true;

  /// 支持的资源文件类型
  final List<ResourceFileType> resourceTypes = [
    ResourceFileType(
      name: 'images',
      displayName: '图片',
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff', 'raw', 'heic'],
      defaultSubfolder: '图片',
    ),
    ResourceFileType(
      name: 'videos',
      displayName: '视频',
      extensions: ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpeg', 'mpg', '3gp'],
      defaultSubfolder: '视频',
    ),
    ResourceFileType(
      name: 'audio',
      displayName: '音频',
      extensions: ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'ape', 'alac'],
      defaultSubfolder: '音频',
    ),
    ResourceFileType(
      name: 'documents',
      displayName: '文档',
      extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt'],
      defaultSubfolder: '文档',
    ),
    ResourceFileType(
      name: 'archives',
      displayName: '压缩包',
      extensions: ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'],
      defaultSubfolder: '压缩包',
    ),
  ];

  // Getters
  String get archiveBasePath => _archiveBasePath;
  bool get isConfigured => _archiveBasePath.isNotEmpty;
  bool get organizeByDate => _organizeByDate;
  bool get organizeByType => _organizeByType;

  /// 获取启用的文件类型
  List<ResourceFileType> get enabledTypes => 
      resourceTypes.where((t) => t.enabled).toList();

  /// 获取文件应该归档到的子文件夹
  String? getSubfolderForFile(String filePath) {
    for (final type in enabledTypes) {
      if (type.matches(filePath)) {
        return type.defaultSubfolder;
      }
    }
    return null;
  }

  /// 检查文件是否为可归档的资源文件
  bool isResourceFile(String filePath) {
    for (final type in enabledTypes) {
      if (type.matches(filePath)) {
        return true;
      }
    }
    return false;
  }

  /// 从本地存储加载配置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _archiveBasePath = prefs.getString(_keyArchiveBasePath) ?? '';
      _organizeByDate = prefs.getBool(_keyOrganizeByDate) ?? true;
      _organizeByType = prefs.getBool(_keyOrganizeByType) ?? true;

      // 加载启用的类型
      final enabledTypesStr = prefs.getStringList(_keyEnabledTypes);
      if (enabledTypesStr != null) {
        for (final type in resourceTypes) {
          type.enabled = enabledTypesStr.contains(type.name);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load archive config: $e');
    }
  }

  /// 保存配置到本地存储
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyArchiveBasePath, _archiveBasePath);
      await prefs.setBool(_keyOrganizeByDate, _organizeByDate);
      await prefs.setBool(_keyOrganizeByType, _organizeByType);
      await prefs.setStringList(
        _keyEnabledTypes,
        resourceTypes.where((t) => t.enabled).map((t) => t.name).toList(),
      );
    } catch (e) {
      debugPrint('Failed to save archive config: $e');
    }
  }

  /// 更新归档基础路径
  Future<void> setArchiveBasePath(String path) async {
    _archiveBasePath = path;
    await save();
    notifyListeners();
  }

  /// 更新按日期组织选项
  Future<void> setOrganizeByDate(bool value) async {
    _organizeByDate = value;
    await save();
    notifyListeners();
  }

  /// 更新按类型组织选项
  Future<void> setOrganizeByType(bool value) async {
    _organizeByType = value;
    await save();
    notifyListeners();
  }

  /// 切换文件类型启用状态
  Future<void> toggleResourceType(String typeName, bool enabled) async {
    final type = resourceTypes.firstWhere(
      (t) => t.name == typeName,
      orElse: () => throw ArgumentError('Unknown type: $typeName'),
    );
    type.enabled = enabled;
    await save();
    notifyListeners();
  }
}
