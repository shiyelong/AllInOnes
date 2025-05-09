import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GroupInfoPage extends StatefulWidget {
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> members;
  final Function(Map<String, dynamic>) onGroupUpdated;

  const GroupInfoPage({
    Key? key,
    required this.group,
    required this.members,
    required this.onGroupUpdated,
  }) : super(key: key);

  @override
  _GroupInfoPageState createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  bool _isLoading = false;
  bool _isEditing = false;
  String _errorMessage = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noticeController = TextEditingController();
  File? _avatarFile;
  int _currentUserId = 0;
  bool _isOwner = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group['name'] ?? '';
    _noticeController.text = widget.group['notice'] ?? '';
    _loadUserRole();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noticeController.dispose();
    super.dispose();
  }

  void _loadUserRole() {
    final userInfo = Persistence.getUserInfo();
    if (userInfo != null) {
      _currentUserId = userInfo.id;
      
      // 检查当前用户是否是群主或管理员
      for (var member in widget.members) {
        if (member['user_id'] == _currentUserId) {
          if (member['role'] == 'owner') {
            setState(() {
              _isOwner = true;
            });
          } else if (member['role'] == 'admin') {
            setState(() {
              _isAdmin = true;
            });
          }
          break;
        }
      }
    }
  }

  Future<void> _pickImage() async {
    if (!_isOwner && !_isAdmin) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  Future<void> _updateGroup() async {
    if (!_isOwner && !_isAdmin) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 上传新头像（如果有）
      String avatarUrl = widget.group['avatar'] ?? '';
      if (_avatarFile != null) {
        final uploadResult = await Api.uploadFile(
          file: _avatarFile!,
          type: 'image',
          userId: _currentUserId.toString(),
        );
        
        if (uploadResult['success'] == true) {
          avatarUrl = uploadResult['data']['url'] ?? '';
        }
      }

      // 更新群组信息
      final result = await Api.updateGroup(
        groupId: widget.group['id'].toString(),
        name: _nameController.text,
        notice: _noticeController.text,
        avatar: avatarUrl,
      );

      if (result['success'] == true) {
        // 更新成功
        final updatedGroup = Map<String, dynamic>.from(widget.group);
        updatedGroup['name'] = _nameController.text;
        updatedGroup['notice'] = _noticeController.text;
        updatedGroup['avatar'] = avatarUrl;
        
        widget.onGroupUpdated(updatedGroup);
        
        setState(() {
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('群组信息已更新'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '更新群组信息失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '更新群组信息失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveGroup() async {
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('群主不能退出群组，请先转让群主身份'), backgroundColor: Colors.red),
      );
      return;
    }

    // 显示确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('退出群组'),
        content: Text('确定要退出该群组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确定'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await Api.leaveGroup(
        groupId: widget.group['id'].toString(),
        userId: _currentUserId.toString(),
      );

      if (result['success'] == true) {
        // 退出成功，返回上一页
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已退出群组'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
        Navigator.pop(context); // 退出群聊页面
      } else {
        setState(() {
          _errorMessage = result['msg'] ?? '退出群组失败';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '退出群组失败: $e';
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
        title: Text('群组信息'),
        actions: [
          if (_isOwner || _isAdmin)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_isEditing) {
                        _updateGroup();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
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

                  // 群头像和名称
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isEditing ? _pickImage : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: _avatarFile != null
                                    ? FileImage(_avatarFile!)
                                    : widget.group['avatar'] != null && widget.group['avatar'].isNotEmpty
                                        ? NetworkImage(widget.group['avatar'])
                                        : null,
                                backgroundColor: theme.primaryColor.withOpacity(0.2),
                                child: widget.group['avatar'] == null || widget.group['avatar'].isEmpty && _avatarFile == null
                                    ? Icon(
                                        Icons.group,
                                        size: 50,
                                        color: theme.primaryColor,
                                      )
                                    : null,
                              ),
                              if (_isEditing)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        _isEditing
                            ? TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: '群组名称',
                                  border: OutlineInputBorder(),
                                ),
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                widget.group['name'] ?? '群聊',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // 群公告
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '群公告',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          _isEditing
                              ? TextField(
                                  controller: _noticeController,
                                  decoration: InputDecoration(
                                    hintText: '输入群公告',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                )
                              : Text(
                                  widget.group['notice']?.isNotEmpty == true
                                      ? widget.group['notice']
                                      : '暂无群公告',
                                  style: TextStyle(
                                    color: widget.group['notice']?.isNotEmpty == true
                                        ? null
                                        : Colors.grey,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // 群成员
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '群成员 (${widget.members.length})',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isOwner || _isAdmin)
                                TextButton.icon(
                                  icon: Icon(Icons.person_add),
                                  label: Text('添加'),
                                  onPressed: () {
                                    // TODO: 实现添加群成员功能
                                  },
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: widget.members.length,
                            itemBuilder: (context, index) {
                              final member = widget.members[index];
                              final isCurrentUser = member['user_id'] == _currentUserId;
                              
                              return Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundImage: member['avatar'] != null && member['avatar'].isNotEmpty
                                            ? NetworkImage(member['avatar'])
                                            : null,
                                        child: member['avatar'] == null || member['avatar'].isEmpty
                                            ? Text(
                                                (member['nickname'] ?? '').isNotEmpty
                                                    ? (member['nickname'] ?? '')[0]
                                                    : '?',
                                              )
                                            : null,
                                      ),
                                      if (member['role'] == 'owner')
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      if (member['role'] == 'admin')
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.admin_panel_settings,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    isCurrentUser
                                        ? '${member['nickname'] ?? ''}(我)'
                                        : member['nickname'] ?? '',
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // 退出群组按钮
                  if (!_isOwner)
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.exit_to_app, color: Colors.red),
                        label: Text('退出群组', style: TextStyle(color: Colors.red)),
                        onPressed: _leaveGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
