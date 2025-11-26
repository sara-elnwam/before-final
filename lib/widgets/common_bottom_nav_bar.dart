// lib/widgets/common_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/ble_controller.dart';
import '../screens/main_chat_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/devices_screen.dart'; // ✅ استيراد الشاشة الجديدة

// تعريف الألوان المستخدمة (إذا لم تكن معرفة في مكان مركزي)
const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF1C1C1C);
const Color onBackground = Colors.white;


class CommonBottomNavBar extends StatelessWidget {
  // ✅ تمرير الاندكس الخاص بالشاشة الحالية
  final int currentIndex;

  const CommonBottomNavBar({super.key, required this.currentIndex});

  // 0: Home, 1: Add (Devices), 2: Profile, 3: Settings

  // ✅ بناء عنصر التنقل المفرد (مع الدائرة البرتقالية للأكتيف)
  Widget _buildBottomNavItem({
    required BleController bleController,
    required IconData icon,
    required int index,
    required VoidCallback onTap,
  }) {
    final isActive = index == currentIndex;

    // ✅ لون الأيقونة: أبيض دائماً كما طلبت
    const iconColor = onBackground;

    // ✅ لون الدائرة: برتقالي (neonColor) إذا كانت نشطة، شفاف إذا كانت غير نشطة
    final circleColor = isActive ? neonColor : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: circleColor,
        ),
        child: Icon(
          icon,
          size: 28,
          color: iconColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ يجب الحصول على Controller من GetX هنا لاستخدامه في الـ onTap
    final bleController = Get.find<BleController>();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      color: darkSurface.withOpacity(0.9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Home (الرئيسية) - Index 0
          _buildBottomNavItem(
            bleController: bleController,
            icon: Icons.home_outlined,
            index: 0,
            // الانتقال إلى الشاشة الرئيسية وإلغاء جميع الشاشات السابقة
            onTap: () => Get.offAll(() => const MainChatScreen()),
          ),
          // 2. Add (الأجهزة) - Index 1
          _buildBottomNavItem(
            bleController: bleController,
            icon: Icons.add,
            index: 1,
            // ✅ تم التعديل: التنقل إلى شاشة الأجهزة
            onTap: () => Get.to(() => const DevicesScreen()),
          ),
          // 3. Profile (الملف الشخصي) - Index 2
          _buildBottomNavItem(
            bleController: bleController,
            icon: Icons.person_outline,
            index: 2,
            onTap: () => Get.to(() => const UserProfileScreen()),
          ),
          // 4. Settings (الإعدادات) - Index 3
          _buildBottomNavItem(
            bleController: bleController,
            icon: Icons.settings,
            index: 3,
            // التنقل المباشر إلى شاشة الإعدادات
            onTap: () => Get.to(() => const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}