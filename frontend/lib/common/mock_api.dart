import 'dart:math';
import 'package:flutter/foundation.dart';

/// 模拟API响应，用于在后端API不可用时提供测试数据
class MockApi {
  static final Random _random = Random();

  /// 生成随机账号
  static String _generateRandomAccount() {
    return (100000 + _random.nextInt(900000)).toString();
  }

  /// 生成随机昵称
  static String _generateRandomNickname() {
    final List<String> firstNames = [
      '张', '王', '李', '赵', '刘', '陈', '杨', '黄', '周', '吴',
      '郑', '孙', '马', '朱', '胡', '林', '郭', '何', '高', '罗'
    ];

    final List<String> lastNames = [
      '伟', '芳', '娜', '秀英', '敏', '静', '丽', '强', '磊', '军',
      '洋', '勇', '艳', '杰', '娟', '涛', '明', '超', '秀兰', '霞'
    ];

    return '${firstNames[_random.nextInt(firstNames.length)]}${lastNames[_random.nextInt(lastNames.length)]}';
  }

  /// 生成随机性别
  static String _generateRandomGender() {
    final genders = ['男', '女', '未知'];
    final weights = [40, 40, 20]; // 权重：40% 男, 40% 女, 20% 未知

    final totalWeight = weights.reduce((a, b) => a + b);
    final randomValue = _random.nextInt(totalWeight);

    int cumulativeWeight = 0;
    for (int i = 0; i < genders.length; i++) {
      cumulativeWeight += weights[i];
      if (randomValue < cumulativeWeight) {
        return genders[i];
      }
    }

    return '未知';
  }

  /// 生成随机头像URL
  static String? _generateRandomAvatar() {
    // 70%的概率有头像
    if (_random.nextInt(100) < 70) {
      final id = _random.nextInt(1000);
      return 'https://randomuser.me/api/portraits/${_random.nextBool() ? 'men' : 'women'}/$id.jpg';
    }
    return null;
  }

  /// 生成推荐好友列表
  static Map<String, dynamic> getRecommendedFriends({
    String? currentUserId,
    int limit = 10,
    String? gender,
  }) {
    debugPrint('[MockApi] 获取推荐好友: currentUserId=$currentUserId, limit=$limit, gender=$gender');

    final List<Map<String, dynamic>> friends = [];

    // 确保至少生成10个推荐好友，不管性别筛选
    int count = 0;
    int maxAttempts = limit * 3; // 防止无限循环
    int attempts = 0;

    while (count < limit && attempts < maxAttempts) {
      attempts++;
      final randomGender = _generateRandomGender();

      // 如果指定了性别筛选，则跳过不匹配的性别
      if (gender != null && gender.isNotEmpty && randomGender != gender) {
        continue;
      }

      count++;
      final friend = {
        'id': (1000 + _random.nextInt(9000)).toString(),
        'account': _generateRandomAccount(),
        'nickname': _generateRandomNickname(),
        'gender': randomGender,
        'avatar': _generateRandomAvatar(),
        'is_friend': false,
        'has_pending_request': false,
        'friend_add_mode': _random.nextInt(3), // 0=自动通过，1=需验证，2=拒绝所有
      };

      friends.add(friend);
    }

    return {
      'success': true,
      'data': friends,
      'total': friends.length,
    };
  }

  /// 搜索用户
  static Map<String, dynamic> searchUsers({
    required String keyword,
    String? currentUserId,
    String? gender,
  }) {
    debugPrint('[MockApi] 搜索用户: keyword=$keyword, currentUserId=$currentUserId, gender=$gender');

    final List<Map<String, dynamic>> users = [];

    // 生成随机搜索结果
    final resultCount = 1 + _random.nextInt(5); // 1-5个结果

    for (int i = 0; i < resultCount; i++) {
      final randomGender = _generateRandomGender();

      // 如果指定了性别筛选，则跳过不匹配的性别
      if (gender != null && gender.isNotEmpty && randomGender != gender) {
        continue;
      }

      final nickname = _generateRandomNickname();
      final account = _generateRandomAccount();

      // 确保结果与搜索关键词相关
      if (!nickname.contains(keyword) && !account.contains(keyword)) {
        continue;
      }

      final user = {
        'id': (1000 + _random.nextInt(9000)).toString(),
        'account': account,
        'nickname': nickname,
        'gender': randomGender,
        'avatar': _generateRandomAvatar(),
        'is_friend': _random.nextBool() && _random.nextBool(), // 25%概率已是好友
        'has_pending_request': !_random.nextBool() && _random.nextBool(), // 25%概率有待处理请求
        'friend_add_mode': _random.nextInt(3), // 0=自动通过，1=需验证，2=拒绝所有
      };

      users.add(user);
    }

    return {
      'success': true,
      'data': users,
      'total': users.length,
    };
  }
}
