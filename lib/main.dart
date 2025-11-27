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

// 🔑 FIX: استيراد شاشة الصوت وإخفاء AssistantVoice لتجنب تضارب النوع
import 'screens/voice_selection_screen.dart' hide AssistantVoice;
// 🔑 FIX: يجب استيراد enum AssistantVoice لتهيئة TTS في main
import 'package:blind/enums/assistant_voice.dart';


// ====================================================================
// 🆕 شاشة البداية (Splash Screen) - تعرض الصورة لمدة ثانيتين
// ====================================================================

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // الانتقال إلى الشاشة التالية بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
      Get.offAll(() => widget.nextScreen);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black, // خلفية سوداء لتناسب تصميمك
      body: Center(
        // 🔑 استخدام الصورة الموجودة في assets/images/UI.png
        // (تأكد من إضافة المسار في ملف pubspec.yaml)
        child: Image(
          image: AssetImage('assets/images/UI.png'),
          fit: BoxFit.cover, // يغطي الشاشة أو يتم تعديله ليناسب رؤيتك
        ),
      ),
    );
  }
}


// ⚠️ شاشة الملف الطبي الوهمية
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

// ⚠️ شاشة الدردشة الرئيسية الوهمية
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
// 🚀 دالة تهيئة الإطلاق والتحقق من حالة المستخدم (مع التعديل)
// ====================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // تهيئة متحكمات GetX
  final bleController = Get.put(BleController(prefs: prefs));
  Get.put(bleController, permanent: true);

  // 🔑 1. تحديد اللغة الأولية (لغة الجهاز)
  final UserProfile? userProfile = bleController.userProfile;
  String languageCode = userProfile?.localeCode.split('-').first ??
      ui.window.locale.languageCode;

  // التحقق من الدعم وتعيين الافتراضي (ar أو en)
  if (languageCode != 'ar' && languageCode != 'en') {
    languageCode = 'en';
  }
  String fullLocaleCode = languageCode == 'ar' ? 'ar-SA' : 'en-US';

  // 🔑 2. تهيئة TTS/STT باللغة المكتشفة قبل عرض أي شاشة
  // هذا يضمن أن LocalAuthScreen تنطق باللغة الصحيحة فوراً. (شرط التدريب)
  await bleController.setLocaleAndTTS(fullLocaleCode, AssistantVoice.male);

  // 🔑 3. ضبط الـ Locale في GetX
  final initialLocale = Locale(languageCode, languageCode == 'ar' ? 'SA' : 'US');

  // 4. تحديد المسار الذي يجب أن تذهب إليه شاشة البصمة (LocalAuthScreen) بعد نجاح المصادقة
  final AuthNextRoute authSuccessRoute;

  // A. المستخدم الجديد (إذا لم يكن هناك ملف مستخدم أو الاسم فارغ):
  if (userProfile == null || userProfile.fullName.isEmpty) {
    // التسلسل: بصمة -> لغة -> صوت -> تسجيل (كما تم التحديد)
    authSuccessRoute = AuthNextRoute.languageSelection;
  }
  // B. المستخدم المسجل:
  else {
    // بما أن المستخدم مسجل، شاشة البصمة ستنقله مباشرة للشاشة الرئيسية
    authSuccessRoute = AuthNextRoute.mainScreen;
  }

  // 1. الشاشة التالية بعد البداية (Splash) هي شاشة البصمة (LocalAuthScreen)
  final nextAuthScreen = LocalAuthScreen(nextRoute: authSuccessRoute);

  // 2. شاشة البداية هي الآن الـ SplashScreen التي تنتقل تلقائيًا
  final initialScreen = SplashScreen(nextScreen: nextAuthScreen);

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
        GetPage(name: '/voice-select', page: () => const ChooseVoiceScreen()),
        GetPage(name: '/signup', page: () => const SignUpScreen()),
        GetPage(name: '/medical-profile', page: () => const MedicalProfileScreen()),
        GetPage(name: '/main', page: () => const MainChatScreen()),
      ],
    );
  }
}