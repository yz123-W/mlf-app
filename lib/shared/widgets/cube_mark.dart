import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 面立方立体方块 Logo（近似还原原型 CSS 3D 立方体）。
class CubeMark extends StatelessWidget {
  const CubeMark({super.key, this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 顶面
          Positioned(
            left: size * 0.19,
            top: size * 0.02,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.skewX(-math.pi / 5.5),
              child: Container(
                width: size * 0.72,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: const Color(0xFF80A1FF),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(size * 0.18),
                    bottom: Radius.circular(size * 0.05),
                  ),
                ),
              ),
            ),
          ),
          // 侧面
          Positioned(
            right: size * 0.04,
            top: size * 0.13,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.skewY(-math.pi / 6),
              child: Container(
                width: size * 0.32,
                height: size * 0.66,
                decoration: BoxDecoration(
                  color: AppColors.wine,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(size * 0.2),
                    bottomRight: Radius.circular(size * 0.16),
                    topLeft: Radius.circular(size * 0.06),
                  ),
                ),
              ),
            ),
          ),
          // 正面
          Positioned(
            left: size * 0.15,
            top: size * 0.22,
            child: Container(
              width: size * 0.62,
              height: size * 0.6,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF164BCC), Color(0xFF002B99)],
                ),
                borderRadius: BorderRadius.circular(size * 0.12),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Text(
                '面',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
