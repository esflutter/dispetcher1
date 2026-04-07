import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Базовая сетка отступов из макета (Figma 375 dp).
/// Все значения масштабируются через flutter_screenutil.
class AppSpacing {
  AppSpacing._();

  static double get xxs => 4.w;
  static double get xs => 8.w;
  static double get sm => 12.w;
  static double get md => 16.w; // основной горизонтальный отступ экрана
  static double get lg => 20.w;
  static double get xl => 24.w;
  static double get xxl => 32.w;
  static double get xxxl => 40.w;

  static double get screenH => 16.w; // канонический горизонтальный паддинг

  static double get radiusS => 8.r;
  static double get radiusM => 12.r;
  static double get radiusL => 16.r;
  static double get radiusXL => 20.r;
  static double get radiusPill => 100.r;
}
