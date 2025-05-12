import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:frontend/modules/social/friends/friend_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({Key? key}) : super(key: key);

  @override
  _CreateGroupPageState createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _avatarFile;
  List<Map<String, dynamic>> _selectedFriends = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFriends.isEmpty) {
      setState(() {
        _errorMessage = '请至少选择一个好友添加到群组';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userInfo = Persistence.getUserInfo();
      if (userInfo == null) {
        throw Exception('用户未登录');
      }

      // 上传群头像（如果有）
      String avatarUrl = '';
      if (_avatarFile != null) {
        try {
          // 使用真实的文件上传API
          final uploadResult = await Api.uploadFile(
            filePath: _avatarFile!.path,
            targetId: '0',
            fileName: 'group_avatar.jpg',
            fileType: 'image'
          );
          if (uploadResult['success'] == true && uploadResult['data'] != null) {
            avatarUrl = uploadResult['data']['url'] ?? '';
            debugPrint('群头像上传成功: $avatarUrl');
          } else {
            debugPrint('群头像上传失败: ${uploadResult['msg']}');
            throw Exception(uploadResult['msg'] ?? '头像上传失败');
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = '头像上传失败: $e';
          });
          return;
        }
      }

      // 准备成员列表（包括创建者）
      final List<String> memberIds = [userInfo.id];
      for (var friend in _selectedFriends) {
        memberIds.add(friend['friend_id'].toString());
      }

      // 创建群组
      final result = await Api.createGroup(
        name: _nameController.text,
        avatar: avatarUrl,
        memberIds: memberIds,
        ownerId: userInfo.id.toString(),
      );

      if (result['success'] == true) {
        // 创建成功，返回上一页
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('群组创建成功'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, result['data']);
        }
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '创建群组失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '创建群组失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.currentTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('创建群组'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: Text(
              '创建',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 错误消息
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 群头像
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: theme.primaryColor.withOpacity(0.2),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: theme.primaryColor,
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Text(
                        '点击添加群头像',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    SizedBox(height: 24),

                    // 群名称
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '群组名称',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入群组名称';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // 群描述
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: '群组描述',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 24),

                    // 选择好友
                    Text(
                      '选择好友添加到群组',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    FriendSelector(
                      onSelectionChanged: (selectedFriends) {
                        setState(() {
                          _selectedFriends = selectedFriends;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
