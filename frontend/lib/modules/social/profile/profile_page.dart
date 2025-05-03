import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import '../../../common/persistence.dart';
import '../../../common/api.dart';
import '../../../common/theme.dart';
import '../../../widgets/app_avatar.dart';
import '../../../modules/profile/avatar_cropper.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserInfo? _userInfo;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 加载用户信息
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 尝试从API获取最新的用户信息
      final response = await Api.getUserInfo();

      if (response['success'] == true && response['data'] != null) {
        // 保存用户信息到本地
        await Persistence.saveUserInfo(response['data']);

        setState(() {
          _userInfo = UserInfo.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        // 如果API请求失败，尝试从本地获取
        final userInfo = await Persistence.getUserInfoAsync();

        setState(() {
          _userInfo = userInfo;
          _isLoading = false;
          if (userInfo == null) {
            _error = '无法获取用户信息';
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '获取用户信息失败: $e';
      });
    }
  }

  // 更新头像
  Future<void> _updateAvatar(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // 上传头像
      final response = await Api.uploadFile(imageFile.path, 'avatar');

      if (response['success'] == true) {
        // 更新用户信息
        final avatarUrl = response['data']['url'];
        final updateResponse = await Api.updateUserInfo({
          'avatar': avatarUrl,
        });

        if (updateResponse['success'] == true) {
          // 更新本地缓存
          await Persistence.saveUserInfo(updateResponse['data']);

          // 清除缓存的用户信息
          Persistence.clearCachedUserInfo();

          // 重新加载用户信息
          await _loadUserInfo();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('头像更新成功'), backgroundColor: Colors.green),
          );
        } else {
          setState(() {
            _isLoading = false;
            _error = updateResponse['msg'] ?? '更新用户信息失败';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = response['msg'] ?? '上传头像失败';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '操作异常: $e';
      });
    }
  }

  // 更新用户信息
  Future<void> _updateUserInfo(Map<String, dynamic> data) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await Api.updateUserInfo(data);

      if (response['success'] == true) {
        // 更新本地缓存
        await Persistence.saveUserInfo(response['data']);

        // 清除缓存的用户信息
        Persistence.clearCachedUserInfo();

        // 重新加载用户信息
        await _loadUserInfo();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('个人资料更新成功'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = response['msg'] ?? '更新用户信息失败';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '操作异常: $e';
      });
    }
  }

  // 显示编辑昵称对话框
  void _showEditNicknameDialog() {
    final TextEditingController controller = TextEditingController(text: _userInfo?.nickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑昵称'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '请输入新昵称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                _updateUserInfo({'nickname': controller.text});
              }
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('个人资料'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.all(0),
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                AvatarCropper(
                  initialAvatarUrl: _userInfo?.avatar,
                  size: 88,
                  onAvatarSelected: (File imageFile) {
                    _updateAvatar(imageFile);
                  },
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    _showEditNicknameDialog();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userInfo?.nickname != null && _userInfo!.nickname!.isNotEmpty
                            ? _userInfo!.nickname!
                            : _userInfo?.account ?? '用户',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text('账号: ${_userInfo?.account ?? '未知'}', style: TextStyle(color: Colors.grey)),
                if (_userInfo?.generatedEmail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('邮箱: ${_userInfo?.generatedEmail}', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shopping_bag, color: Colors.deepOrange),
                  title: Text('我的订单'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.color_lens, color: Colors.purple),
                  title: Text('主题商城'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: 跳转主题商城页面
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.location_on, color: Colors.green),
                  title: Text('收货地址'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.favorite, color: Colors.pink),
                  title: Text('我的收藏'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet, color: Colors.blue),
                  title: Text('我的钱包'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/wallet');
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.grey),
                  title: Text('设置'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
