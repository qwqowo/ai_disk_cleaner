import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/ai_provider.dart' as provider;
import '../services/ai_config.dart';
import '../services/archive_config.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _deepseekKeyController;
  late TextEditingController _openaiKeyController;
  late TextEditingController _deepseekUrlController;
  late TextEditingController _openaiUrlController;
  late TextEditingController _modelController;
  
  bool _obscureDeepseekKey = true;
  bool _obscureOpenaiKey = true;
  bool _isTesting = false;
  AIProvider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    final aiProvider = context.read<provider.AIProvider>();
    final config = aiProvider.config;
    
    _deepseekKeyController = TextEditingController(text: config.deepseekApiKey);
    _openaiKeyController = TextEditingController(text: config.openaiApiKey);
    _deepseekUrlController = TextEditingController(text: config.deepseekBaseUrl);
    _openaiUrlController = TextEditingController(text: config.openaiBaseUrl);
    _modelController = TextEditingController(text: config.model);
    _selectedProvider = config.provider;
  }

  @override
  void dispose() {
    _deepseekKeyController.dispose();
    _openaiKeyController.dispose();
    _deepseekUrlController.dispose();
    _openaiUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI 服务提供商选择
          _buildSection(
            title: 'AI 服务提供商',
            child: Column(
              children: [
                _buildProviderTile(
                  title: 'DeepSeek',
                  subtitle: '推荐，性价比高',
                  value: AIProvider.deepseek,
                ),
                _buildProviderTile(
                  title: 'OpenAI',
                  subtitle: 'GPT-4o，能力强大',
                  value: AIProvider.openai,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // DeepSeek 配置
          _buildSection(
            title: 'DeepSeek 配置',
            child: Column(
              children: [
                _buildTextField(
                  controller: _deepseekKeyController,
                  label: 'API Key',
                  hint: '输入 DeepSeek API Key',
                  obscure: _obscureDeepseekKey,
                  onToggleObscure: () => setState(() {
                    _obscureDeepseekKey = !_obscureDeepseekKey;
                  }),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _deepseekUrlController,
                  label: 'API Base URL',
                  hint: AIConfig.defaultDeepseekBaseUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // OpenAI 配置
          _buildSection(
            title: 'OpenAI 配置',
            child: Column(
              children: [
                _buildTextField(
                  controller: _openaiKeyController,
                  label: 'API Key',
                  hint: '输入 OpenAI API Key',
                  obscure: _obscureOpenaiKey,
                  onToggleObscure: () => setState(() {
                    _obscureOpenaiKey = !_obscureOpenaiKey;
                  }),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _openaiUrlController,
                  label: 'API Base URL',
                  hint: AIConfig.defaultOpenaiBaseUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 模型配置
          _buildSection(
            title: '模型配置',
            child: _buildTextField(
              controller: _modelController,
              label: '模型名称',
              hint: _selectedProvider == AIProvider.deepseek
                  ? AIConfig.defaultDeepseekModel
                  : AIConfig.defaultOpenaiModel,
            ),
          ),
          const SizedBox(height: 24),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi),
                  label: Text(_isTesting ? '测试中...' : '测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('保存设置'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 资源文件归档配置
          _buildArchiveSection(),
          const SizedBox(height: 32),

          // 清理原则配置
          _buildPrinciplesSection(),
        ],
      ),
    );
  }

  Widget _buildArchiveSection() {
    return Consumer<ArchiveConfig>(
      builder: (context, archiveConfig, child) {
        return _buildSection(
          title: '资源文件归档',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '将图片、视频、音频等资源文件转移到指定目录进行归档管理：',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              // 归档目录选择
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder,
                            color: archiveConfig.isConfigured 
                                ? Colors.amber 
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              archiveConfig.isConfigured
                                  ? archiveConfig.archiveBasePath
                                  : '未设置归档目录',
                              style: TextStyle(
                                color: archiveConfig.isConfigured
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
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _selectArchiveDirectory(archiveConfig),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('选择'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 组织选项
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('按文件类型分类'),
                subtitle: const Text('图片、视频、音频等分别放入不同文件夹'),
                value: archiveConfig.organizeByType,
                onChanged: (v) => archiveConfig.setOrganizeByType(v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('按日期分类'),
                subtitle: const Text('按年/月创建子文件夹'),
                value: archiveConfig.organizeByDate,
                onChanged: (v) => archiveConfig.setOrganizeByDate(v),
              ),
              
              const Divider(),
              const SizedBox(height: 8),
              
              // 文件类型开关
              const Text(
                '启用的文件类型：',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: archiveConfig.resourceTypes.map((type) {
                  return FilterChip(
                    label: Text(type.displayName),
                    selected: type.enabled,
                    onSelected: (selected) {
                      archiveConfig.toggleResourceType(type.name, selected);
                    },
                    avatar: Icon(
                      _getTypeIcon(type.name),
                      size: 18,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getTypeIcon(String typeName) {
    switch (typeName) {
      case 'images':
        return Icons.image;
      case 'videos':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'documents':
        return Icons.description;
      case 'archives':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _selectArchiveDirectory(ArchiveConfig config) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择归档目录',
    );
    
    if (result != null) {
      await config.setArchiveBasePath(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('归档目录已设置: $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTile({
    required String title,
    required String subtitle,
    required AIProvider value,
  }) {
    return RadioListTile<AIProvider>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: _selectedProvider,
      onChanged: (v) => setState(() => _selectedProvider = v),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }

  Widget _buildPrinciplesSection() {
    return Consumer<provider.AIProvider>(
      builder: (context, aiProvider, child) {
        final principles = aiProvider.principles.principles;
        
        return _buildSection(
          title: '清理原则',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 会根据以下原则来判断哪些文件可以清理：',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ...principles.asMap().entries.map((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removePrinciple(entry.key),
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addPrinciple,
                icon: const Icon(Icons.add),
                label: const Text('添加原则'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    
    // 先保存当前配置
    await _saveSettings(showSnackbar: false);
    
    final aiProvider = context.read<provider.AIProvider>();
    final success = await aiProvider.testConnection();
    
    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'API 连接成功！' : 'API 连接失败，请检查配置'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSettings({bool showSnackbar = true}) async {
    final aiProvider = context.read<provider.AIProvider>();
    
    await aiProvider.config.update(
      provider: _selectedProvider,
      deepseekApiKey: _deepseekKeyController.text,
      openaiApiKey: _openaiKeyController.text,
      deepseekBaseUrl: _deepseekUrlController.text.isEmpty
          ? AIConfig.defaultDeepseekBaseUrl
          : _deepseekUrlController.text,
      openaiBaseUrl: _openaiUrlController.text.isEmpty
          ? AIConfig.defaultOpenaiBaseUrl
          : _openaiUrlController.text,
      model: _modelController.text.isEmpty
          ? (_selectedProvider == AIProvider.deepseek
              ? AIConfig.defaultDeepseekModel
              : AIConfig.defaultOpenaiModel)
          : _modelController.text,
    );

    if (showSnackbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addPrinciple() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加清理原则'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入新的清理原则...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await context.read<provider.AIProvider>().principles.add(result);
    }
  }

  Future<void> _removePrinciple(int index) async {
    await context.read<provider.AIProvider>().principles.remove(index);
  }
}
