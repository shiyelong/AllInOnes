import 'package:flutter/foundation.dart';
import 'platform_utils.dart';

/// 配置类
/// 用于存储应用配置信息
class Config {
  // API基础URL
  static String get apiUrl {
    if (kDebugMode) {
      // 开发环境
      if (PlatformUtils.isDesktop) {
        return 'http://localhost:3001/api';
      } else {
        // 移动设备使用本机IP，而不是localhost
        return 'http://192.168.1.100:3001/api';
      }
    } else {
      // 生产环境
      return 'https://api.allinone.com/api';
    }
  }
  
  // WebSocket基础URL
  static String get wsUrl {
    if (kDebugMode) {
      // 开发环境
      if (PlatformUtils.isDesktop) {
        return 'ws://localhost:3001/ws';
      } else {
        // 移动设备使用本机IP，而不是localhost
        return 'ws://192.168.1.100:3001/ws';
      }
    } else {
      // 生产环境
      return 'wss://api.allinone.com/ws';
    }
  }
  
  // 资源基础URL
  static String get resourceUrl {
    if (kDebugMode) {
      // 开发环境
      if (PlatformUtils.isDesktop) {
        return 'http://localhost:3001/resources';
      } else {
        // 移动设备使用本机IP，而不是localhost
        return 'http://192.168.1.100:3001/resources';
      }
    } else {
      // 生产环境
      return 'https://api.allinone.com/resources';
    }
  }
  
  // 默认头像URL
  static String get defaultAvatarUrl {
    return '$resourceUrl/default_avatar.png';
  }
  
  // 默认群组头像URL
  static String get defaultGroupAvatarUrl {
    return '$resourceUrl/default_group_avatar.png';
  }
  
  // 应用版本
  static const String appVersion = '1.0.0';
  
  // 应用构建号
  static const String appBuildNumber = '1';
  
  // 应用名称
  static const String appName = 'AllInOne';
  
  // 应用包名
  static const String appPackageName = 'com.allinone.app';
  
  // 应用ID
  static const String appId = 'com.allinone.app';
  
  // 应用描述
  static const String appDescription = '一款集成多种功能的全能应用';
  
  // 应用作者
  static const String appAuthor = 'AllInOne Team';
  
  // 应用官网
  static const String appWebsite = 'https://www.allinone.com';
  
  // 应用邮箱
  static const String appEmail = 'support@allinone.com';
  
  // 应用隐私政策URL
  static const String privacyPolicyUrl = 'https://www.allinone.com/privacy';
  
  // 应用服务条款URL
  static const String termsOfServiceUrl = 'https://www.allinone.com/terms';
  
  // 应用帮助中心URL
  static const String helpCenterUrl = 'https://www.allinone.com/help';
  
  // 应用反馈URL
  static const String feedbackUrl = 'https://www.allinone.com/feedback';
  
  // 应用更新URL
  static const String updateUrl = 'https://www.allinone.com/update';
  
  // 应用分享URL
  static const String shareUrl = 'https://www.allinone.com/share';
  
  // 应用评分URL
  static String get rateUrl {
    if (PlatformUtils.isIOS) {
      return 'https://apps.apple.com/app/id1234567890';
    } else if (PlatformUtils.isAndroid) {
      return 'https://play.google.com/store/apps/details?id=$appPackageName';
    } else {
      return appWebsite;
    }
  }
  
  // 最大重试次数
  static const int maxRetryCount = 3;
  
  // 请求超时时间（毫秒）
  static const int requestTimeout = 15000;
  
  // 最大上传文件大小（字节）
  static const int maxUploadFileSize = 50 * 1024 * 1024; // 50MB
  
  // 最大上传图片大小（字节）
  static const int maxUploadImageSize = 10 * 1024 * 1024; // 10MB
  
  // 最大上传视频大小（字节）
  static const int maxUploadVideoSize = 100 * 1024 * 1024; // 100MB
  
  // 最大上传语音大小（字节）
  static const int maxUploadVoiceSize = 5 * 1024 * 1024; // 5MB
  
  // 最大语音录制时长（秒）
  static const int maxVoiceRecordDuration = 60;
  
  // 最大视频录制时长（秒）
  static const int maxVideoRecordDuration = 60;
  
  // 图片压缩质量（0-100）
  static const int imageCompressQuality = 80;
  
  // 视频压缩质量（0-100）
  static const int videoCompressQuality = 80;
  
  // 最大聊天记录加载数量
  static const int maxChatHistoryLoadCount = 20;
  
  // 最大好友数量
  static const int maxFriendCount = 5000;
  
  // 最大群组数量
  static const int maxGroupCount = 500;
  
  // 最大群组成员数量
  static const int maxGroupMemberCount = 500;
  
  // 最大红包金额（元）
  static const double maxRedPacketAmount = 200.0;
  
  // 最小红包金额（元）
  static const double minRedPacketAmount = 0.01;
  
  // 最大转账金额（元）
  static const double maxTransferAmount = 50000.0;
  
  // 最小转账金额（元）
  static const double minTransferAmount = 0.01;
  
  // 验证码有效期（秒）
  static const int verificationCodeExpiration = 300;
  
  // 验证码长度
  static const int verificationCodeLength = 6;
  
  // 验证码冷却时间（秒）
  static const int verificationCodeCooldown = 60;
  
