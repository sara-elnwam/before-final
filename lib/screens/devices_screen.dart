// lib/screens/devices_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../services/ble_controller.dart';
import '../widgets/common_bottom_nav_bar.dart';

// ✅ افترض وجود هذه الشاشات للتنقل، وإلا ستحتاج إلى إنشائها
import 'earpods_screen.dart';
import 'glasses_screen.dart';
import 'cane_screen.dart';
import 'bracelet_screen.dart';

// الألوان المستخدمة (لضمان التناسق)
const Color neonColor = Color(0xFFFFB267);
const Color darkBackground = Color(0xFF000000);
const Color onBackground = Colors.white;
const Color cardColor = Color(0xFF282424); // لون خلفية البطاقة


class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  // ------------------------------------------------------------------------
  // ✅ بناء بطاقة الجهاز (Card Item)
  // ------------------------------------------------------------------------
  Widget _buildDeviceCard({
    required IconData icon,
    required String titleKey,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: neonColor, size: 30),
                const SizedBox(width: 20),
                Text(
                  titleKey.tr, // يتم ترجمة العنوان هنا
                  style: const TextStyle(
                    color: onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, color: onBackground, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // يجب الحصول على المتحكم هنا
    final bleController = Get.find<BleController>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: darkBackground,

        // ✅ شريط التنقل السفلي (مع تعيين الاندكس على 1)
        bottomNavigationBar: const CommonBottomNavBar(currentIndex: 1),

        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ➡️ العنوان
              Padding(
                padding: const EdgeInsets.only(top: 20, right: 30, bottom: 20),
                child: Text(
                  'devices_title'.tr, // يجب أن تكون 'devices_title' معرفة في ملفات التعريب
                  style: const TextStyle(
                    color: onBackground,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // --------------------------------
              // 1. سماعات الأذن (Earpods)
              _buildDeviceCard(
                icon: FluentIcons.headphones_20_filled,
                titleKey: 'earpods_device_name'.tr,
                onTap: () {
                  bleController.stopListening(shouldSpeakStop: false);
                  Get.to(() => const EarpodsScreen());
                },
              ),

              // 2. النظارات (Glasses)
              _buildDeviceCard(
                icon: FluentIcons.glasses_20_filled,
                titleKey: 'glasses_device_name'.tr,
                onTap: () {
                  bleController.stopListening(shouldSpeakStop: false);
                  Get.to(() => const GlassesScreen());
                },
              ),

              // 3. العصا (Cane)
              _buildDeviceCard(
                icon: FluentIcons.navigation_20_filled, // رمز تقريبي للعصا
                titleKey: 'cane_device_name'.tr,
                onTap: () {
                  bleController.stopListening(shouldSpeakStop: false);
                  Get.to(() => const CaneScreen());
                },
              ),

              // 4. السوار (Bracelet)
              _buildDeviceCard(
                // ✅ تم التصحيح إلى أيقونة Material
                icon: Icons.watch_rounded,
                titleKey: 'bracelet_device_name'.tr,
                onTap: () {
                  bleController.stopListening(shouldSpeakStop: false);
                  Get.to(() => const BraceletScreen());
                },
              ),
              // --------------------------------
            ],
          ),
        ),
      ),
    );
  }
}