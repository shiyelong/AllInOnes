import 'dart:typed_data';
import 'package:typed_data/typed_data.dart';

// 添加一个扩展方法，提供 UnmodifiableUint8ListView 功能
extension Uint8ListExtension on Uint8List {
  Uint8List get unmodifiable {
    return UnmodifiableUint8ListView(this);
  }
}
