import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

/// 使用camera包实现的摄像头页面
///
/// 提供更稳定的拍照体验，支持桌面和移动平台
class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedCameraIndex = 0;
  bool _isCapturing = false;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 检查摄像头权限
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        try {
          final status = await Permission.camera.request();
          if (status.isDenied || status.isPermanentlyDenied) {
            setState(() {
              _isLoading = false;
              _errorMessage = '摄像头权限被拒绝，请在系统设置中允许应用访问摄像头';
            });
            return;
          }
        } catch (e) {
          print('请求摄像头权限出错: $e');
          // 继续执行，因为在某些平台上可能不需要显式请求权限
        }
      }

      // 获取可用摄像头列表
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '未检测到摄像头设备';
        });
        return;
      }

      // 初始化摄像头控制器
      await _initializeCameraController(_cameras![_selectedCameraIndex]);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化摄像头失败: $e';
      });
      print('摄像头初始化错误: $e');
    }
  }

  Future<void> _initializeCameraController(CameraDescription cameraDescription) async {
    try {
      // 创建新的控制器
      final CameraController controller = CameraController(
        cameraDescription,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // 释放旧控制器
      if (_controller != null) {
        await _controller!.dispose();
      }

      _controller = controller;

      // 初始化控制器
      await controller.initialize();

      // 获取缩放范围
      await _getZoomLevel();

      // 设置闪光灯模式
      await controller.setFlashMode(FlashMode.off);

      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '初始化摄像头控制器失败: $e';
      });
      print('摄像头控制器初始化错误: $e');
    }
  }

  Future<void> _getZoomLevel() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _minAvailableZoom = await _controller!.getMinZoomLevel();
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = 1.0;

      setState(() {});
    } catch (e) {
      print('获取缩放级别失败: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isCameraInitialized = false;
    });

    // 切换到下一个摄像头
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;

    await _initializeCameraController(_cameras![_selectedCameraIndex]);
  }

  Future<void> _setFlashMode(FlashMode mode) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.setFlashMode(mode);
      setState(() {
        _flashMode = mode;
      });
    } catch (e) {
      print('设置闪光灯模式失败: $e');
      setState(() {
        _errorMessage = '设置闪光灯模式失败: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // 拍照
      final XFile photo = await _controller!.takePicture();

      // 创建一个临时目录来存储照片
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      final String fileName = '${Uuid().v4()}.jpg';
      final String filePath = path.join(tempPath, fileName);

      // 复制照片到临时目录
      final File sourceFile = File(photo.path);
      await sourceFile.copy(filePath);

      // 返回照片路径
      Navigator.pop(context, XFile(filePath));
    } catch (e) {
      setState(() {
        _isCapturing = false;
        _errorMessage = '拍照失败: $e';
      });
      print('拍照错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择图片失败: $e';
      });
      print('选择图片错误: $e');
    }
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Text('摄像头未初始化', style: TextStyle(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final cameraRatio = _controller!.value.aspectRatio;

    return Transform.scale(
      scale: deviceRatio / cameraRatio,
      child: Center(
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: Text('重试'),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: _pickImageFromGallery,
              child: Text('从相册选择'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControl() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            Text('1x', style: TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: _currentZoomLevel,
                min: _minAvailableZoom,
                max: _maxAvailableZoom,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
                onChanged: (value) async {
                  setState(() {
                    _currentZoomLevel = value;
                  });
                  await _controller?.setZoomLevel(value);
                },
              ),
            ),
            Text('${_maxAvailableZoom.toStringAsFixed(1)}x', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashControl() {
    IconData getFlashIcon() {
      switch (_flashMode) {
        case FlashMode.off:
          return Icons.flash_off;
        case FlashMode.auto:
          return Icons.flash_auto;
        case FlashMode.always:
          return Icons.flash_on;
        case FlashMode.torch:
          return Icons.highlight;
        default:
          return Icons.flash_off;
      }
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(getFlashIcon(), color: Colors.white),
          onPressed: () {
            if (_flashMode == FlashMode.off) {
              _setFlashMode(FlashMode.auto);
            } else if (_flashMode == FlashMode.auto) {
              _setFlashMode(FlashMode.always);
            } else if (_flashMode == FlashMode.always) {
              _setFlashMode(FlashMode.torch);
            } else {
              _setFlashMode(FlashMode.off);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('拍照'),
        actions: [
          IconButton(
            icon: Icon(Icons.photo_library),
            onPressed: _pickImageFromGallery,
            tooltip: '从相册选择',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : Stack(
                  children: [
                    // 摄像头预览
                    _buildCameraPreview(),

                    // 缩放控制
                    if (_isCameraInitialized)
                      _buildZoomControl(),

                    // 闪光灯控制
                    if (_isCameraInitialized)
                      _buildFlashControl(),

                    // 底部控制栏
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 切换摄像头按钮
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.flip_camera_ios, color: Colors.white),
                              onPressed: _switchCamera,
                            ),
                          ),

                          // 拍照按钮
                          GestureDetector(
                            onTap: _isCapturing ? null : _takePhoto,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: _isCapturing
                                  ? Center(child: CircularProgressIndicator(color: Colors.black))
                                  : Container(
                                      margin: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),

                          // 占位，保持对称
                          SizedBox(width: 50, height: 50),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
