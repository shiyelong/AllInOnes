import 'package:flutter/material.dart';

/// 小程序面板，支持最近/我的小程序、顶部推荐等分组
class MiniAppPanel extends StatelessWidget {
  final VoidCallback? onClose;
  const MiniAppPanel({this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    // 示例数据，可后续接入真实API
    final recentMiniApps = [
      {'icon': Icons.music_note, 'title': '音乐'},
      {'icon': Icons.graphic_eq, 'title': '音频'},
      {'icon': Icons.play_circle_outline, 'title': '热血(1).mp3'},
    ];
    final myMiniApps = [
      {'icon': Icons.favorite, 'title': '好活'},
      {'icon': Icons.school, 'title': '学习城'},
      {'icon': Icons.psychology, 'title': '深探心理'},
      {'icon': Icons.emoji_events, 'title': '龙考助学'},
      {'icon': Icons.gamepad, 'title': '音乐彩配'},
      {'icon': Icons.rocket_launch, 'title': '亚马逊科技'},
      {'icon': Icons.tag_faces, 'title': 'TCL快递'},
    ];
    return Material(
      color: Colors.black.withOpacity(0.35),
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text('最近', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  )
                ],
              ),
              // 最近小程序
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recentMiniApps.length,
                  separatorBuilder: (_, __) => SizedBox(width: 16),
                  itemBuilder: (ctx, i) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(recentMiniApps[i]['icon'] as IconData, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(recentMiniApps[i]['title'] as String, style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 16, bottom: 8),
                child: Text('我的小程序', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              // 我的
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: myMiniApps.length,
                  itemBuilder: (ctx, i) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.orange,
                        child: Icon(myMiniApps[i]['icon'] as IconData, color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(myMiniApps[i]['title'] as String, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
