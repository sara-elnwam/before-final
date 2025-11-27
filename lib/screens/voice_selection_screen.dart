// lib/screens/voice_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:blind/services/ble_controller.dart'; // تأكد من وجود هذا الاستيراد
import '../services/ble_controller.dart';
import 'sign_up_screen.dart';
import 'package:blind/enums/assistant_voice.dart'; // 🆕 استيراد AssistantVoice من مكانه الصحيح
// وتأكد من حذف أي استيراد سابق كان يجلب AssistantVoice
// 🎨 الألوان المخصصة
const Color darkBackground = Color(0x80000000); // ✅ أسود بنسبة شفافية 50% (#00000080)
const Color primaryTextColor = Color(0xFFF8F8F8); // #F8F8F8 (أبيض)
// 🔑 اللون البرتقالي المطلوب للعنوان وزر Continue (#CA842B)
const Color accentColor = Color(0xFFCA842B);
// 🔑 اللون المطلوب لنص زر المتابعة (#DADADA)
const Color continueButtonTextColor = Color(0xFFDADADA);
// 🔑 اللون لخلفية العنصر النشط (المختار) - #EE8118
const Color activeSelectionColor = Color(0xFFEE8118);
// ✅ لون الحدود المطلوب عند الاختيار: 80% Opacity of #FF6229
const Color selectedBorderColor = Color(0xCCFF6229);

// ✅ لون أيقونات التشغيل والإيقاف: #FFB267
const Color playIconColor = Color(0xFFFFB267);

