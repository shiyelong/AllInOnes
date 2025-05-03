import 'package:flutter/material.dart';
import '../../../common/theme_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ThemeSettingsPage extends StatefulWidget {
  final Function? onThemeChanged;

  const ThemeSettingsPage({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  _ThemeSettingsPageState createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late String _selectedThemeId;
  bool _isCreatingCustomTheme = false;

  // 自定义主题参数
  String _customThemeName = '我的主题';
  Color _customPrimaryColor = Colors.blue;
  Color _customSelfMessageColor = Colors.blue;
  Color _customOtherMessageColor = Colors.grey.shade200;
  bool _customIsDark = false;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = ThemeManager.currentTheme.id;
  }

  void _selectTheme(String themeId) async {
    setState(() {
      _selectedThemeId = themeId;
    });

    await ThemeManager.setTheme(themeId);

    if (widget.onThemeChanged != null) {
      widget.onThemeChanged!();
    }
  }

  void _saveCustomTheme() async {
    final customTheme = AppThemeData.custom(
      name: _customThemeName,
      primaryColor: _customPrimaryColor,
      selfMessageBubbleColor: _customSelfMessageColor,
      otherMessageBubbleColor: _customOtherMessageColor,
      isDark: _customIsDark,
    );

    await ThemeManager.saveCustomTheme(customTheme);

    setState(() {
      _selectedThemeId = customTheme.id;
      _isCreatingCustomTheme = false;
    });

    if (widget.onThemeChanged != null) {
      widget.onThemeChanged!();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('主题已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主题设置'),
        actions: [
          if (!_isCreatingCustomTheme)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _isCreatingCustomTheme = true;
                });
              },
              tooltip: '创建自定义主题',
            ),
        ],
      ),
      body: _isCreatingCustomTheme
          ? _buildCustomThemeEditor()
          : _buildThemeList(),
    );
  }

  Widget _buildThemeList() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '选择主题',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...ThemeManager.predefinedThemes.map((theme) => _buildThemeItem(theme)),
      ],
    );
  }

  Widget _buildThemeItem(AppThemeData theme) {
    final isSelected = _selectedThemeId == theme.id;

    return ListTile(
      title: Text(theme.name),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () => _selectTheme(theme.id),
    );
  }

  Widget _buildCustomThemeEditor() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          '创建自定义主题',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: '主题名称',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: _customThemeName),
          onChanged: (value) {
            setState(() {
              _customThemeName = value;
            });
          },
        ),
        SizedBox(height: 16),
        Text('主题颜色', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        _buildColorPicker(
          '主题颜色',
          _customPrimaryColor,
          (color) {
            setState(() {
              _customPrimaryColor = color;
            });
          },
        ),
        SizedBox(height: 16),
        Text('我的消息气泡颜色', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        _buildColorPicker(
          '我的消息气泡颜色',
          _customSelfMessageColor,
          (color) {
            setState(() {
              _customSelfMessageColor = color;
            });
          },
        ),
        SizedBox(height: 16),
        Text('对方消息气泡颜色', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        _buildColorPicker(
          '对方消息气泡颜色',
          _customOtherMessageColor,
          (color) {
            setState(() {
              _customOtherMessageColor = color;
            });
          },
        ),
        SizedBox(height: 16),
        SwitchListTile(
          title: Text('深色模式'),
          value: _customIsDark,
          onChanged: (value) {
            setState(() {
              _customIsDark = value;
            });
          },
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isCreatingCustomTheme = false;
                });
              },
              child: Text('取消'),
            ),
            SizedBox(width: 16),
            ElevatedButton(
              onPressed: _saveCustomTheme,
              child: Text('保存'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPicker(String title, Color currentColor, Function(Color) onColorChanged) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: onColorChanged,
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsv,
                  pickerAreaBorderRadius: BorderRadius.circular(8),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('确定'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: currentColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '点击选择颜色',
            style: TextStyle(
              color: ThemeData.estimateBrightnessForColor(currentColor) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
