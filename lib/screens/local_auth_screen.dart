// screens/local_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/ble_controller.dart';
import 'main_chat_screen.dart'; // ✅ يجب استيراد الشاشة الرئيسية
import 'sign_up_screen.dart'; // ✅ يجب استيراد شاشة التسجيل
import 'language_selection_screen.dart'; // ✅ يجب استيراد شاشة اللغة

// Custom Colors
const Color accentColor = Color(0xFFFFB267);
const Color onBackground = Color(0xFFF8F8F8);

// ✅ المحدد الجديد لتحديد المسار التالي بعد المصادقة
enum AuthNextRoute {
  // 1. للمستخدم الجديد: Auth -> Language Selection
  languageSelection,
  // 2. للتسجيل الدخول العادي: Auth -> Check Profile Status -> Main / Medical Profile
  mainScreen,
  // 3. لتأكيد عملية معينة (مثل تسجيل الخروج)
  logoutConfirm,
  // 4. ✅ NEW: لتأكيد إكمال الملف الطبي/الشخصي (الخطوة الأخيرة قبل الرئيسية)
  profileConfirmation,
}

class LocalAuthScreen extends StatefulWidget {
  final AuthNextRoute nextRoute;
  const LocalAuthScreen({super.key, required this.nextRoute});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  late final BleController _bleController;

  bool _isAuthenticated = false;
  bool _isProcessing = true;
  bool _biometricsAvailable = false;
  Color _screenBackground = Colors.black;

  @override
  void initState() {
    super.initState();
    // ✅ استرداد الـ Controller من GetX
    _bleController = Get.find<BleController>();
    _checkBiometricsAndAuthenticate();
  }

  Future<void> _checkBiometricsAndAuthenticate() async {
    // 1. فحص توفر البصمة
    _biometricsAvailable = await _isBiometricsAvailable();

    if (!_biometricsAvailable) {
      // 💡 إذا لم تكن البصمة متاحة: نذهب فوراً للمسار التالي (افتراضياً، البصمة اختيارية)
      _bleController.speak('auth_not_available_proceeding'.tr); // نص: المصادقة غير متاحة. انتقال للشاشة التالية.
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      _navigateToNextRoute(widget.nextRoute);
      return;
    }

    // 2. إذا كانت متاحة، نقوم ببدء المصادقة
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    // 💡 تأخير بسيط لإعطاء الـ UI فرصة للتحميل
    Future.delayed(const Duration(milliseconds: 500), () {
      _authenticate();
    });
  }

  Future<bool> _isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException catch (e) {
      // 💡 التعامل مع الأخطاء التي قد تمنع فحص البصمة
      debugPrint('Biometrics check error: $e');
      return false;
    }
  }

  Future<void> _authenticate() async {
    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }
    // ✅ نطق طلب المصادقة (إذا كانت ميزة النطق متاحة)
    _bleController.speak('auth_required_prompt'.tr);

    // 💡 إضافة تأثير اهتزاز خفيف (Haptic Feedback)
    await HapticFeedback.selectionClick();

    final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'auth_reason'.tr,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // 💡 نستخدم false لتدعم رمز المرور (Passcode) كبديل للبيومتري
          biometricOnly: false,
        ));

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    if (didAuthenticate) {
      // 🚀 النجاح: التنقل بناءً على nextRoute
      _navigateToNextRoute(widget.nextRoute);
    } else {
      // 🛑 الفشل أو الإلغاء: تم توجيه المستخدم بطريقة خاطئة سابقاً.
      _handleAuthFailure();
    }
  }

  // ----------------------------------------------------------------------
  // ⚙️ Navigation Helpers
  // ----------------------------------------------------------------------

  void _navigateToNextRoute(AuthNextRoute nextRoute) {
    if (nextRoute == AuthNextRoute.logoutConfirm) {
      // حالة خاصة: لا تنتقل، بل قم بتنفيذ مهمة ثم أعد المستخدم للشاشة الرئيسية
      _bleController.speak('logout_confirmed'.tr);
      // 💡 هنا يجب وضع منطق تسجيل الخروج الفعلي
      Get.offAll(() => const SignUpScreen());
      return;
    }

    switch (nextRoute) {
      case AuthNextRoute.languageSelection:
        Get.offAll(() => const LanguageSelectionScreen());
        break;
      case AuthNextRoute.mainScreen:
      case AuthNextRoute.profileConfirmation:
      // ✅ المسار الصحيح: بعد المصادقة الناجحة، يذهب إلى MainChatScreen
        Get.offAll(() => const MainChatScreen());
        break;
      default:
      // مسار احتياطي
        Get.offAll(() => const MainChatScreen());
    }
  }

  void _handleAuthFailure() {
    // 🛑 FIX: بدلاً من العودة لشاشة التسجيل (SignUpScreen) في كل الحالات،
    // نتحقق مما إذا كان الهدف هو الانتقال للشاشة الرئيسية بعد إكمال الملف الشخصي.
    if (widget.nextRoute == AuthNextRoute.mainScreen || widget.nextRoute == AuthNextRoute.profileConfirmation) {
      // ✅ إذا كان الهدف هو الشاشة الرئيسية (بعد حفظ الملف الطبي)،
      // نذهب للشاشة الرئيسية لمنع إعادة المستخدم لبداية عملية التسجيل.
      // 💡 يجب إضافة هذا النص 'auth_failure_proceeding_to_main_screen' في ملفات التعريب
      _bleController.speak('auth_failure_proceeding_to_main_screen'.tr);
      Get.offAll(() => const MainChatScreen());
    } else {
      // 🛑 للحالات الأخرى (مثل محاولة تسجيل الدخول الأولية)، يتم العودة لشاشة التسجيل.
      // 💡 يجب إضافة هذا النص 'auth_failure_reverting_to_signup' في ملفات التعريب
      _bleController.speak('auth_failure_reverting_to_signup'.tr);
      Get.offAll(() => const SignUpScreen());
    }
  }

  // ----------------------------------------------------------------------
  // 🎨 UI Build
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BleController>(
      init: _bleController,
      builder: (bleController) {
        // ... (كود الـ UI المتبقي)
        return GestureDetector(
          // ... (كود GestureDetector)
          child: Container(
            color: _screenBackground,
            constraints: const BoxConstraints.expand(),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // شاشة المعالجة (التحميل المرئي الوحيد)
                  if (_isProcessing)
                    const Column(
                      children: [
                        CircularProgressIndicator(color: accentColor),
                        SizedBox(height: 20),
                        // ❌ تم إزالة نص 'loading_message'
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}