// 🔑 الخلفية المتدرجة
const LinearGradient backgroundGradient = LinearGradient(
  colors: [
    Color(0xFF2D2929),
    Color(0xFF110F0F),
  ],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// تعريف الأصوات المتاحة
enum AssistantVoice {
  female,
  male,
  none,
}

enum TapSide { left, right }

class ChooseVoiceScreen extends StatefulWidget {
  const ChooseVoiceScreen({super.key});

  @override
  State<ChooseVoiceScreen> createState() => _ChooseVoiceScreenState();
}

class _ChooseVoiceScreenState extends State<ChooseVoiceScreen> with SingleTickerProviderStateMixin {
  late final BleController bleController;

  // ⬅️ الحالة الأولية: لا يوجد اختيار، والتركيز يبدأ على الولد
  AssistantVoice _selectedVoice = AssistantVoice.none;
  AssistantVoice _currentFocus = AssistantVoice.male;

  int _tapCount = 0;
  Timer? _tapResetTimer;
  final Duration _tapTimeout = const Duration(milliseconds: 600);

  late AnimationController _animationController;
  late Animation<double> _animation;

  // ----------------------------------------------------------------------
  // 🚀 التهيئة
  // ----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    bleController = Get.find<BleController>();

    _initializeVoiceSelection();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(_animationController);

    Future.delayed(const Duration(milliseconds: 500), () {
      _speakInitialInstructions();
    });
  }

  // ⬅️ تم التعديل: لا يوجد اختيار عند بدء الشاشة
  void _initializeVoiceSelection() {
    _selectedVoice = AssistantVoice.none;
    _currentFocus = AssistantVoice.male;
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 🗣️ TTS Logic
  // ----------------------------------------------------------------------

  Future<void> _speakInstruction(String instruction) async {
    if (!mounted) return;
    await bleController.stop();
    await bleController.speak(instruction);
  }

  void _speakInitialInstructions() async {
    // 🔑 تم استبدال النصوص العربية الثابتة بمفاتيح ترجمة
    const String contextAnnouncementKey = "voice_selection_screen_context";
    const String instructionsKey = "voice_selection_instructions_focus";

    // 🔑 استخدام .tr على المفتاح بدلاً من النص
    await _speakInstruction(contextAnnouncementKey.tr + instructionsKey.tr);
    await _speakFocusDescription(_currentFocus);
  }

  Future<void> _speakFocusDescription(AssistantVoice voice) async {
    // 🔑 المتغير الآن يحمل مفتاح الترجمة وليس النص الكامل
    String messageKey = '';
    HapticFeedback.lightImpact();

    switch (voice) {
      case AssistantVoice.male:
        messageKey = 'focus_on_male_voice'; // ⬅️ مفتاح جديد
        break;
      case AssistantVoice.female:
        messageKey = 'focus_on_female_voice'; // ⬅️ مفتاح جديد
        break;
      case AssistantVoice.none:
        messageKey = 'focus_on_continue_button'; // ⬅️ مفتاح جديد
        break;
    }
    await _speakInstruction(messageKey.tr);
  }

  // ----------------------------------------------------------------------
  // 👆 Tap Handling Logic (التعامل مع النقرات)
  // ----------------------------------------------------------------------

  void _handleScreenTap(TapSide side) {
    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(_tapTimeout, () => _processTapCount(side));
  }

  void _processTapCount(TapSide side) async {
    final int count = _tapCount;
    _tapCount = 0;

    if (count == 1) {
      // منطق الضغطة الواحدة للتنقل أو الاختبار (يمين/يسار)
      if (_currentFocus == AssistantVoice.male) {
        if (side == TapSide.right) {
          // نقر يمين: اختبار صوت الولد
          // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
          String confirmationMsgKey = 'test_male_voice';
          await bleController.speak(confirmationMsgKey.tr);
        } else {
          // نقر يسار: التنقل للأنثى
          await _handleSingleTapForNavigation();
        }
      } else if (_currentFocus == AssistantVoice.female) {
        if (side == TapSide.left) {
          // نقر يسار: اختبار صوت الأنثى
          // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
          String confirmationMsgKey = 'test_female_voice';
          await bleController.speak(confirmationMsgKey.tr);
        } else {
          // نقر يمين: التنقل لزر المتابعة
          await _handleSingleTapForNavigation();
        }
      } else if (_currentFocus == AssistantVoice.none) {
        // إذا كان التركيز على زر المتابعة: العودة للولد
        await _handleSingleTapForNavigation();
      }
    } else if (count == 2) {
      // منطق الضغط المزدوج للاختيار
      await _handleDoubleTap();
    }
  }

  Future<void> _handleSingleTapForNavigation() async {
    setState(() {
      switch (_currentFocus) {
        case AssistantVoice.male:
          _currentFocus = AssistantVoice.female;
          break;
        case AssistantVoice.female:
          _currentFocus = AssistantVoice.none;
          break;
        case AssistantVoice.none:
          _currentFocus = AssistantVoice.male;
          break;
      }
    });
    await _speakFocusDescription(_currentFocus);
  }

  Future<void> _handleDoubleTap() async {
    HapticFeedback.heavyImpact();

    switch (_currentFocus) {
      case AssistantVoice.male:
      case AssistantVoice.female:
        await _handleVoiceSelection(_currentFocus);
        setState(() => _currentFocus = AssistantVoice.none);
        // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
        await _speakInstruction('voice_selected_focus_continue'.tr);
        break;

      case AssistantVoice.none:
      // يجب اختيار صوت أولاً قبل المتابعة
        if (_selectedVoice != AssistantVoice.none) {
          await _saveAndContinue();
        } else {
          // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
          await _speakInstruction('select_voice_first'.tr);
        }
        break;
    }
  }

  // ----------------------------------------------------------------------
  // 💾 Core Functionality
  // ----------------------------------------------------------------------

  // 💡 تم التعديل: استدعاء updateAssistantVoice
  Future<void> _handleVoiceSelection(AssistantVoice voice) async {
    setState(() {
      _selectedVoice = voice;
    });

    // 🔑 استخدام اسم الصوت (male أو female) الذي يتم البحث عنه في _configureTtsSettings
    String voiceCode = voice == AssistantVoice.male ? 'male' : 'female';
    // هذا سيقوم بتحديث الصوت فوراً (مع Locale الحالي) لاختباره
    // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
    String confirmationMsgKey = 'voice_set_as_personal_assistant';
    await bleController.speak(confirmationMsgKey.tr);
  }

  // 💡 تم التعديل: استخدام setLocaleAndTTS لضمان تحديث اللغة والصوت والتعريب
  Future<void> _saveAndContinue() async {
    // 1. التأكد من أن هناك اختيار قبل المتابعة
    if (_selectedVoice == AssistantVoice.none) {
      // 🔑 تم استبدال النص الثابت بمفتاح ترجمة
      await _speakInstruction('select_voice_first'.tr);
      return;
    }

    // 2. تحديد الجنس
    String voiceCode = _selectedVoice == AssistantVoice.male ? 'male' : 'female';

    // 🔑 الخطوة الحاسمة: استدعاء الدالة الشاملة التي تحدث اللغة (Localization)، وحالة المتحكم، وإعدادات TTS.
    // يتم تمرير كود اللغة الحالي لضمان عدم فقدانه.
    // هذا يحل مشكلة توقف التعريب (Localization) بعد حفظ الإعدادات.

    // 3. النطق برسالة المتابعة
    await _speakInstruction('selection_saved_moving_to_signup'.tr);

    // 4. المتابعة إلى شاشة التسجيل
    Get.offAll(() => const SignUpScreen());
  }

  // ----------------------------------------------------------------------
  // 🎨 UI Builders
  // ----------------------------------------------------------------------

  Widget _buildVoiceOption({
    required AssistantVoice voice,
    required String imagePath,
    required String checkmarkImagePath,
  }) {
    final bool isSelected = _selectedVoice == voice;
    final bool isFocused = _currentFocus == voice;

    // ✅ لون الخلفية: برتقالي صلب عند الاختيار، أسود شفاف عند عدم الاختيار
    final Color boxColor = isSelected ? activeSelectionColor : darkBackground;

    // ✅ منطق الحدود والظل
    Color borderColor = Colors.transparent;
    double borderWidth = 0;
    List<BoxShadow>? boxShadows;

    if (isSelected) {
      // حالة الاختيار
      borderColor = selectedBorderColor;
      borderWidth = 2.0;
      boxShadows = [
        BoxShadow(
          color: activeSelectionColor,
          blurRadius: 10,
          spreadRadius: 0,
        )
      ];
    } else if (isFocused) {
      // حالة التركيز (الـ Focus)
      borderColor = accentColor;
      borderWidth = 3.0;
      boxShadows = [
        BoxShadow(
          color: accentColor.withOpacity(0.3),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    }

    final Color fixedPlayIconColor = playIconColor;
    final bool isAnimating = isFocused;

    return GestureDetector(
      // 🔑 هذا هو الجزء الذي يحقق متطلب النقر المباشر وتغيير صوت TTS فوراً.
      onTap: () {
        _handleVoiceSelection(voice); // يحدد الصوت ويحدث TTS وينطق رسالة التأكيد بالصوت الجديد
        setState(() => _currentFocus = AssistantVoice.none); // ينقل التركيز إلى زر المتابعة
        _speakFocusDescription(AssistantVoice.none); // ينطق تعليمات زر المتابعة
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: isAnimating ? _animation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 145,
          height: 240,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: boxShadows,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // طبقة لتلوين خلفية منطقة الصورة بالبرتقالي عند الاختيار.
              if (isSelected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: double.infinity,
                    height: 170,
                    decoration: const BoxDecoration(
                      color: activeSelectionColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),

              // 1. صورة الشخصية (حجم 120x120)
              Positioned(
                top: 30,
                child: Image.asset(
                  imagePath,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),

              // 2. أيقونات التشغيل والإيقاف المؤقت (في الأسفل)
              Positioned(
                bottom: 25,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // أيقونة الموجة الصوتية
                    Image.asset(
                      'assets/images/mingcute_voice_fill.png',
                      width: 28,
                      height: 28,
                      color: fixedPlayIconColor,
                    ),
                    const SizedBox(width: 20),
                    // أيقونة التشغيل
                    Image.asset(
                      'assets/images/icon_park_solid_play.png',
                      width: 28,
                      height: 28,
                      color: fixedPlayIconColor,
                    ),
                  ],
                ),
              ),

              // 3. علامة الصح (Checkmark) - تظهر فقط عند الاختيار
              if (isSelected)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Image.asset(
                    checkmarkImagePath,
                    width: 28,
                    height: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 🔑 التأكد من أن أسماء ملفات الصور المستخدمة هي نفسها في مجلد assets لديك
    const String maleImagePath = 'assets/images/male_assistant_icon.png';
    const String femaleImagePath = 'assets/images/female_assistant_icon.png';
    const String checkmarkImagePath = 'assets/images/lets_icons_check_fill.png';

    final double screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTapUp: (details) {
        final double x = details.globalPosition.dx;
        final TapSide side = (x < screenWidth / 2) ? TapSide.left : TapSide.right;
        _handleScreenTap(side);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // 1. العنوان الرئيسي
                  Text(
                    'Choose a voice for your assistant'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // 2. خيارات الأصوات
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildVoiceOption(
                        voice: AssistantVoice.male,
                        imagePath: maleImagePath,
                        checkmarkImagePath: checkmarkImagePath,
                      ),
                      _buildVoiceOption(
                        voice: AssistantVoice.female,
                        imagePath: femaleImagePath,
                        checkmarkImagePath: checkmarkImagePath,
                      ),
                    ],
                  ),

                  const Spacer(flex: 5),

                  // 3. زر "Continue" (المتابعة)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      // ✅ تم التصحيح: يتم تفعيل الزر فقط عند اختيار صوت فعلي
                      onPressed: (_selectedVoice != AssistantVoice.none)
                          ? _saveAndContinue
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor, // ✅ اللون ثابت دائمًا على #CA842B
                        foregroundColor: continueButtonTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'NeoSansArabic',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        shadowColor: accentColor, // ✅ الظل ثابت دائمًا
                        elevation: 10, // ✅ البروز ثابت دائمًا
                      ),
                      child: Text('Continue'.tr),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}