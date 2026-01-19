import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/file_item.dart';
import '../utils/format_utils.dart';

/// Treemap 可视化组件 - 类似 SpaceSniffer 的矩形树图
class TreemapChart extends StatefulWidget {
  final FileItem rootItem;
  final double width;
  final double height;
  final Function(FileItem)? onItemTap;
  final Function(FileItem)? onItemDoubleTap;

  const TreemapChart({
    super.key,
    required this.rootItem,
    required this.width,
    required this.height,
    this.onItemTap,
    this.onItemDoubleTap,
  });

  @override
  State<TreemapChart> createState() => _TreemapChartState();
}

class _TreemapChartState extends State<TreemapChart> {
  FileItem? _currentRoot;
  final List<FileItem> _navigationStack = [];
  FileItem? _hoveredItem;

  @override
  void initState() {
    super.initState();
    _currentRoot = widget.rootItem;
  }

  @override
  void didUpdateWidget(TreemapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootItem != widget.rootItem) {
      _currentRoot = widget.rootItem;
      _navigationStack.clear();
    }
  }

  void _navigateInto(FileItem item) {
    if (item.isDirectory && item.children.isNotEmpty) {
      setState(() {
        _navigationStack.add(_currentRoot!);
        _currentRoot = item;
      });
    }
  }

  void _navigateBack() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _currentRoot = _navigationStack.removeLast();
      });
    }
  }

  void _navigateToRoot() {
    setState(() {
      _currentRoot = widget.rootItem;
      _navigationStack.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // 导航栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              // 返回按钮
              if (_navigationStack.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: _navigateBack,
                  tooltip: '返回上一级',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
              ],
              // 根目录按钮
              if (_navigationStack.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.home, size: 20),
                  onPressed: _navigateToRoot,
                  tooltip: '返回根目录',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              // 路径面包屑
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._navigationStack.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _currentRoot = item;
                                  _navigationStack.removeRange(index, _navigationStack.length);
                                });
                              },
                              child: Text(
                                item.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.chevron_right, size: 16),
                            ),
                          ],
                        );
                      }),
                      Text(
                        _currentRoot?.name ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 当前目录大小
              Text(
                FormatUtils.formatSize(_currentRoot?.size ?? 0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        // Treemap 区域
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            child: Container(
              color: theme.colorScheme.surface,
              child: _currentRoot != null && _currentRoot!.children.isNotEmpty
                  ? _buildTreemap(
                      _currentRoot!.children,
                      Rect.fromLTWH(0, 0, widget.width, widget.height - 56),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '此文件夹为空或只包含文件',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreemap(List<FileItem> items, Rect bounds) {
    if (items.isEmpty || bounds.width < 1 || bounds.height < 1) {
      return const SizedBox.shrink();
    }

    // 过滤掉大小为 0 的项目
    final validItems = items.where((item) => item.size > 0).toList();
    if (validItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算总大小
    final totalSize = validItems.fold<int>(0, (sum, item) => sum + item.size);
    if (totalSize == 0) {
      return const SizedBox.shrink();
    }

    // 使用 Squarified Treemap 算法布局
    final rects = _squarify(validItems, bounds, totalSize);

    return Stack(
      children: rects.map((itemRect) {
        final item = itemRect.item;
        final rect = itemRect.rect;
        
        // 计算颜色
        final color = _getItemColor(item);
        final isHovered = _hoveredItem == item;
        
        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredItem = item),
            onExit: (_) => setState(() => _hoveredItem = null),
            child: GestureDetector(
              onTap: () {
                widget.onItemTap?.call(item);
              },
              onDoubleTap: () {
                if (item.isDirectory) {
                  _navigateInto(item);
                }
                widget.onItemDoubleTap?.call(item);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isHovered ? color.withOpacity(0.9) : color,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: isHovered 
                        ? Colors.white 
                        : color.withOpacity(0.3),
                    width: isHovered ? 2 : 1,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: _buildItemContent(item, rect, isHovered),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemContent(FileItem item, Rect rect, bool isHovered) {
    // 根据矩形大小决定显示内容
    final minWidth = rect.width - 4;
    final minHeight = rect.height - 4;
    
    if (minWidth < 30 || minHeight < 20) {
      // 太小，不显示任何文字
      return Tooltip(
        message: '${item.name}\n${FormatUtils.formatSize(item.size)}',
        child: const SizedBox.expand(),
      );
    }

    final showSize = minHeight > 35;
    final showIcon = minWidth > 50 && minHeight > 50;
    
    final tooltipMsg = '${item.name}\n${FormatUtils.formatSize(item.size)}${item.isDirectory ? "\n双击进入文件夹" : ""}';
    
    return Tooltip(
      message: tooltipMsg,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showIcon)
                  Icon(
                    item.isDirectory ? Icons.folder : _getFileIcon(item),
                    size: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                if (showIcon) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: minWidth < 80 ? 10 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showSize) ...[
              const SizedBox(height: 2),
              Text(
                FormatUtils.formatSize(item.size),
                style: TextStyle(
                  fontSize: minWidth < 80 ? 9 : 10,
                  color: Colors.white.withOpacity(0.85),
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 获取文件图标
  IconData _getFileIcon(FileItem item) {
    final ext = item.extension.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'exe':
      case 'msi':
        return Icons.apps;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// 获取项目颜色
  Color _getItemColor(FileItem item) {
    if (item.isDirectory) {
      // 文件夹使用橙色系
      return Colors.orange.shade700;
    }
    
    // 根据文件扩展名选择颜色
    final ext = item.extension.toLowerCase();
    switch (ext) {
      // 图片 - 绿色
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return Colors.green.shade600;
      // 视频 - 紫色
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
      case 'flv':
        return Colors.purple.shade600;
      // 音频 - 粉色
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return Colors.pink.shade600;
      // 文档 - 蓝色
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
      case 'txt':
        return Colors.blue.shade600;
      // 压缩文件 - 棕色
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Colors.brown.shade600;
      // 可执行文件 - 红色
      case 'exe':
      case 'msi':
      case 'dll':
        return Colors.red.shade600;
      // 代码文件 - 青色
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'h':
      case 'swift':
      case 'kt':
        return Colors.cyan.shade600;
      // 系统/临时文件 - 灰色
      case 'tmp':
      case 'temp':
      case 'log':
      case 'bak':
        return Colors.grey.shade600;
      // 其他 - 蓝灰色
      default:
        return Colors.blueGrey.shade600;
    }
  }

  /// Squarified Treemap 算法
  List<_ItemRect> _squarify(List<FileItem> items, Rect bounds, int totalSize) {
    final result = <_ItemRect>[];
    
    if (items.isEmpty || totalSize == 0) return result;
    
    // 按大小降序排序
    final sortedItems = List<FileItem>.from(items)
      ..sort((a, b) => b.size.compareTo(a.size));
    
    _squarifyHelper(sortedItems, bounds, totalSize, result);
    
    return result;
  }

  void _squarifyHelper(
    List<FileItem> items,
    Rect bounds,
    int totalSize,
    List<_ItemRect> result,
  ) {
    if (items.isEmpty || bounds.width < 1 || bounds.height < 1) return;
    
    if (items.length == 1) {
      result.add(_ItemRect(items[0], bounds));
      return;
    }
    
    // 确定布局方向（短边优先）
    final isHorizontal = bounds.width >= bounds.height;
    final sideLength = isHorizontal ? bounds.height : bounds.width;
    
    // 找到最佳行
    final row = <FileItem>[];
    var rowSize = 0;
    var bestAspectRatio = double.infinity;
    var i = 0;
    
    for (; i < items.length; i++) {
      final item = items[i];
      final newRowSize = rowSize + item.size;
      row.add(item);
      
      // 计算当前行的最差纵横比
      final rowArea = bounds.width * bounds.height * newRowSize / totalSize;
      final rowLength = rowArea / sideLength;
      
      var worstAspectRatio = 0.0;
      for (final rowItem in row) {
        final itemArea = bounds.width * bounds.height * rowItem.size / totalSize;
        final itemLength = itemArea / rowLength;
        final aspectRatio = math.max(rowLength / itemLength, itemLength / rowLength);
        worstAspectRatio = math.max(worstAspectRatio, aspectRatio);
      }
      
      if (worstAspectRatio > bestAspectRatio && row.length > 1) {
        // 移除最后一个项目，使用之前的行
        row.removeLast();
        break;
      }
      
      bestAspectRatio = worstAspectRatio;
      rowSize = newRowSize;
    }
    
    // 布局当前行
    final rowArea = bounds.width * bounds.height * rowSize / totalSize;
    final rowLength = rowArea / sideLength;
    
    var offset = 0.0;
    for (final rowItem in row) {
      final itemArea = bounds.width * bounds.height * rowItem.size / totalSize;
      final itemLength = itemArea / rowLength;
      
      Rect itemRect;
      if (isHorizontal) {
        itemRect = Rect.fromLTWH(
          bounds.left,
          bounds.top + offset,
          rowLength,
          itemLength,
        );
      } else {
        itemRect = Rect.fromLTWH(
          bounds.left + offset,
          bounds.top,
          itemLength,
          rowLength,
        );
      }
      
      result.add(_ItemRect(rowItem, itemRect));
      offset += itemLength;
    }
    
    // 递归处理剩余项目
    final remainingItems = items.sublist(row.length);
    if (remainingItems.isNotEmpty) {
      final remainingSize = totalSize - rowSize;
      Rect remainingBounds;
      
      if (isHorizontal) {
        remainingBounds = Rect.fromLTWH(
          bounds.left + rowLength,
          bounds.top,
          bounds.width - rowLength,
          bounds.height,
        );
      } else {
        remainingBounds = Rect.fromLTWH(
          bounds.left,
          bounds.top + rowLength,
          bounds.width,
          bounds.height - rowLength,
        );
      }
      
      _squarifyHelper(remainingItems, remainingBounds, remainingSize, result);
    }
  }
}

/// 项目和对应矩形
class _ItemRect {
  final FileItem item;
  final Rect rect;
  
  _ItemRect(this.item, this.rect);
}
