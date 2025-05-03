import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math' as math;

class EnhancedQrScanPage extends StatefulWidget {
  final void Function(String code, Rect? position)? onScan;
  final String title;
  final String description;
  
  const EnhancedQrScanPage({
    Key? key,
    this.onScan,
    this.title = '扫一扫',
    this.description = '将二维码放入框内，即可自动扫描',
  }) : super(key: key);
  
  @override
  _EnhancedQrScanPageState createState() => _EnhancedQrScanPageState();
}

class _EnhancedQrScanPageState extends State<EnhancedQrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  Rect? _lastPosition;
  String? _lastCode;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // 闪光灯按钮
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
                _controller.toggleTorch();
              });
            },
          ),
          // 切换摄像头按钮
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
                _controller.switchCamera();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 扫描器
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final barcode = barcodes.first;
                final code = barcode.rawValue!;
                
                // 获取二维码位置
                Rect? position;
                if (barcode.corners != null && barcode.corners!.length >= 4) {
                  final corners = barcode.corners!;
                  
                  // 计算边界框
                  double minX = double.infinity;
                  double minY = double.infinity;
                  double maxX = 0;
                  double maxY = 0;
                  
                  for (final corner in corners) {
                    minX = math.min(minX, corner.x);
                    minY = math.min(minY, corner.y);
                    maxX = math.max(maxX, corner.x);
                    maxY = math.max(maxY, corner.y);
                  }
                  
                  position = Rect.fromLTRB(minX, minY, maxX, maxY);
                }
                
                // 避免重复扫描
                if (_lastCode != code) {
                  _lastCode = code;
                  _lastPosition = position;
                  
                  // 回调
                  if (widget.onScan != null) {
                    widget.onScan!(code, position);
                  }
                }
              }
            },
          ),
          
          // 扫描框
          Center(
            child: _AnimatedScanBox(),
          ),
          
          // 底部提示
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Text(
                    widget.description,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        icon: Icons.photo_library,
                        label: '相册',
                        onTap: _pickFromGallery,
                      ),
                      SizedBox(width: 32),
                      _buildActionButton(
                        icon: Icons.qr_code,
                        label: '我的二维码',
                        onTap: _showMyQrCode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 从相册选择二维码图片
  Future<void> _pickFromGallery() async {
    // TODO: 实现从相册选择图片并解析二维码
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('从相册选择功能开发中')),
    );
  }
  
  // 显示我的二维码
  void _showMyQrCode() {
    // TODO: 实现显示我的二维码
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('我的二维码功能开发中')),
    );
  }
}

class _AnimatedScanBox extends StatefulWidget {
  @override
  __AnimatedScanBoxState createState() => __AnimatedScanBoxState();
}

class __AnimatedScanBoxState extends State<_AnimatedScanBox> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        // 扫描线
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Positioned(
              top: 250 * _animation.value,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: Colors.green.withOpacity(0.8),
              ),
            );
          },
        ),
        // 四个角
        Positioned(
          top: 0,
          left: 0,
          child: _buildCorner(topLeft: true),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _buildCorner(topRight: true),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _buildCorner(bottomLeft: true),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _buildCorner(bottomRight: true),
        ),
      ],
    );
  }
  
  Widget _buildCorner({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: topLeft || topRight ? BorderSide(color: Colors.green, width: 4) : BorderSide.none,
          right: topRight || bottomRight ? BorderSide(color: Colors.green, width: 4) : BorderSide.none,
          bottom: bottomLeft || bottomRight ? BorderSide(color: Colors.green, width: 4) : BorderSide.none,
          left: topLeft || bottomLeft ? BorderSide(color: Colors.green, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}
