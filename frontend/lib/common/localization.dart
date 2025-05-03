import 'package:timeago/timeago.dart' as timeago;

class AppLocalization {
  static void initialize() {
    // 初始化timeago中文本地化
    timeago.setLocaleMessages('zh_CN', _ChineseMessages());
  }
}

// 自定义中文消息
class _ChineseMessages implements timeago.LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '从现在开始';
  @override
  String suffixAgo() => '前';
  @override
  String suffixFromNow() => '后';
  @override
  String lessThanOneMinute(int seconds) => '刚刚';
  @override
  String aboutAMinute(int minutes) => '1分钟';
  @override
  String minutes(int minutes) => '$minutes分钟';
  @override
  String aboutAnHour(int minutes) => '1小时';
  @override
  String hours(int hours) => '$hours小时';
  @override
  String aDay(int hours) => '1天';
  @override
  String days(int days) => '$days天';
  @override
  String aboutAMonth(int days) => '1个月';
  @override
  String months(int months) => '$months个月';
  @override
  String aboutAYear(int year) => '1年';
  @override
  String years(int years) => '$years年';
  @override
  String wordSeparator() => '';
}
