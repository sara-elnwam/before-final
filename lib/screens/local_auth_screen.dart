// screens/local_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ نحتاج هذا لحفظ حالة الدخول

import '../services/ble_controller.dart';
import 'main_chat_screen.dart';
import 'sign_up_screen.dart'; // ✅ الاستيراد لشاشة التسجيل
import 'language_selection_screen.dart';
import 'voice_selection_screen.dart';
import 'registration_screen.dart'; // لتأكيد إكمال الملف الطبي

// Custom Colors
const Color accentColor = Color(0xFFFFB267);
const Color _screenBackground = Colors.black;

// ✅ المحدد الجديد لتحديد المسار التالي بعد المصادقة
enum AuthNextRoute {
  languageSelection,
  mainScreen,
  logoutConfirm,
  profileConfirmation,
  voiceSelection,
  // 🆕 الحالة المضافة: للانتقال إلى شاشة تسجيل حساب جديد
  signUp,
}

class LocalAuthScreen extends StatefulWidget {
  final AuthNextRoute nextRoute;
  final String? customRoute;

  const LocalAuthScreen({
    super.key,
    required this.nextRoute,
    this.customRoute,
  });

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isProcessing = true;
  late BleController _bleController;

  @override
  void initState() {
    super.initState();
    _bleController = Get.find<BleController>();
    _checkBiometrics();
    // 📢 تفعيل TTS لطلب المصادقة
    Future.delayed(const Duration(milliseconds: 500), () {
      _bleController.speak('local_auth_reason'.tr);
    });
  }

  // ----------------------------------------------------------------------
  // 🔐 منطق المصادقة
  // ----------------------------------------------------------------------

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      if (kDebugMode) print("Error checking biometrics: $e");
      canCheckBiometrics = false;
    }

    if (!mounted) return;

    setState(() {
      _canCheckBiometrics = canCheckBiometrics;
    });

    if (_canCheckBiometrics) {
      _authenticate();
    } else {
      // ⚠️ في حالة عدم توفر البصمة، ننتقل مباشرة حسب المسار المحدد
      if (kDebugMode) print("Biometrics not available. Skipping authentication.");
      _navigateAfterAuth(widget.nextRoute);
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() => _isProcessing = true);
      authenticated = await auth.authenticate(
        localizedReason: 'local_auth_instruction'.tr,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      setState(() => _isProcessing = false);

      if (authenticated) {
        _navigateAfterAuth(widget.nextRoute);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) print("Authentication error: $e");
      setState(() => _isProcessing = false);
    }
  }

  // ----------------------------------------------------------------------
  // 🗺️ منطق التنقل بعد المصادقة
  // ----------------------------------------------------------------------

  void _navigateAfterAuth(AuthNextRoute route) async {
    switch (route) {
      case AuthNextRoute.languageSelection:
      // المسار الأولي للمستخدم الجديد: الانتقال إلى اختيار اللغة
        Get.offAll(() => const LanguageSelectionScreen());
        break;

      case AuthNextRoute.voiceSelection:
      // الانتقال لاختيار الصوت بعد اختيار اللغة
        Get.offAll(() => const ChooseVoiceScreen());
        break;

      case AuthNextRoute.signUp:
      // ✅ التعديل الجديد: الانتقال إلى شاشة التسجيل
        Get.offAll(() => const SignUpScreen());
        break;

      case AuthNextRoute.profileConfirmation:
      // حفظ حالة إكمال الإعداد الأولي وتسجيل الدخول
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_run_setup', true);
        await prefs.setBool('is_logged_in', true);
        Get.offAll(() => const MainChatScreen());
        break;

      case AuthNextRoute.mainScreen:
      // تسجيل دخول لحساب موجود
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        Get.offAll(() => const MainChatScreen());
        break;

      case AuthNextRoute.logoutConfirm:
      // أمر تسجيل خروج مؤكد
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);
        // 📢 أمر TTS لتأكيد الخروج
        _bleController.speak('logout_confirmed'.tr);
        Get.offAll(() => const SignUpScreen());
        break;
    }
  }

  // ----------------------------------------------------------------------
  // 🎨 واجهة المستخدم (UI) Build - لم يتم تعديلها
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💡 مؤشر تحميل بسيط عند فحص توفر البصمة
            if (_isProcessing)
              const CircularProgressIndicator(color: accentColor),

            const SizedBox(height: 20),

            // 🔑 العنوان الرئيسي (Lumus Authentication)
            Text(
              'local_auth_title_new'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: accentColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // 🔑 رسالة الترحيب
            Text(
              'local_auth_welcome'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 40),

            // 🔒 أيقونة البصمة


          ],
        ),
      ),
    );
  }
}