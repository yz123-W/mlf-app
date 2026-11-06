import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

/// 主外壳：底部 5 栏导航（首页 / 题库 / 面 / 岗位 / 我的）。
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _item(0, Icons.home_outlined, Icons.home, '首页'),
                _item(1, Icons.menu_book_outlined, Icons.menu_book, '题库'),
                _center(),
                _item(3, Icons.work_outline, Icons.work, '岗位'),
                _item(4, Icons.account_circle_outlined, Icons.account_circle, '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label) {
    final active = navigationShell.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goBranch(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, size: 21, color: active ? AppColors.blue : const Color(0xFF8D91A0)),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? AppColors.blue : const Color(0xFF8D91A0),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? AppColors.wine : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _center() {
    final active = navigationShell.currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goBranch(2),
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 47,
                height: 47,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(17),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: AppColors.cream, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22002B99), blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: const Text('面',
                    style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, height: 1)),
              ),
              const SizedBox(height: 2),
              Text(
                '面',
                style: TextStyle(
                  fontSize: 10,
                  color: active ? AppColors.blue : const Color(0xFF8D91A0),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
