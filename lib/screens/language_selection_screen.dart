// lib/screens/language_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../services/ble_controller.dart';
import 'voice_selection_screen.dart';


// 🎨 الألوان المخصصة (المطابقة للديزاين والمقاسات المحدثة)
const Color darkBackgroundPrimary = Color(0xFF292625);
const Color darkBackgroundSecondary = Color(0xFF1B1818);
const Color primaryTextColor = Color(0xFFF8F8F8);
const Color accentColor = Color(0xFFFFB267);
// 🔑 اللون الجديد: #757575 للنصوص الثانوية واللغات غير المختارة
const Color secondaryTextColor = Color(0xFF757575);
// 🔑 اللون الجديد: #FFB26740 (البرتقالي المميز مع شفافية) لخلفية العنصر النشط
const Color activeBoxColor = Color(0x40FFB267);


// ✅ الخلفية المتدرجة الموحدة
const LinearGradient backgroundGradient = LinearGradient(
  colors: [
    darkBackgroundPrimary,
    darkBackgroundSecondary,
  ],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// 🆕 قائمة اللغات المدعومة
const List<Map<String, String>> supportedLanguages = [
  {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
  {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
];

// 🆕 حالة التفاعل الجديدة
enum InteractionPhase {
  initial,
  awaitingChoice, // تم النقر على "Select Language" والآن ننتظر الاختيار
  cycling,
  processing,
  awaitingVoiceConfirmation,
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late final BleController bleController;

  String _selectedLanguageCode = 'en';
  // 🔑 هذا المتغير يتحكم في إظهار بطاقات اللغات
  bool _isDropdownOpen = false;

  InteractionPhase _currentPhase = InteractionPhase.initial;
  int _tapCount = 0;
  Timer? _tapResetTimer;
  final Duration _tapTimeout = const Duration(milliseconds: 600);

  int _languageIndex = -1;
  Timer? _languageCycleTimer;
  final Duration _cycleDuration = const Duration(seconds: 2);

  String _recognizedCommand = '';

  @override
  void initState() {
    super.initState();
    bleController = Get.find<BleController>();

    _selectedLanguageCode = bleController.userProfile?.localeCode.split('-').first ??
        Get.locale?.languageCode ??
        'en';

    // لضمان عرض اللغة الصحيحة
    if(_selectedLanguageCode != 'ar') {
      _selectedLanguageCode = 'en';
    }

    bleController.stop();

    Future.delayed(const Duration(milliseconds: 500), () {
      _speakInitialInstructions();
    });
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _languageCycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _speakInstruction(String instruction) async {
    if (!mounted) return;
    await bleController.speak(instruction);
  }

  Future<void> _speakInitialInstructions() async {
    // 🔑 رسالة التعليمات المتفق عليها: ضغطة للمتابعة (إذا لم يكن هناك رغبة في التغيير)، ضغطتين للتغيير
    const String contextAnnouncement = "أنت الآن في شاشة اختيار اللغة. ";
    const String instructions =
        "للثبات على لغة موبايلك والمتابعة اضغط ضغطة واحدة على الشاشة. ولو عايز تغير اللغة اضغط ضغطتين لفتح قائمة اللغات.";

    await _speakInstruction(contextAnnouncement + instructions);
  }

  // ----------------------------------------------------------------------
  // 👆 Tap Handling Logic (تم تعديل _handleSingleTap ليتوافق مع التصميم الجديد)
  // ----------------------------------------------------------------------

  void _handleScreenTap() {
    if (_currentPhase == InteractionPhase.processing) return;

    bleController.stop();
    _languageCycleTimer?.cancel();

    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(_tapTimeout, () => _processTapCount());
  }

  void _processTapCount() {
    final int count = _tapCount;
    _tapCount = 0;

    if (count == 1) {
      _handleSingleTap();
    } else if (count == 2) {
      _handleDoubleTap();
    }
  }

  // 🔑 تم تعديل هذا الجزء للتعامل مع منطق "الثبات والمتابعة" والتعامل مع حالات القائمة.
  void _handleSingleTap() {
    if (_currentPhase == InteractionPhase.awaitingVoiceConfirmation) {
      // 1. تأكيد الأمر الصوتي
      HapticFeedback.heavyImpact();
      _processVoiceCommand(_recognizedCommand);
    }

    // 2. إذا كانت القائمة مغلقة (الحالة الافتتاحية)
    else if (_currentPhase == InteractionPhase.initial && !_isDropdownOpen) {
      // 🔑 الثبات على اللغة الحالية والمتابعة، كما هو مطلوب في الاتفاق الأصلي.
      _saveAndContinue(_selectedLanguageCode);
    }

    // 3. إذا كانت القائمة مفتوحة (الحالة awaitingChoice)
    else if (_currentPhase == InteractionPhase.awaitingChoice) {
      // 🔑 ضغطة واحدة والقائمة مفتوحة: تبدأ دورة التنقل (cycling)
      HapticFeedback.mediumImpact();
      _startLanguageCycle();
    }

    // 4. إذا كانت في وضع الاستعراض (cycling)
    else if (_currentPhase == InteractionPhase.cycling) {
      // 🔑 ضغطة واحدة خلال الدورة: توقف الدورة
      _stopLanguageCycleAndSpeakInstruction();
    }
  }

  // 🔑 منطق إيقاف الدورة والنطق
  void _stopLanguageCycleAndSpeakInstruction() {
    _languageCycleTimer?.cancel();
    setState(() {
      _currentPhase = InteractionPhase.awaitingChoice;
      _languageIndex = -1;
    });
    _speakInstruction("تم إيقاف استعراض اللغات. يمكنك الضغط مرتين لاختيار اللغة الحالية أو ضغطة واحدة لاستئناف الاستعراض.");
  }


  // 🔑 دالة فتح/غلق القائمة المنسدلة (تُستدعى الآن عبر Double Tap)
  void _toggleDropdown() {
    if (_currentPhase == InteractionPhase.processing) return;

    if (_isDropdownOpen) {
      // 🔑 الإغلاق
      setState(() {
        _isDropdownOpen = false;
        _currentPhase = InteractionPhase.initial;
        _languageCycleTimer?.cancel();
      });
      _speakInstruction("تم إغلاق قائمة اللغات. اضغط ضغطتين لفتحها.");
    } else {
      // 🔑 الفتح
      setState(() {
        _isDropdownOpen = true;
        _currentPhase = InteractionPhase.awaitingChoice;
        _languageIndex = -1; // لا يوجد تركيز في البداية
      });
      _speakInstruction("القائمة مفتوحة. يمكنك الضغط ضغطة واحدة لبدء استعراض اللغات، أو ضغطتين لاختيار اللغة المختارة حالياً.");
    }
    HapticFeedback.mediumImpact();
  }

  // 🔑 تم تعديل _handleDoubleTap لفتح/غلق القائمة.
  void _handleDoubleTap() {
    if (_currentPhase == InteractionPhase.initial) {
      // 🔑 الضغط المزدوج يفتح القائمة (لتغيير اللغة)
      _toggleDropdown();
    }
    else if (_currentPhase == InteractionPhase.awaitingChoice || _currentPhase == InteractionPhase.cycling) {
      // 🔑 اختيار اللغة المحددة حالياً والمتابعة
      if (supportedLanguages.any((l) => l['code'] == _selectedLanguageCode)) {
        HapticFeedback.heavyImpact();
        _saveAndContinue(_selectedLanguageCode);
      } else {
        _speakInstruction("يرجى اختيار لغة أولاً.");
      }
    }
  }

  // ----------------------------------------------------------------------
  // 🔊 منطق الأوامر الصوتية (Long Press) (لم يتغير)
  // ----------------------------------------------------------------------

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_currentPhase == InteractionPhase.processing) return;

    _languageCycleTimer?.cancel();
    bleController.stop();
    HapticFeedback.vibrate();

    _speakInstruction('stt_listening_tts'.tr);

    // 🔑 استخدام دالة STT الموثوقة من bleController
    bleController.startListening(onResult: (result) async {
      bleController.stopListening(shouldSpeakStop: false);

      if (result.isEmpty) {
        await _speakInstruction('did_not_catch_language_tts'.tr);
        _resetToInitialState();
        return;
      }

      await _speakInstruction('stt_heard_tts'.trArgs([result]));

      setState(() {
        _recognizedCommand = result;
        _currentPhase = InteractionPhase.awaitingVoiceConfirmation;
        // 🔑 نفتح القائمة ليراها المستخدم
        _isDropdownOpen = true;
      });

      await _speakInstruction('confirm_command_tts'.tr);
    });
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (_currentPhase == InteractionPhase.processing) return;
    bleController.stopListening(shouldSpeakStop: false);
    HapticFeedback.selectionClick();
  }

  void _processVoiceCommand(String result) async {
    setState(() => _currentPhase = InteractionPhase.processing);

    final String lowerResult = result.toLowerCase();
    String? selectedCode;

    // 1. محاولة معالجة أمر اختيار اللغة أولاً
    if (lowerResult.contains('عربي') || lowerResult.contains('arabic')) {
      selectedCode = 'ar';
    } else if (lowerResult.contains('إنجليزي') || lowerResult.contains('english')) {
      selectedCode = 'en';
    }

    if (selectedCode != null) {
      // 🔑 تحديث _selectedLanguageCode قبل المتابعة
      _selectedLanguageCode = selectedCode;
      await bleController.speak('language_confirmed_tts'.trArgs([supportedLanguages.firstWhere((l) => l['code'] == selectedCode)['name']!]));
      _saveAndContinue(selectedCode);
    }
    // 2. أمر تنقل عالمي
    else if (lowerResult.contains('رجوع') || lowerResult.contains('خلف') || lowerResult.contains('go back')) {
      await bleController.handleNavigationCommand(lowerResult);
      _resetToInitialState();
    }
    // 3. أسئلة عامة (Gemini)
    else if (result.isNotEmpty) {
      await bleController.getGeminiResponse(result);
      _resetToInitialState();
    }
    else {
      await _speakInstruction('did_not_catch_language_tts'.tr);
      _resetToInitialState();
    }
  }

  void _resetToInitialState() {
    setState(() {
      _currentPhase = InteractionPhase.initial;
      _languageIndex = -1;
      _isDropdownOpen = false; // إغلاق القائمة
    });
    _speakInitialInstructions();
  }

  // ----------------------------------------------------------------------
  // 🔄 منطق دورة استعراض اللغات (Cycling) (لم يتغير)
  // ----------------------------------------------------------------------

  void _startLanguageCycle() {
    setState(() {
      _currentPhase = InteractionPhase.cycling;
    });

    _speakInstruction('starting_language_cycle_tts'.tr);

    _languageCycleTimer?.cancel();

    _languageIndex = 0; // البدء من أول لغة
    _cycleLanguage();

    _languageCycleTimer = Timer.periodic(_cycleDuration, (timer) {
      _languageIndex = (_languageIndex + 1) % supportedLanguages.length;
      _cycleLanguage();
    });
  }

  void _cycleLanguage() {
    final langMap = supportedLanguages[_languageIndex];
    final langCode = langMap['code']!;

    setState(() {
      _selectedLanguageCode = langCode;
    });

    String message;
    if (langCode == 'ar') {
      message = 'arabic_select_tts'.tr;
    } else {
      message = 'english_select_tts'.tr;
    }

    bleController.speak(message);
    HapticFeedback.vibrate();
  }

  void _saveAndContinue(String languageCode) async {
    _tapResetTimer?.cancel();
    _languageCycleTimer?.cancel();

    setState(() => _currentPhase = InteractionPhase.processing);
    HapticFeedback.heavyImpact();

    String fullLocaleCode = languageCode == 'ar' ? 'ar-SA' : 'en-US';
    Locale finalLocale = Locale(languageCode, languageCode == 'ar' ? 'SA' : 'US');

    await bleController.setLocaleAndTTS(finalLocale.toLanguageTag(), fullLocaleCode);
    await _speakInstruction('language_selection_complete_tts'.tr);

    Get.offAll(() => const ChooseVoiceScreen());
  }


  // ----------------------------------------------------------------------
  // 🎨 UI Builders (المُعدّل لمطابقة تصميم Figma)
  // ----------------------------------------------------------------------

  // 🔑 البناء الجديد لزر القائمة المنسدلة "Select Language"
  Widget _buildDropdownButton() {

    // 💡 النص الحالي الذي يظهر داخل الزر
    final String displayText = 'Select Language'; // النص ثابت في هذا الزر

    // 💡 تحديد لون الحدود
    final Color borderColor = _isDropdownOpen ? accentColor : Colors.transparent;

    // 💡 تحديد لون الخلفية بناءً على ما إذا كانت القائمة مغلقة
    final Color backgroundColor = darkBackgroundPrimary.withOpacity(_isDropdownOpen ? 0.8 : 0.9);


    return InkWell(
      onTap: _toggleDropdown, // ضغطة واحدة تفتح/تغلق القائمة
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 55, // ارتفاع ثابت 55px
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          // 🔑 استخدام اللون الداكن
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          // 🔑 حدود شفافة في الوضع العادي، وبرتقالية عند الفتح
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            // 🔑 النص
            Text(
              displayText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                // 🔑 اللون: #757575
                color: secondaryTextColor,
              ),
            ),
            const Spacer(),

            // 🔑 السهم: يدور عند فتح/غلق القائمة
            Icon(
              _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: secondaryTextColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // 🔑 البناء الجديد لبطاقات اللغة (تظهر فقط عند فتح القائمة)
  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required String flag,
  }) {
    // 🔑 isFocused: للغة التي يتم التنقل عليها (cycling) أو المختارة حالياً
    final bool isFocused = _selectedLanguageCode == languageCode;

    // 🔑 لون الخلفية: #FFB26740 فقط عندما تكون اللغة مركز عليها/مختارة
    Color backgroundColor = isFocused ? activeBoxColor : Colors.transparent;

    // 🔑 لون الحدود: برتقالي عند التركيز/الاختيار، وإلا أبيض شفاف
    Color borderColor = isFocused ? accentColor : Colors.transparent;


    // 💡 نستخدم InkWell للتعامل مع ضغطتين (Double Tap)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isFocused ? 2.0 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            // 💡 عند النقر المزدوج على بطاقة اللغة: نختارها ونتابع
            onDoubleTap: () {
              _saveAndContinue(languageCode);
            },
            // 💡 عند النقر العادي: نغير اللغة المختارة وننطقها
            onTap: () {
              if (_currentPhase != InteractionPhase.processing) {
                setState(() {
                  _selectedLanguageCode = languageCode;
                  // عند النقر، ننتقل إلى حالة awaitingChoice
                  _currentPhase = InteractionPhase.awaitingChoice;
                  _languageCycleTimer?.cancel();
                  _languageIndex = -1;
                });
                HapticFeedback.lightImpact();
                _speakInstruction(languageName);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    languageName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      // 🔑 لون النص: #F8F8F8 إذا كانت مختارة، #757575 إذا لم تكن
                      color: isFocused ? primaryTextColor : secondaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  // 🔑 السهم (مؤشر التحديد)
                  if (isFocused)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: accentColor,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLangCode = _selectedLanguageCode;

    return GestureDetector(
      onTap: _handleScreenTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressEnd: _handleLongPressEnd,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),

                  // 1. العنوان الرئيسي
                  const Text(
                    'Choose the language',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. رسائل الشرح
                  Text(
                    'Select your preferred language below',
                    style: const TextStyle(
                      // 🔑 تطبيق اللون #757575
                      color: secondaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This helps us serve you better.',
                    style: const TextStyle(
                      // 🔑 تطبيق اللون #757575
                      color: secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 3. زر القائمة المنسدلة "Select Language"
                  _buildDropdownButton(),

                  // 🔑 قائمة اللغات التي تظهر فقط عند _isDropdownOpen
                  if (_isDropdownOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        children: supportedLanguages.map((lang) {
                          // 🔑 تحديد ما إذا كانت اللغة هي اللغة التي يتم استعراضها حالياً في وضع cycling
                          final isCycling = _currentPhase == InteractionPhase.cycling && supportedLanguages.indexOf(lang) == _languageIndex;

                          // 🔑 نستخدم اللغة المختارة _selectedLanguageCode أو لغة الدورة isCycling كحالة تركيز
                          return _buildLanguageOption(
                            languageCode: lang['code']!,
                            languageName: lang['name']!,
                            flag: lang['flag']!,
                          );
                        }).toList(),
                      ),
                    ),

                  const Spacer(),

                  // 4. زر "Continue" في الأسفل
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (_currentPhase != InteractionPhase.processing) ? () => _saveAndContinue(currentLangCode) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPhase != InteractionPhase.processing
                            ? accentColor
                            : accentColor.withOpacity(0.6),
                        foregroundColor: darkBackgroundPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'NeoSansArabic',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        elevation: _currentPhase != InteractionPhase.processing ? 5 : 2,
                      ),
                      child: Text(_currentPhase == InteractionPhase.processing ? 'Loading...' : 'Continue'),
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