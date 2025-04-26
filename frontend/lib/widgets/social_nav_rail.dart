import 'package:flutter/material.dart';

/// 左侧社交导航栏组件，可复用
class SocialNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  SocialNavRail({required this.selectedIndex, required this.onSelected});

  final List<String> _navTitles = [
    '聊天', '朋友圈', '广场', '好友', '小程序', '购物', '游戏', 'AI'
  ];
  final List<IconData> _navIcons = [
    Icons.chat_bubble_outline, Icons.camera, Icons.forum, Icons.people, Icons.apps, Icons.shopping_cart, Icons.videogame_asset, Icons.smart_toy
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算最大可显示的导航项数（减去头像、间距、底部按钮等高度）
        double availableHeight = constraints.maxHeight - 28 * 2 - 24 - 32 - 48; // 头像+间距+底部按钮+padding
        int maxNavCount = (availableHeight ~/ 64).clamp(2, _navTitles.length); // 每项大约64px
        bool needMore = _navTitles.length > maxNavCount;
        List<NavigationRailDestination> visibleDest = List.generate(
          needMore ? maxNavCount - 1 : _navTitles.length,
          (i) => NavigationRailDestination(
            icon: Icon(_navIcons[i]),
            label: Text(_navTitles[i]),
          ),
        );
        // 剩余项合并进“更多”菜单
        if (needMore) {
          visibleDest.add(
            NavigationRailDestination(
              icon: Icon(Icons.more_horiz),
              label: Text('更多'),
            ),
          );
        }
        return NavigationRail(
          selectedIndex: selectedIndex < visibleDest.length ? selectedIndex : 0,
          onDestinationSelected: (idx) {
            if (needMore && idx == visibleDest.length - 1) {
              // 弹出菜单显示剩余项
              showModalBottomSheet(
                context: context,
                builder: (ctx) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (int i = maxNavCount - 1; i < _navTitles.length; i++)
                      ListTile(
                        leading: Icon(_navIcons[i]),
                        title: Text(_navTitles[i]),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelected(i);
                        },
                      ),
                  ],
                ),
              );
            } else {
              onSelected(idx);
            }
          },
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                GestureDetector(
  onTap: () {
    // TODO: 打开头像选择/更换弹窗
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('更换头像'),
        content: Text('这里实现头像选择/上传功能'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
      ),
    );
  },
  child: CircleAvatar(
    radius: 28,
    backgroundColor: Colors.blue,
    child: Icon(Icons.person, color: Colors.white, size: 32),
  ),
),
                SizedBox(height: 24),
              ],
            ),
          ),
          destinations: visibleDest,
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Icon(Icons.grid_view_rounded, size: 32, color: Colors.black12),
          ),
          groupAlignment: -1.0,
        );
      },
    );
  }
}
