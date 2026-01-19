import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/file_item.dart';
import '../models/cleaning_suggestion.dart';
import 'ai_config.dart';
import 'summary_generator.dart';

/// AI 分析服务
class AIAnalysisService {
  final AIConfig config;
  final CleaningPrinciples principles;

  AIAnalysisService({
    required this.config,
    required this.principles,
  });

  /// 系统提示词
  String get _systemPrompt => '''
你是一个专业的磁盘清理专家。你拥有对文件系统的深入分析能力，并且可以使用特定的工具(Tools)来处理文件。

## 你的职责
分析用户提供的磁盘摘要信息，根据用户的清理原则，生成一份清理建议列表。

## 约束条件
1. 你的回答必须是严格的 JSON 格式，不要包含任何其他文本。
2. 对于系统文件、应用核心文件（如 Windows、System32、Program Files），必须保持极其保守的态度，绝不建议删除。
3. 即使符合清理原则，如果是用户生成的文档/图片/视频，优先建议"归档(archive)"而非"删除(delete)"。
4. 每个建议必须包含清晰的理由(reason)和风险等级(risk)。
5. 风险等级分为: low（低风险，可放心删除）、medium（中风险，建议检查后删除）、high（高风险，需谨慎确认）。

## 可用工具 (仅提议，不执行)
- delete: 移入回收站
- archive: 移动到备份目录
- compress: 压缩为 zip 文件

## 用户清理原则
${principles.toPromptText()}

## 输出格式
请严格按照以下 JSON 格式输出：
```json
{
  "summary": "整体分析总结",
  "totalSavings": 预估可释放空间(字节数),
  "suggestions": [
    {
      "path": "文件或文件夹路径",
      "action": "delete|archive|compress",
      "reason": "建议理由",
      "risk": "low|medium|high",
      "size": 预估大小(字节数),
      "category": "cache|temp|log|build|other"
    }
  ]
}
```
''';

  /// 分析磁盘摘要并返回清理建议
  Future<AnalysisResult> analyze(ScanSummary summary) async {
    if (!config.isConfigured) {
      throw Exception('AI API 未配置，请先在设置中配置 API Key');
    }

    // 生成摘要文本
    final summaryText = SummaryGenerator.generateSummary(summary);
    
    // 构建请求
    final requestBody = {
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': '请分析以下磁盘扫描结果，并给出清理建议：\n\n$summaryText'},
      ],
      'temperature': 0.3, // 降低随机性，使输出更稳定
      'max_tokens': 4096,
    };

    debugPrint('Sending request to AI API: ${config.chatEndpoint}');

    try {
      final response = await http.post(
        Uri.parse(config.chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        final errorBody = response.body;
        debugPrint('AI API error: ${response.statusCode} - $errorBody');
        throw Exception('AI API 请求失败: ${response.statusCode}\n$errorBody');
      }

      final responseJson = jsonDecode(response.body);
      final content = responseJson['choices']?[0]?['message']?['content'] ?? '';
      
      debugPrint('AI response: $content');

      // 解析 AI 返回的 JSON
      final result = _parseResponse(content);
      return result;
    } catch (e) {
      debugPrint('AI analysis error: $e');
      rethrow;
    }
  }

