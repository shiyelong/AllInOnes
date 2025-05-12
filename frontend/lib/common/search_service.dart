import 'package:flutter/material.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/persistence.dart';

/// 搜索类型枚举
enum SearchType {
  /// 社交模块搜索
  social,
  /// 聊天记录搜索
  chat,
  /// 好友搜索
  friend,
  /// 游戏搜索
  game,
  /// 广场搜索
  plaza,
  /// 全局搜索
  global,
}

/// 搜索服务类，根据当前模块进行搜索
class SearchService {

  /// 执行搜索
  static Future<Map<String, dynamic>> search({
    required String keyword,
    required SearchType type,
    String? chatId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (keyword.isEmpty) {
      return {'success': false, 'msg': '搜索关键词不能为空', 'data': []};
    }

    final userId = Persistence.getUserInfo()?.id;
    if (userId == null) {
      return {'success': false, 'msg': '未获取到用户信息', 'data': []};
    }

    try {
      switch (type) {
        case SearchType.social:
          // 社交模块搜索，包括好友、群组等
          return await _searchSocial(keyword, userId);

        case SearchType.chat:
          // 聊天记录搜索
          if (chatId == null) {
            return {'success': false, 'msg': '未指定聊天ID', 'data': []};
          }
          return await _searchChatMessages(keyword, userId, chatId);

        case SearchType.friend:
          // 好友搜索
          return await _searchFriends(keyword, userId);

        case SearchType.game:
          // 游戏搜索
          return await _searchGames(keyword);

        case SearchType.plaza:
          // 广场搜索
          return await _searchPlaza(keyword, page, pageSize);

        case SearchType.global:
          // 全局搜索，合并多个模块的结果
          return await _searchGlobal(keyword, userId);

        default:
          return {'success': false, 'msg': '不支持的搜索类型', 'data': []};
      }
    } catch (e) {
      debugPrint('[SearchService] 搜索异常: $e');
      return {'success': false, 'msg': '搜索出错: $e', 'data': []};
    }
  }

  /// 社交模块搜索
  static Future<Map<String, dynamic>> _searchSocial(String keyword, String userId) async {
    // 搜索好友和群组
    final result = await Api.searchUsers(
      keyword: keyword,
      page: 1,
      pageSize: 20,
    );

    return result;
  }

  /// 聊天记录搜索
  static Future<Map<String, dynamic>> _searchChatMessages(String keyword, String userId, String chatId) async {
    // 目前API不支持搜索聊天记录，返回空结果
    // TODO: 实现聊天记录搜索API
    return {'success': true, 'msg': '搜索成功', 'data': []};
  }

  /// 好友搜索
  static Future<Map<String, dynamic>> _searchFriends(String keyword, String userId) async {
    // 搜索好友
    final result = await Api.searchUsers(
      keyword: keyword,
      page: 1,
      pageSize: 20,
    );

    return result;
  }

  /// 游戏搜索
  static Future<Map<String, dynamic>> _searchGames(String keyword) async {
    // 目前API不支持搜索游戏，返回空结果
    // TODO: 实现游戏搜索API
    return {'success': true, 'msg': '搜索成功', 'data': []};
  }

  /// 广场搜索
  static Future<Map<String, dynamic>> _searchPlaza(String keyword, int page, int pageSize) async {
    // 目前API不支持搜索广场，返回空结果
    // TODO: 实现广场搜索API
    return {'success': true, 'msg': '搜索成功', 'data': []};
  }

  /// 全局搜索
  static Future<Map<String, dynamic>> _searchGlobal(String keyword, String userId) async {
    // 合并多个模块的搜索结果
    final socialResult = await _searchSocial(keyword, userId);

    // 目前只实现了社交模块搜索，其他模块待实现
    return socialResult;
  }

  /// 根据当前路由获取搜索类型
  static SearchType getSearchTypeFromRoute(String route) {
    if (route.startsWith('/social')) {
      return SearchType.social;
    } else if (route.startsWith('/chat')) {
      return SearchType.chat;
    } else if (route.startsWith('/game')) {
      return SearchType.game;
    } else if (route.startsWith('/plaza')) {
      return SearchType.plaza;
    } else {
      return SearchType.global;
    }
  }

  /// 获取搜索提示文本
  static String getSearchHint(SearchType type) {
    switch (type) {
      case SearchType.social:
        return '搜索好友、群组';
      case SearchType.chat:
        return '搜索聊天记录';
      case SearchType.friend:
        return '搜索好友';
      case SearchType.game:
        return '搜索游戏';
      case SearchType.plaza:
        return '搜索广场内容';
      case SearchType.global:
        return '全局搜索';
      default:
        return '搜索';
    }
  }
}
