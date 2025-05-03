import 'package:flutter/material.dart';

/// 可调整大小的面板组件
class ResizablePanel extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final bool resizeFromRight;
  final Color? dividerColor;
  final double dividerWidth;
  final Function(double)? onWidthChanged;

  const ResizablePanel({
    Key? key,
    required this.child,
    this.initialWidth = 300,
    this.minWidth = 200,
    this.maxWidth = 500,
    this.resizeFromRight = false,
    this.dividerColor,
    this.dividerWidth = 4,
    this.onWidthChanged,
  }) : super(key: key);

  @override
  _ResizablePanelState createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  late double _width;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  void _updateWidth(double delta) {
    final newWidth = widget.resizeFromRight
        ? _width - delta
        : _width + delta;
    
    if (newWidth >= widget.minWidth && newWidth <= widget.maxWidth) {
      setState(() {
        _width = newWidth;
      });
      
      if (widget.onWidthChanged != null) {
        widget.onWidthChanged!(_width);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = widget.dividerColor ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800] 
            : Colors.grey[300]);
    
    return Row(
      children: widget.resizeFromRight
          ? [
              // 内容
              SizedBox(
                width: _width,
                child: widget.child,
              ),
              // 分隔线
              GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                onHorizontalDragUpdate: (details) => _updateWidth(details.delta.dx),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: widget.dividerWidth,
                    color: _isDragging ? Theme.of(context).primaryColor : dividerColor,
                    child: Center(
                      child: _isDragging
                          ? Container(
                              width: 2,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ]
          : [
              // 内容
              SizedBox(
                width: _width,
                child: widget.child,
              ),
              // 分隔线
              GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                onHorizontalDragUpdate: (details) => _updateWidth(details.delta.dx),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: Container(
                    width: widget.dividerWidth,
                    color: _isDragging ? Theme.of(context).primaryColor : dividerColor,
                    child: Center(
                      child: _isDragging
                          ? Container(
                              width: 2,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
    );
  }
}

/// 垂直可调整大小的面板组件
class VerticalResizablePanel extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final double minHeight;
  final double maxHeight;
  final bool resizeFromBottom;
  final Color? dividerColor;
  final double dividerHeight;
  final Function(double)? onHeightChanged;

  const VerticalResizablePanel({
    Key? key,
    required this.child,
    this.initialHeight = 300,
    this.minHeight = 100,
    this.maxHeight = 500,
    this.resizeFromBottom = true,
    this.dividerColor,
    this.dividerHeight = 4,
    this.onHeightChanged,
  }) : super(key: key);

  @override
  _VerticalResizablePanelState createState() => _VerticalResizablePanelState();
}

class _VerticalResizablePanelState extends State<VerticalResizablePanel> {
  late double _height;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
  }

  void _updateHeight(double delta) {
    final newHeight = widget.resizeFromBottom
        ? _height + delta
        : _height - delta;
    
    if (newHeight >= widget.minHeight && newHeight <= widget.maxHeight) {
      setState(() {
        _height = newHeight;
      });
      
      if (widget.onHeightChanged != null) {
        widget.onHeightChanged!(_height);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = widget.dividerColor ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800] 
            : Colors.grey[300]);
    
    return Column(
      children: widget.resizeFromBottom
          ? [
              // 内容
              SizedBox(
                height: _height,
                child: widget.child,
              ),
              // 分隔线
              GestureDetector(
                onVerticalDragStart: (_) => setState(() => _isDragging = true),
                onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                onVerticalDragUpdate: (details) => _updateHeight(details.delta.dy),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Container(
                    height: widget.dividerHeight,
                    color: _isDragging ? Theme.of(context).primaryColor : dividerColor,
                    child: Center(
                      child: _isDragging
                          ? Container(
                              height: 2,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ]
          : [
              // 分隔线
              GestureDetector(
                onVerticalDragStart: (_) => setState(() => _isDragging = true),
                onVerticalDragEnd: (_) => setState(() => _isDragging = false),
                onVerticalDragUpdate: (details) => _updateHeight(details.delta.dy),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Container(
                    height: widget.dividerHeight,
                    color: _isDragging ? Theme.of(context).primaryColor : dividerColor,
                    child: Center(
                      child: _isDragging
                          ? Container(
                              height: 2,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              // 内容
              SizedBox(
                height: _height,
                child: widget.child,
              ),
            ],
    );
  }
}
