import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 位置选择对话框
class LocationPickerDialog extends StatefulWidget {
  final Function(double latitude, double longitude, String address) onLocationSelected;

  const LocationPickerDialog({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  _LocationPickerDialogState createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  bool _isLoading = true;
  String _error = '';
  Position? _currentPosition;
  String _currentAddress = '';
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = '位置服务未启用，请开启位置服务';
          _isLoading = false;
        });
        return;
      }

      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = '位置权限被拒绝';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = '位置权限被永久拒绝，请在设置中启用';
          _isLoading = false;
        });
        return;
      }

      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // 获取地址
      _getAddressFromLatLng();
    } catch (e) {
      setState(() {
        _error = '获取位置失败: $e';
        _isLoading = false;
      });
    }
  }

  // 根据经纬度获取地址
  Future<void> _getAddressFromLatLng() async {
    if (_selectedLocation == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      print('获取地址失败: $e');
      setState(() {
        _currentAddress = '未知地址';
      });
    }
  }

  // 处理地图点击
  void _handleTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _getAddressFromLatLng();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '选择位置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _selectedLocation,
                            zoom: 15.0,
                            onTap: _handleTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                              // 添加错误处理
                              errorImage: NetworkImage('https://via.placeholder.com/256x256?text=Map+Error'),
                              // 添加备用地图源
                              fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                              // 添加自定义头信息
                              tileProvider: NetworkTileProvider(
                                headers: {
                                  'User-Agent': 'AllInOne App (https://allinone.com)',
                                },
                              ),
                            ),
                            MarkerLayer(
                              markers: [
                                if (_selectedLocation != null)
                                  Marker(
                                    width: 40.0,
                                    height: 40.0,
                                    point: _selectedLocation!,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _currentAddress.isEmpty ? '点击地图选择位置' : _currentAddress,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _selectedLocation == null
                      ? null
                      : () {
                          widget.onLocationSelected(
                            _selectedLocation!.latitude,
                            _selectedLocation!.longitude,
                            _currentAddress,
                          );
                          Navigator.pop(context);
                        },
                  child: Text('发送位置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 实时位置共享对话框
class LiveLocationSharingDialog extends StatefulWidget {
  final Function(double latitude, double longitude, String address, int duration)
      onLiveLocationSharing;

  const LiveLocationSharingDialog({
    Key? key,
    required this.onLiveLocationSharing,
  }) : super(key: key);

  @override
  _LiveLocationSharingDialogState createState() =>
      _LiveLocationSharingDialogState();
}

class _LiveLocationSharingDialogState extends State<LiveLocationSharingDialog> {
  int _selectedDuration = 15; // 默认15分钟
  bool _isLoading = true;
  String _error = '';
  Position? _currentPosition;
  String _currentAddress = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = '位置服务未启用，请开启位置服务';
          _isLoading = false;
        });
        return;
      }

      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = '位置权限被拒绝';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = '位置权限被永久拒绝，请在设置中启用';
          _isLoading = false;
        });
        return;
      }

      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // 获取地址
      _getAddressFromLatLng();
    } catch (e) {
      setState(() {
        _error = '获取位置失败: $e';
        _isLoading = false;
      });
    }
  }

  // 根据经纬度获取地址
  Future<void> _getAddressFromLatLng() async {
    if (_currentPosition == null) return;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      print('获取地址失败: $e');
      setState(() {
        _currentAddress = '未知地址';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '实时位置共享',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Container(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error.isNotEmpty)
              Container(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _error,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentAddress.isEmpty ? '获取地址中...' : _currentAddress,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('选择共享时长'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildDurationChip(15),
                      _buildDurationChip(30),
                      _buildDurationChip(60),
                      _buildDurationChip(120),
                    ],
                  ),
                ],
              ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _currentPosition == null
                      ? null
                      : () {
                          widget.onLiveLocationSharing(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            _currentAddress,
                            _selectedDuration,
                          );
                          Navigator.pop(context);
                        },
                  child: Text('开始共享'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes) {
    final isSelected = _selectedDuration == minutes;
    return ChoiceChip(
      label: Text('$minutes 分钟'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedDuration = minutes;
          });
        }
      },
      backgroundColor: Colors.grey.withOpacity(0.1),
      selectedColor: Colors.blue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

/// 位置消息展示组件
class LocationMessageWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;
  final VoidCallback? onTap;

  const LocationMessageWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(latitude, longitude),
                        zoom: 15.0,
                        interactiveFlags: InteractiveFlag.none,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                          // 添加错误处理
                          errorImage: NetworkImage('https://via.placeholder.com/256x256?text=Map+Error'),
                          // 添加备用地图源
                          fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                          // 添加自定义头信息
                          tileProvider: NetworkTileProvider(
                            headers: {
                              'User-Agent': 'AllInOne App (https://allinone.com)',
                            },
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: LatLng(latitude, longitude),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 添加加载失败的备用显示
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        size: 32,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '位置信息',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// 实时位置共享消息组件
class LiveLocationMessageWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;
  final int duration;
  final int startTime;
  final VoidCallback? onTap;

  const LiveLocationMessageWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.duration,
    required this.startTime,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 计算剩余时间
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final endTime = startTime + (duration * 60);
    final remainingSeconds = endTime - now;
    final isExpired = remainingSeconds <= 0;

    // 格式化剩余时间
    String remainingTime = '';
    if (!isExpired) {
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      remainingTime = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(latitude, longitude),
                        zoom: 15.0,
                        interactiveFlags: InteractiveFlag.none,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                          // 添加错误处理
                          errorImage: NetworkImage('https://via.placeholder.com/256x256?text=Map+Error'),
                          // 添加备用地图源
                          fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                          // 添加自定义头信息
                          tileProvider: NetworkTileProvider(
                            headers: {
                              'User-Agent': 'AllInOne App (https://allinone.com)',
                            },
                          ),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: LatLng(latitude, longitude),
                              child: Icon(
                                Icons.location_on,
                                color: isExpired ? Colors.grey : Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 添加加载失败的备用显示
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        size: 32,
                        color: isExpired ? Colors.grey : Colors.red,
                      ),
                    ),
                  ),
                  // 添加实时位置指示器
                  if (!isExpired)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_searching,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_searching,
                        size: 16,
                        color: isExpired ? Colors.grey : Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        isExpired ? '实时位置（已结束）' : '实时位置',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isExpired ? Colors.grey : Colors.black,
                        ),
                      ),
                      Spacer(),
                      if (!isExpired)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            remainingTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    address,
                    style: TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
