// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/ble_controller.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'language_selection_screen.dart';
import 'sign_up_screen.dart';
import 'main_chat_screen.dart';
import 'ble_scan_screen.dart';
import 'user_profile_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/common_bottom_nav_bar.dart'; // ✅ إضافة استيراد الـ CommonBottomNavBar

// ------------------------------------------------------------------------
// 🎨 Custom Colors - مطابقة للألوان المطلوبة وتصميم Figma
// ------------------------------------------------------------------------
const Color accentColor = Color(0xFFFFB267); // اللون البرتقالي المميز
const Color darkBackgroundPrimary = Color(0xFF292625); // لون خلفية المجموعة
const Color darkBackgroundSecondary = Color(0xFF1B1818); // لون الخلفية الرئيسية (#1B1818)
const Color primaryTextColor = Color(0xFFF8F8F8);
const Color secondaryTextColor = Color(0xFF757575); // لون الخط الفاصل (#757575)
const Color logoutColor = Color(0xFFF44336);
const Color neonColor = Color(0xFFFFB267);
const Color navBarColor = Color(0xFF191616); // لون شريط التنقل

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggingOut = false;
  late BleController _bleController;

  // ✅ نصوص ثابتة للتعريب
  final Map<String, String> _arTexts = {
    'settings_title': 'الإعدادات',
    'account_section': 'الحساب',
    'medical_profile_section': 'الملف الطبي',
    'language_section': 'اللغة',
    'updates_section': 'التحديثات',
    'help_feedback_section': 'المساعدة والدعم',
    'about_lumos_section': 'حول لوموس',
    'logout_section': 'تسجيل الخروج',
    'status_listening': 'جارٍ الاستماع إليك...',
    'status_processing': 'جارٍ معالجة الأمر...',
    // ... (المزيد من النصوص المطلوبة)
  };

  @override
  void initState() {
    super.initState();
    _bleController = Get.find<BleController>();
  }

  // منطق المصادقة البيومترية (تم تبسيطه لعدم وجوده في تصميم المجموعة الجديد)
  Future<void> _toggleBiometricAuth() async {
    // منطق مصادقة مؤقت
    Get.snackbar(
      'الأمان',
      'سيتم تحديث حالة المصادقة البيومترية لاحقاً.',
      backgroundColor: neonColor.withOpacity(0.8),
      colorText: darkBackgroundSecondary,
    );
  }

  // ------------------------------------------------------------------------
  // منطق تسجيل الخروج (لم يتغير)
  // ------------------------------------------------------------------------
  Future<void> _logout() async {
    setState(() { _isLoggingOut = true; });

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkBackgroundPrimary,
          title: Text(_arTexts['logout_section']!, style: const TextStyle(color: neonColor)),
          content: Text('هل أنت متأكد من تسجيل الخروج؟', style: const TextStyle(color: primaryTextColor)),
          actions: <Widget>[
            TextButton(child: Text('لا', style: const TextStyle(color: primaryTextColor)), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: Text('نعم', style: const TextStyle(color: logoutColor)), onPressed: () => Navigator.of(context).pop(true)),
          ],
        );
      },
    );

    setState(() { _isLoggingOut = false; });

    if (confirmed == true) {
      // await _bleController.speak('logging_out_message'.tr); // تم التعليق أو الحذف لتسريع الاختبار
      await _bleController.clearUserProfileAndLogout();
      Get.offAll(() => const SignUpScreen());
    }
  }

  // ------------------------------------------------------------------------
  // UI Helpers: Bottom Navigation Bar (تم حذف الدالة القديمة واستبدالها بالـ CommonBottomNavBar)
  // ------------------------------------------------------------------------

  // ------------------------------------------------------------------------
  // 🎨 UI Helpers: Settings Item (الصف الداخلي)
  // ------------------------------------------------------------------------
  Widget _buildGroupItemRow({
    required String titleKey,
    required VoidCallback onTap,
    bool isLast = false,
    Color textColor = primaryTextColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // العنوان
                Text(
                  titleKey.tr,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // السهم (إذا لم يكن تسجيل خروج)
                if (titleKey != 'logout_section')
                  Icon(Icons.arrow_forward_ios, color: primaryTextColor.withOpacity(0.5), size: 16),
              ],
            ),
          ),
          // خط فاصل بلون #757575
          if (!isLast)
            Divider(
              color: secondaryTextColor.withOpacity(0.5),
              height: 1,
              thickness: 0.5,
              indent: 20,
              endIndent: 20,
            ),
        ],
      ),
    );
  }

  // 🎨 UI Helpers: Settings Group (الحاوية الكبيرة المستديرة)
  Widget _buildSettingsGroup({
    required List<Widget> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 40, left: 30, right: 30),
      width: 330,
      decoration: BoxDecoration(
        color: darkBackgroundPrimary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.2), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  }


  // ------------------------------------------------------------------------
  // شاشة البناء الرئيسية
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // ✅ تعيين الخلفية الرئيسية للشاشة بأكملها
        backgroundColor: darkBackgroundSecondary,

        // ✅ استبدال شريط التنقل السفلي بالـ CommonBottomNavBar
        bottomNavigationBar: const CommonBottomNavBar(currentIndex: 3),

        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.zero, // لا توجد حاجة لـ padding إضافي هنا
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 70),

                  // ✅ العنوان "الإعدادات"
                  Text(
                    _arTexts['settings_title']!,
                    style: const TextStyle(
                      color: primaryTextColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // المجموعة الرئيسية التي تضم كل العناصر
                  _buildSettingsGroup(
                    items: [
                      _buildGroupItemRow(
                        titleKey: 'account_section',
                        onTap: () => Get.to(() => const UserProfileScreen()),
                        isLast: false,
                      ),
                      _buildGroupItemRow(
                        titleKey: 'medical_profile_section',
                        onTap: () => Get.to(() => const UserProfileScreen()),
                        isLast: false,
                      ),
                      _buildGroupItemRow(
                        titleKey: 'language_section',
                        onTap: () => Get.to(() => const LanguageSelectionScreen()),
                        isLast: false,
                      ),
                      _buildGroupItemRow(
                        titleKey: 'updates_section',
                        onTap: () => launchUrl(Uri.parse('https://example.com/updates')),
                        isLast: false,
                      ),
                      _buildGroupItemRow(
                        titleKey: 'help_feedback_section',
                        onTap: () => launchUrl(Uri.parse('https://example.com/support')),
                        isLast: false,
                      ),
                      _buildGroupItemRow(
                        titleKey: 'about_lumos_section',
                        onTap: () => launchUrl(Uri.parse('https://example.com/about')),
                        isLast: false,
                      ),
                      // Log Out
                      _buildGroupItemRow(
                        titleKey: 'logout_section',
                        onTap: _logout,
                        textColor: logoutColor,
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // شاشة التحميل/الاستماع العائمة
            if (Get.find<BleController>().isListening || _isLoggingOut)
              Container(
                color: Colors.black.withOpacity(0.8),
                constraints: const BoxConstraints.expand(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: neonColor),
                      const SizedBox(height: 20),
                      Text(
                        Get.find<BleController>().isListening
                            ? _arTexts['status_listening']!
                            : _arTexts['status_processing']!,
                        style: const TextStyle(color: primaryTextColor, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// نموذج LocalAuth بسيط
class LocalAuth {
  final _auth = LocalAuthentication();
  Future<bool> isBiometricsAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    if (!canCheck) return false;
    final available = await _auth.getAvailableBiometrics();
    return available.isNotEmpty;
  }
  Future<bool> authenticate(String reason) async {
    return _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ));
  }
}