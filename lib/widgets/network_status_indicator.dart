import 'package:flutter/material.dart';
import '../common/theme_manager.dart';

/// 网络状态指示器
/// 显示网络连接状态和质量
class NetworkStatusIndicator extends StatelessWidget {
  final bool connected;
  final double quality;

  const NetworkStatusIndicator({
    Key? key,
    required this.connected,
    required this.quality,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    if (!connected) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        color: Colors.red,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              '网络连接已断开',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (quality < 0.3) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 2, horizontal: 16),
        color: Colors.orange,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getNetworkIcon(),
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              '网络信号较弱',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox.shrink();
  }

  // 获取网络图标
  IconData _getNetworkIcon() {
    // WiFi图标
    if (_isWifi()) {
      if (quality >= 0.2) return Icons.wifi;
      return Icons.wifi_off;
    }

    // 移动网络图标
    if (quality >= 0.2) return Icons.signal_cellular_alt;
    return Icons.signal_cellular_off;
  }

  // 判断是否为WiFi连接
  bool _isWifi() {
    // 这里可以根据实际情况判断是WiFi还是移动网络
    // 简单起见，暂时返回true
    return true;
  }
}
