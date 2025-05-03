class Config {
  // API基础URL
  static const String baseUrl = 'http://localhost:3001/api';

  // WebSocket基础URL
  static const String wsBaseUrl = 'ws://localhost:3001/api';

  // 图片上传URL
  static const String uploadUrl = '$baseUrl/upload';

  // 头像URL前缀
  static const String avatarUrlPrefix = '$baseUrl/avatar';

  // 文件URL前缀
  static const String fileUrlPrefix = '$baseUrl/file';

  // 应用名称
  static const String appName = 'AllInOne';

  // 应用版本
  static const String appVersion = '1.0.0';

  // 应用ID
  static const String appId = 'com.allinone.app';

  // 邮箱后缀
  static const String emailSuffix = 'mail.allinone.com';
}