  /// 解析 AI 响应
  AnalysisResult _parseResponse(String content) {
    // 尝试提取 JSON 内容
    String jsonStr = content;
    
    // 如果包含 markdown 代码块，提取其中的 JSON
    final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(content);
    if (jsonMatch != null) {
      jsonStr = jsonMatch.group(1) ?? content;
    }

    // 尝试找到 JSON 对象的开始和结束
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AnalysisResult.fromJson(json, rawResponse: content);
    } catch (e) {
      debugPrint('Failed to parse AI response as JSON: $e');
      debugPrint('Raw content: $content');
      
      // 如果解析失败，返回空结果
      return AnalysisResult(
        suggestions: [],
        summary: '无法解析 AI 响应，请重试。原始响应：$content',
        rawResponse: content,
      );
    }
  }

  /// 测试 API 连接
  Future<bool> testConnection() async {
    if (!config.isConfigured) {
      return false;
    }

    try {
      final requestBody = {
        'model': config.model,
        'messages': [
          {'role': 'user', 'content': '你好，请回复"连接成功"'},
        ],
        'max_tokens': 50,
      };

      final response = await http.post(
        Uri.parse(config.chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API connection test failed: $e');
      return false;
    }
  }

  /// 分析单个文件或文件夹
  Future<Map<String, dynamic>> analyzeItem(FileItem item) async {
    if (!config.isConfigured) {
      throw Exception('AI API 未配置，请先在设置中配置 API Key');
    }

    final itemType = item.isDirectory ? '文件夹' : '文件';
    final prompt = '''
请分析以下$itemType，告诉我：
1. 这个$itemType存储的是什么内容
2. 是否可以安全删除
3. 删除的风险等级

## $itemType信息
- 路径: ${item.path}
- 名称: ${item.name}
- 大小: ${(item.size / 1024 / 1024).toStringAsFixed(2)} MB
- 类型: $itemType
${item.isDirectory ? '- 文件数量: ${item.fileCount}' : '- 扩展名: .${item.extension}'}
${item.modifiedTime != null ? '- 最后修改时间: ${item.modifiedTime}' : ''}

## 用户清理原则
${principles.toPromptText()}

## 输出格式
请严格按照以下 JSON 格式输出，不要包含任何其他文本：
```json
{
  "description": "这个$itemType存储的内容描述",
  "canDelete": true或false,
  "riskLevel": "low|medium|high",
  "reason": "是否可以删除的详细原因",
  "suggestion": "建议的操作（如删除、归档、压缩、保留等）"
}
```
''';

    try {
      final requestBody = {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': '你是一个专业的磁盘清理专家，擅长分析文件和文件夹的用途，判断其是否可以安全删除。你的回答必须是严格的 JSON 格式。'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
        'max_tokens': 1024,
      };

      final response = await http.post(
        Uri.parse(config.chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('AI API 请求失败: ${response.statusCode}');
      }

      final responseJson = jsonDecode(response.body);
      final content = responseJson['choices']?[0]?['message']?['content'] ?? '';

      // 解析 JSON
      String jsonStr = content;
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(content);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1) ?? content;
      }

      final startIndex = jsonStr.indexOf('{');
      final endIndex = jsonStr.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }

      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AI item analysis error: $e');
      rethrow;
    }
  }

  /// 分析大文件夹的内容分组
  /// 识别文件夹中包含的不同软件/项目的数据
  Future<List<Map<String, dynamic>>> analyzeFolderGroups({
    required String folderPath,
    required int totalSize,
    required String subfoldersSummary,
  }) async {
    if (!config.isConfigured) {
      throw Exception('AI API 未配置，请先在设置中配置 API Key');
    }

    final sizeMB = (totalSize / 1024 / 1024).toStringAsFixed(2);
    final sizeGB = (totalSize / 1024 / 1024 / 1024).toStringAsFixed(2);
    
    final prompt = '''
请分析以下大文件夹的内容，识别其中包含的不同"内容组"。

一个"内容组"可能是：
- 某个软件/游戏的数据（如 Steam 游戏、Epic 游戏）
- 某个开发项目（如 node_modules、.git）
- 某类文件的集合（如视频文件、下载文件）
- 缓存或临时文件

## 文件夹信息
- 路径: $folderPath
- 总大小: $sizeGB GB ($sizeMB MB)

## 子文件夹列表（按大小排序）
$subfoldersSummary

## 分析要求
1. 根据文件夹名称特征，识别出不同的内容分组
2. 同一软件/项目的多个相关文件夹应归为一组
3. 判断每个分组是否可以安全删除
4. 给出风险等级

## 输出格式
请严格按照以下 JSON 格式输出，不要包含任何其他文本：
```json
{
  "groups": [
    {
      "groupName": "分组名称（如：Steam 游戏、Epic Games 数据）",
      "description": "这个分组包含什么内容的描述",
      "folders": ["匹配的文件夹名称关键词列表"],
      "canDelete": true或false,
      "riskLevel": "low|medium|high"
    }
  ]
}
```

注意：folders 数组中填写的是能够匹配到对应子文件夹的关键词，可以是部分名称。
''';

    try {
      final requestBody = {
        'model': config.model,
        'messages': [
          {
            'role': 'system', 
            'content': '你是一个专业的磁盘分析专家，擅长识别文件夹中存储的不同类型内容，并将它们进行智能分组。你的回答必须是严格的 JSON 格式。'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.3,
        'max_tokens': 2048,
      };

      final response = await http.post(
        Uri.parse(config.chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw Exception('AI API 请求失败: ${response.statusCode}');
      }

      final responseJson = jsonDecode(response.body);
      final content = responseJson['choices']?[0]?['message']?['content'] ?? '';

      debugPrint('AI folder groups response: $content');

      // 解析 JSON
      String jsonStr = content;
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(content);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1) ?? content;
      }

      final startIndex = jsonStr.indexOf('{');
      final endIndex = jsonStr.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonStr = jsonStr.substring(startIndex, endIndex + 1);
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final groups = (json['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      
      return groups;
    } catch (e) {
      debugPrint('AI folder groups analysis error: $e');
      rethrow;
    }
  }
}
