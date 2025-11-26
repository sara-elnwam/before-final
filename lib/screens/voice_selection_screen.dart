// lib/screens/voice_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../services/ble_controller.dart';
import 'sign_up_screen.dart';

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
    const String contextAnnouncement = "أنت الآن في شاشة اختيار صوت المساعد. ";
    const String instructions =
        "من فضلك اختار صوت المساعد. اضغط ضغطة واحدة للتنقل بين الخيارات. اضغط مرتين للاختيار والمتابعة.";

    await _speakInstruction(contextAnnouncement + instructions);
    await _speakFocusDescription(_currentFocus);
  }

  Future<void> _speakFocusDescription(AssistantVoice voice) async {
    String message = '';
    HapticFeedback.lightImpact();

    switch (voice) {
      case AssistantVoice.male:
        message = 'التركيز على صوت الذكر. للاختبار اضغط ضغطة واحدة على الجانب الأيمن من الشاشة.';
        break;
      case AssistantVoice.female:
        message = 'التركيز على صوت الأنثى. للاختبار اضغط ضغطة واحدة على الجانب الأيسر من الشاشة.';
        break;
      case AssistantVoice.none:
        message = 'التركيز على زر المتابعة. اضغط مرتين للمتابعة.';
        break;
    }
    await _speakInstruction(message);
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
          String confirmationMsg = 'هذا هو صوت المساعد الذكر.';
          await bleController.speak(confirmationMsg);
        } else {
          // نقر يسار: التنقل للأنثى
          await _handleSingleTapForNavigation();
        }
      } else if (_currentFocus == AssistantVoice.female) {
        if (side == TapSide.left) {
          // نقر يسار: اختبار صوت الأنثى
          String confirmationMsg = 'هذا هو صوت المساعد الأنثى.';
          await bleController.speak(confirmationMsg);
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
        await _speakInstruction('تم اختيار الصوت. اضغط مرتين على زر المتابعة للانتقال للخطوة التالية.');
        break;

      case AssistantVoice.none:
      // يجب اختيار صوت أولاً قبل المتابعة
        if (_selectedVoice != AssistantVoice.none) {
          await _saveAndContinue();
        } else {
          await _speakInstruction('من فضلك اختر صوت المساعد قبل المتابعة.');
        }
        break;
    }
  }

  // ----------------------------------------------------------------------
  // 💾 Core Functionality
  // ----------------------------------------------------------------------

  Future<void> _handleVoiceSelection(AssistantVoice voice) async {
    setState(() {
      _selectedVoice = voice;
    });

    String voiceCode = voice == AssistantVoice.male ? 'male' : 'female';
    await bleController.updateAssistantVoice(voiceCode);

    String confirmationMsg = 'تم تحديد هذا الصوت كمساعدك الشخصي.';
    await bleController.speak(confirmationMsg);
  }

  Future<void> _saveAndContinue() async {
    // التأكد من أن هناك اختيار قبل المتابعة
    if (_selectedVoice == AssistantVoice.none) return;

    String voiceCode = _selectedVoice == AssistantVoice.male ? 'male' : 'female';
    await bleController.updateAssistantVoice(voiceCode);

    await _speakInstruction('تم حفظ اختيارك. اضغط ضغطة واحدة للانتقال لإنشاء الحساب.');

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
      onTap: () {
        _handleVoiceSelection(voice);
        setState(() => _currentFocus = AssistantVoice.none);
        _speakFocusDescription(AssistantVoice.none);
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
                    decoration: BoxDecoration(
                      color: activeSelectionColor,
                      borderRadius: const BorderRadius.only(
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
                  const Text(
                    'Choose a voice for your assistant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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

                  // 3. زر \"Continue\" (المتابعة)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      // يجب أن يكون التركيز على الزر لكي يتمكن TTS من اختيار وظيفة المتابعة
                      onPressed: (_currentFocus == AssistantVoice.none)
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
                      child: const Text('Continue'),
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