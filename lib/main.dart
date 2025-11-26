// lib/main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

// ✅ الإستيرادات الضرورية للشاشات والخدمات
import 'screens/local_auth_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/sign_up_screen.dart';
import 'utils/app_translations.dart';
import 'services/ble_controller.dart';
import 'models/user_profile.dart';
// 🆕 استيراد شاشة اختيار الصوت
import 'screens/voice_selection_screen.dart';

// ⚠️ شاشة الملف الطبي الوهمية (يجب استبدالها بشاشتك الفعلية لاحقًا)
class MedicalProfileScreen extends StatelessWidget {
  const MedicalProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('medical_profile_title'.tr, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFB267)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'medical_profile_completion_prompt'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // 1. ⚠️ يجب إضافة منطق حفظ بيانات الملف الطبي هنا
                  // 2. الانتقال إلى شاشة البصمة لتأكيد التسجيل النهائي قبل الشاشة الرئيسية
                  // هذا يحقق: "بصمه تاكيد التسجيل بروفايل"
                  Get.offAll(() => const LocalAuthScreen(nextRoute: AuthNextRoute.profileConfirmation));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB267),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('confirm_profile_button'.tr, style: const TextStyle(color: Colors.black, fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ⚠️ يجب التأكد من وجود هذه الشاشة لاستخدامها كمسار افتراضي للمسجلين
class MainChatScreen extends StatelessWidget {
  const MainChatScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat Screen')),
      body: Center(child: Text('Welcome Back to Lumos!')),
    );
  }
}

// ====================================================================
// 🚀 دالة تهيئة الإطلاق والتحقق من حالة المستخدم
// ====================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // تهيئة متحكمات GetX
  final bleController = Get.put(BleController(prefs: prefs));
  Get.put(bleController, permanent: true);

  // 4. تحديد الشاشة الأولية بناءً على حالة المستخدم:
  final AuthNextRoute initialNextRoute;
  final UserProfile? userProfile = bleController.userProfile; // 🔑 الوصول الآمن للملف

  final initialLocale = Locale(userProfile?.localeCode.split('-').first ?? 'ar', userProfile?.localeCode.split('-').last ?? 'SA');

  // A. المستخدم الجديد (إذا لم يكن هناك ملف مستخدم أو الاسم فارغ): يبدأ ببوابة المصادقة التي تذهب لشاشة اللغة
  if (userProfile == null || userProfile.fullName.isEmpty) { // 🔑 FIX: استخدام التحقق الآمن من null
    // التسلسل: بصمة -> لغة -> صوت -> تسجيل
    initialNextRoute = AuthNextRoute.languageSelection;
  }
  // B. المستخدم المسجل: يبدأ ببوابة المصادقة التي تذهب للشاشة الرئيسية/التحقق
  else {
    // التسلسل: بصمة -> التحقق من اكتمال الملف -> رئيسية/ملف طبي
    initialNextRoute = AuthNextRoute.mainScreen;
  }

  // شاشة البداية هي دائما LocalAuthScreen مع المسار المناسب
  final initialScreen = LocalAuthScreen(nextRoute: initialNextRoute); // 🔑 تهيئة الشاشة هنا

  runApp(MyApp(
    initialScreen: initialScreen,
    initialLocale: initialLocale,
  ));
}

// ====================================================================
// 🎨 هيكل التطبيق الرئيسي
// ====================================================================
class MyApp extends StatelessWidget {
  final Widget initialScreen;
  final Locale initialLocale;

  const MyApp({
    super.key,
    required this.initialScreen,
    required this.initialLocale,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Lumos Assistant',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US'),

      theme: ThemeData(
        fontFamily: 'NeoSansArabic',
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFFB267),
        scaffoldBackgroundColor: Colors.black,
      ),

      home: initialScreen,

      // 💡 تعريف المسارات (Routes) عبر GetX
      getPages: [
        GetPage(name: '/auth-gate', page: () => const LocalAuthScreen(nextRoute: AuthNextRoute.mainScreen)),
        GetPage(name: '/lang-select', page: () => const LanguageSelectionScreen()),
        GetPage(name: '/voice-select', page: () => const ChooseVoiceScreen()), // 🆕 مسار اختيار الصوت
        GetPage(name: '/signup', page: () => const SignUpScreen()),
        GetPage(name: '/medical-profile', page: () => const MedicalProfileScreen()), // 🆕 مسار الملف الطبي
        GetPage(name: '/main', page: () => const MainChatScreen()),
      ],
    );
  }
}