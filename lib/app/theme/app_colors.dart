import 'package:flutter/material.dart';

/// 面立方设计系统色板 —— 白色基底版。
///
/// 页面与卡片统一纯白，深蓝 `#002B99` 承担主操作与信息层级，
/// 酒红 `#6B001B` 只作“印章式”强调（分数、等级、红点、录音等强状态）。
class AppColors {
  AppColors._();

  /// 品牌主色（深蓝）
  static const Color blue = Color(0xFF002B99);

  /// 主色亮阶（进度条等渐变端）
  static const Color blue2 = Color(0xFF2C55E0);

  /// 蓝色雾面底（选中态、标签底）
  static const Color blueSoft = Color(0xFFEEF2FF);

  /// 强调色（酒红）
  static const Color wine = Color(0xFF6B001B);

  /// 酒红雾面底
  static const Color wineSoft = Color(0xFFF7ECF0);

  /// 页面底色（白色基底；历史常量名保留，已是纯白）
  static const Color cream = Color(0xFFFFFFFF);

  /// 卡片底色（纯白）
  static const Color white = Color(0xFFFFFFFF);

  /// 正文
  static const Color ink = Color(0xFF111827);

  /// 次要文字
  static const Color muted = Color(0xFF6B7280);

  /// 更弱的提示文字
  static const Color soft = Color(0xFF9AA1AE);

  /// 成功/正向
  static const Color mint = Color(0xFFE8F5EE);
  static const Color success = Color(0xFF18754D);

  /// 提示/暖色
  static const Color orange = Color(0xFFFFB36B);

  /// 危险
  static const Color danger = Color(0xFFDC3150);

  /// 分隔线 / 描边（浅灰细线）
  static const Color line = Color(0xFFE8EBF2);

  /// 主按钮（收敛为纯蓝，不再使用三段渐变）
  static const LinearGradient primaryButton = LinearGradient(
    colors: [blue, blue],
  );

  /// 品牌深色渐变 —— 仅供开屏 / 生成中这类全屏过渡场景使用。
  /// 白色基底页面里的卡片不再使用它。
  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF001B61), Color(0xFF002B99), Color(0xFF4F0A3A)],
    stops: [0.0, 0.48, 1.0],
  );
}
