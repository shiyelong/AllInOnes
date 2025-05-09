import 'package:flutter/material.dart';
import 'package:frontend/common/network_monitor.dart';

/// 网络状态指示器
/// 用于在UI中显示当前网络状态
class NetworkStatusIndicator extends StatefulWidget {
  final bool showDetails; // 是否显示详细信息
  final bool showQuality; // 是否显示网络质量
  final bool showType; // 是否显示网络类型
  final bool showIcon; // 是否显示图标
  final bool showText; // 是否显示文本
  final bool autoHide; // 是否在网络正常时自动隐藏
  final double iconSize; // 图标大小
  final TextStyle? textStyle; // 文本样式
  final EdgeInsetsGeometry? padding; // 内边距
  final VoidCallback? onTap; // 点击回调

  const NetworkStatusIndicator({
    Key? key,
    this.showDetails = false,
    this.showQuality = true,
    this.showType = true,
    this.showIcon = true,
    this.showText = true,
    this.autoHide = true,
    this.iconSize = 16.0,
    this.textStyle,
    this.padding,
    this.onTap,
  }) : super(key: key);

  @override
  _NetworkStatusIndicatorState createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  bool _isConnected = true;
  double _networkQuality = 1.0;
  String _connectionType = 'WiFi';

  @override
  void initState() {
    super.initState();
    _updateNetworkStatus(NetworkMonitor().isConnected, NetworkMonitor().networkQuality);
    NetworkMonitor().addListener(_updateNetworkStatus);
  }

  @override
  void dispose() {
    NetworkMonitor().removeListener(_updateNetworkStatus);
    super.dispose();
  }

  void _updateNetworkStatus(bool isConnected, double quality) {
    setState(() {
      _isConnected = isConnected;
      _networkQuality = quality;
      _connectionType = NetworkMonitor().connectionType;
    });
  }

  // 获取网络质量描述
  String _getQualityDescription() {
    if (!_isConnected) return '无连接';
    if (_networkQuality >= 0.8) return '极佳';
    if (_networkQuality >= 0.6) return '良好';
    if (_networkQuality >= 0.4) return '一般';
    if (_networkQuality >= 0.2) return '较差';
    return '很差';
  }

  // 获取网络状态图标
  IconData _getNetworkIcon() {
    if (!_isConnected) return Icons.signal_wifi_off;

    if (_connectionType == 'WiFi') {
      if (_networkQuality >= 0.8) return Icons.wifi;
      if (_networkQuality >= 0.6) return Icons.wifi;
      if (_networkQuality >= 0.4) return Icons.wifi;
      if (_networkQuality >= 0.2) return Icons.wifi;
      return Icons.wifi_off;
    } else if (_connectionType == '移动数据') {
      if (_networkQuality >= 0.8) return Icons.signal_cellular_alt;
      if (_networkQuality >= 0.6) return Icons.signal_cellular_alt;
      if (_networkQuality >= 0.4) return Icons.signal_cellular_alt;
      if (_networkQuality >= 0.2) return Icons.signal_cellular_alt;
      return Icons.signal_cellular_off;
    } else if (_connectionType == '以太网') {
      return Icons.lan;
    } else {
      return Icons.network_check;
    }
  }

  // 获取网络状态颜色
  Color _getNetworkColor() {
    if (!_isConnected) return Colors.red;
    if (_networkQuality >= 0.8) return Colors.green;
    if (_networkQuality >= 0.6) return Colors.green.shade300;
    if (_networkQuality >= 0.4) return Colors.orange;
    if (_networkQuality >= 0.2) return Colors.orange.shade700;
    return Colors.red;
  }

  // 获取网络状态文本
  String _getNetworkText() {
    if (!_isConnected) return '网络已断开';

    String text = '';

    if (widget.showType) {
      text += _connectionType;
    }

    if (widget.showQuality) {
      if (text.isNotEmpty) text += ' ';
      text += _getQualityDescription();
    }

    if (text.isEmpty) {
      text = '已连接';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    // 如果设置了自动隐藏且网络正常，则不显示
    if (widget.autoHide && _isConnected && _networkQuality >= 0.8) {
      return SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          // 默认行为：强制检查网络状态
          NetworkMonitor().forceCheckNetwork();
        }
      },
      child: Container(
        padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getNetworkColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _getNetworkColor().withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcon)
              Icon(
                _getNetworkIcon(),
                size: widget.iconSize,
                color: _getNetworkColor(),
              ),
            if (widget.showIcon && widget.showText) SizedBox(width: 4),
            if (widget.showText)
              Text(
                _getNetworkText(),
                style: widget.textStyle ??
                    TextStyle(
                      fontSize: 12,
                      color: _getNetworkColor(),
                    ),
              ),
            if (widget.showDetails) ...[
              SizedBox(width: 4),
              Text(
                '(${(_networkQuality * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 10,
                  color: _getNetworkColor(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
