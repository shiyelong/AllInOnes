import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../common/api.dart';
import '../../common/theme_manager.dart';

class SimpleAvatarPicker extends StatefulWidget {
  final String? initialAvatarUrl;
  final Function(File) onAvatarSelected;
  final double size;

  const SimpleAvatarPicker({
    Key? key,
    this.initialAvatarUrl,
    required this.onAvatarSelected,
    this.size = 100,
  }) : super(key: key);

  @override
  _SimpleAvatarPickerState createState() => _SimpleAvatarPickerState();
}

class _SimpleAvatarPickerState extends State<SimpleAvatarPicker> {
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialAvatar();
  }

  Future<void> _loadInitialAvatar() async {
    if (widget.initialAvatarUrl != null && widget.initialAvatarUrl!.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 如果是网络URL，下载图片
        if (widget.initialAvatarUrl!.startsWith('http')) {
          final response = await http.get(Uri.parse(widget.initialAvatarUrl!));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/temp_avatar.jpg');
            await file.writeAsBytes(response.bodyBytes);
            setState(() {
              _imageFile = file;
            });
          }
        } 
        // 如果是本地路径
        else if (widget.initialAvatarUrl!.startsWith('/')) {
          final file = File(widget.initialAvatarUrl!);
          if (await file.exists()) {
            setState(() {
              _imageFile = file;
            });
          }
        }
      } catch (e) {
        debugPrint('加载头像失败: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        widget.onAvatarSelected(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;
    
    return GestureDetector(
      onTap: _showImageSourceActionSheet,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: theme.isDark ? Colors.grey[800] : Colors.grey[200],
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.primaryColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator()
            : Stack(
                children: [
                  ClipOval(
                    child: _imageFile != null
                        ? Image.file(
                            _imageFile!,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.cover,
                          )
                        : widget.initialAvatarUrl != null && widget.initialAvatarUrl!.startsWith('http')
                            ? Image.network(
                                widget.initialAvatarUrl!,
                                width: widget.size,
                                height: widget.size,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: widget.size * 0.6,
                                    color: theme.primaryColor,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: widget.size * 0.6,
                                color: theme.primaryColor,
                              ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