  // 密码最小长度
  static const int passwordMinLength = 8;
  
  // 密码最大长度
  static const int passwordMaxLength = 20;
  
  // 昵称最小长度
  static const int nicknameMinLength = 2;
  
  // 昵称最大长度
  static const int nicknameMaxLength = 20;
  
  // 签名最大长度
  static const int signatureMaxLength = 100;
  
  // 群组名称最小长度
  static const int groupNameMinLength = 2;
  
  // 群组名称最大长度
  static const int groupNameMaxLength = 20;
  
  // 群组公告最大长度
  static const int groupAnnouncementMaxLength = 500;
  
  // 聊天消息最大长度
  static const int chatMessageMaxLength = 5000;
  
  // 好友验证消息最大长度
  static const int friendVerificationMaxLength = 50;
  
  // 红包祝福语最大长度
  static const int redPacketGreetingMaxLength = 50;
  
  // 转账备注最大长度
  static const int transferRemarkMaxLength = 50;
  
  // 搜索关键词最小长度
  static const int searchKeywordMinLength = 1;
  
  // 搜索关键词最大长度
  static const int searchKeywordMaxLength = 20;
  
  // 搜索结果最大数量
  static const int searchResultMaxCount = 20;
  
  // 是否启用调试日志
  static const bool enableDebugLog = true;
  
  // 是否启用崩溃报告
  static const bool enableCrashReport = true;
  
  // 是否启用性能监控
  static const bool enablePerformanceMonitor = true;
  
  // 是否启用用户行为分析
  static const bool enableUserBehaviorAnalysis = true;
  
  // 是否启用自动更新
  static const bool enableAutoUpdate = true;
  
  // 是否启用推送通知
  static const bool enablePushNotification = true;
  
  // 是否启用离线消息
  static const bool enableOfflineMessage = true;
  
  // 是否启用消息已读回执
  static const bool enableMessageReadReceipt = true;
  
  // 是否启用消息撤回
  static const bool enableMessageRecall = true;
  
  // 消息撤回时限（秒）
  static const int messageRecallTimeLimit = 120;
  
  // 是否启用好友验证
  static const bool enableFriendVerification = true;
  
  // 是否启用群组验证
  static const bool enableGroupVerification = true;
  
  // 是否启用红包功能
  static const bool enableRedPacket = true;
  
  // 是否启用转账功能
  static const bool enableTransfer = true;
  
  // 是否启用语音通话
  static const bool enableVoiceCall = true;
  
  // 是否启用视频通话
  static const bool enableVideoCall = true;
  
  // 是否启用位置共享
  static const bool enableLocationSharing = true;
  
  // 是否启用文件共享
  static const bool enableFileSharing = true;
  
  // 是否启用表情包
  static const bool enableEmoji = true;
  
  // 是否启用贴纸
  static const bool enableSticker = true;
  
  // 是否启用GIF
  static const bool enableGif = true;
  
  // 是否启用朋友圈
  static const bool enableMoments = true;
  
  // 是否启用小程序
  static const bool enableMiniProgram = true;
  
  // 是否启用公众号
  static const bool enableOfficialAccount = true;
  
  // 是否启用扫一扫
  static const bool enableScan = true;
  
  // 是否启用摇一摇
  static const bool enableShake = true;
  
  // 是否启用附近的人
  static const bool enableNearby = true;
  
  // 是否启用漂流瓶
  static const bool enableBottle = true;
  
  // 是否启用游戏中心
  static const bool enableGameCenter = true;
  
  // 是否启用钱包
  static const bool enableWallet = true;
  
  // 是否启用支付
  static const bool enablePayment = true;
  
  // 是否启用收藏
  static const bool enableFavorite = true;
  
  // 是否启用标签
  static const bool enableTag = true;
  
  // 是否启用黑名单
  static const bool enableBlacklist = true;
  
  // 是否启用多语言
  static const bool enableMultiLanguage = true;
  
  // 是否启用多主题
  static const bool enableMultiTheme = true;
  
  // 是否启用字体大小调整
  static const bool enableFontSizeAdjustment = true;
  
  // 是否启用深色模式
  static const bool enableDarkMode = true;
  
  // 是否启用自动登录
  static const bool enableAutoLogin = true;
  
  // 是否启用记住密码
  static const bool enableRememberPassword = true;
  
  // 是否启用指纹登录
  static const bool enableFingerprintLogin = true;
  
  // 是否启用人脸登录
  static const bool enableFaceLogin = true;
  
  // 是否启用PIN登录
  static const bool enablePinLogin = true;
  
  // 是否启用手势登录
  static const bool enableGestureLogin = true;
  
  // 是否启用双因素认证
  static const bool enableTwoFactorAuth = true;
  
  // 是否启用隐私保护
  static const bool enablePrivacyProtection = true;
  
  // 是否启用数据备份
  static const bool enableDataBackup = true;
  
  // 是否启用数据恢复
  static const bool enableDataRestore = true;
  
  // 是否启用数据同步
  static const bool enableDataSync = true;
  
  // 是否启用清理缓存
  static const bool enableClearCache = true;
  
  // 是否启用清理聊天记录
  static const bool enableClearChatHistory = true;
  
  // 是否启用清理账号
  static const bool enableClearAccount = true;
  
  // 是否启用注销账号
  static const bool enableDeleteAccount = true;
}
