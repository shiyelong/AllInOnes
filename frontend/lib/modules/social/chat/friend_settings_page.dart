import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/widgets/app_button.dart';

class FriendSettingsPage extends StatefulWidget {
  final Function()? onSettingsChanged;
  
  const FriendSettingsPage({Key? key, this.onSettingsChanged}) : super(key: key);

  @override
  State<FriendSettingsPage> createState() => _FriendSettingsPageState();
}

class _FriendSettingsPageState extends State<FriendSettingsPage> {
  bool _isLoading = false;
  String? _error;
  
  // 好友添加模式
  int _friendAddMode = 0; // 0=自动同意，1=需验证，2=拒绝所有
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  // 加载设置
  Future<void> _loadSettings() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      setState(() {
        _error = '未获取到用户信息，请重新登录';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final response = await Api.getFriendAddMode(
        userId: userId.toString(),
      );
      
      if (response['success'] == true) {
        setState(() {
          _friendAddMode = response['data']['mode'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['msg'] ?? '获取设置失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '网络异常或服务器错误: $e';
        _isLoading = false;
      });
    }
  }
  
  // 保存设置
  Future<void> _saveSettings() async {
    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('未获取到用户信息，请重新登录'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await Api.setFriendAddMode(
        userId: userId.toString(),
        mode: _friendAddMode,
      );
      
      if (response['success'] == true) {
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 回调
        widget.onSettingsChanged?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg'] ?? '保存失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('网络异常或服务器错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('好友设置'),
        actions: [
          // 刷新按钮
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red),
                      ),
                      SizedBox(height: 24),
                      AppButton(
                        onPressed: _loadSettings,
                        text: '重试',
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 好友添加设置
                      Card(
                        margin: EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                '好友添加方式',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(height: 1),
                            RadioListTile<int>(
                              title: Text('自动同意'),
                              subtitle: Text('所有好友请求将自动同意'),
                              value: 0,
                              groupValue: _friendAddMode,
                              onChanged: (value) {
                                setState(() {
                                  _friendAddMode = value!;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                            RadioListTile<int>(
                              title: Text('需要验证'),
                              subtitle: Text('收到好友请求时，需要您手动同意'),
                              value: 1,
                              groupValue: _friendAddMode,
                              onChanged: (value) {
                                setState(() {
                                  _friendAddMode = value!;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                            RadioListTile<int>(
                              title: Text('拒绝所有'),
                              subtitle: Text('所有好友请求将自动拒绝'),
                              value: 2,
                              groupValue: _friendAddMode,
                              onChanged: (value) {
                                setState(() {
                                  _friendAddMode = value!;
                                });
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: AppButton(
                                onPressed: _saveSettings,
                                text: '保存设置',
                                isLoading: _isLoading,
                                color: AppTheme.primaryColor,
                                width: double.infinity,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 好友管理
                      Card(
                        margin: EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                '好友管理',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.block, color: Colors.red),
                              title: Text('黑名单管理'),
                              subtitle: Text('管理被屏蔽的用户'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: 导航到黑名单管理页面
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('黑名单管理功能即将上线'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.group_remove, color: Colors.orange),
                              title: Text('批量管理好友'),
                              subtitle: Text('批量删除或移动好友'),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: 导航到批量管理好友页面
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('批量管理好友功能即将上线'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // 隐私设置
                      Card(
                        margin: EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                '隐私设置',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Divider(height: 1),
                            SwitchListTile(
                              title: Text('允许通过手机号查找我'),
                              subtitle: Text('他人可以通过手机号搜索到您'),
                              value: true, // TODO: 从API获取实际值
                              onChanged: (value) {
                                // TODO: 实现设置更新
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('此功能即将上线'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                            SwitchListTile(
                              title: Text('允许通过邮箱查找我'),
                              subtitle: Text('他人可以通过邮箱搜索到您'),
                              value: true, // TODO: 从API获取实际值
                              onChanged: (value) {
                                // TODO: 实现设置更新
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('此功能即将上线'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
