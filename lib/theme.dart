import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const primary = Color(0xFF2196F3);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    fontFamily: 'Noto Sans KR',
  );
}

class AppColors {
  AppColors._();
  static const available = Color(0xFF4CAF50);
  static const occupied = Color(0xFF2196F3);
  static const maintenance = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const owned = Color(0xFF9C27B0);
}

/// 충전기 종류별 식별 색상. 타일/카드 테두리, 지도 마커 테두리에 사용.
class ChargerColors {
  ChargerColors._();
  static const fast50 = Color(0xFFD32F2F);
  static const slow7 = Color(0xFFF9A825);
  static const slow3 = Color(0xFF388E3C);

  static Color forTypeId(String typeId) {
    switch (typeId) {
      case 'fast50':
        return fast50;
      case 'slow7':
        return slow7;
      case 'slow3':
        return slow3;
      default:
        return Colors.grey;
    }
  }

  static Color forBadgeClass(String badgeClass) {
    switch (badgeClass) {
      case 'fast':
        return fast50;
      case 'mid':
        return slow7;
      case 'slow':
        return slow3;
      default:
        return Colors.grey;
    }
  }
}
