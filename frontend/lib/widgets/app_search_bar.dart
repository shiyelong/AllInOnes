import 'package:flutter/material.dart';
import 'package:frontend/common/search_service.dart';
import 'package:frontend/common/theme_manager.dart';

/// 应用通用搜索框组件
class AppSearchBar extends StatefulWidget {
  /// 搜索类型
  final SearchType searchType;

  /// 搜索回调
  final Function(String keyword)? onSearch;

  /// 搜索框宽度
  final double? width;

  /// 搜索框高度
  final double height;

  /// 搜索框边距
  final EdgeInsetsGeometry? margin;

  /// 搜索框内边距
  final EdgeInsetsGeometry? padding;

  /// 搜索框提示文本
  final String? hintText;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 是否显示搜索按钮
  final bool showSearchButton;

  /// 搜索框控制器
  final TextEditingController? controller;

  /// 构造函数
  const AppSearchBar({
    Key? key,
    required this.searchType,
    this.onSearch,
    this.width,
    this.height = 36,
    this.margin,
    this.padding,
    this.hintText,
    this.autofocus = false,
    this.showSearchButton = false,
    this.controller,
  }) : super(key: key);

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSearch() {
    final keyword = _controller.text.trim();
    if (keyword.isNotEmpty && widget.onSearch != null) {
      widget.onSearch!(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    final isDark = theme.isDark;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: Row(
        children: [
          // 搜索图标
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.search,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 18,
            ),
          ),
          // 搜索输入框
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: widget.hintText ?? SearchService.getSearchHint(widget.searchType),
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
              ),
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _handleSearch(),
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
              },
            ),
          ),
          // 清除按钮
          if (_isSearching)
            IconButton(
              icon: Icon(
                Icons.clear,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 16,
              ),
              constraints: BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                _controller.clear();
                setState(() {
                  _isSearching = false;
                });
              },
            ),
          // 搜索按钮
          if (widget.showSearchButton)
            TextButton(
              onPressed: _handleSearch,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size(40, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '搜索',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
