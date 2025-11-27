// lib/screens/language_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

// ✅ FIX: استيراد ChooseVoiceScreen وإخفاء AssistantVoice لتجنب تضارب النوع
import 'package:blind/screens/voice_selection_screen.dart' hide AssistantVoice;
import '../services/ble_controller.dart';

import 'package:blind/enums/assistant_voice.dart'; // ✅ هذا هو المصدر الصحيح
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
  {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
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
  // ✅ FIX: تهيئة المتحكم مباشرة لحل مشكلة LateInitializationError
  final BleController bleController = Get.find<BleController>();

  String _selectedLanguageCode = 'en';
  // 🔑 هذا المتغير يتم استخدامه فقط للعرض داخل البطاقات وفي بداية النطق
  String _currentLanguageName = 'English';

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

    // 1. تحديد كود اللغة الأولي (من البروفايل، أو لغة الجهاز، أو افتراضياً الإنجليزية)
    // ✅ تحسين: استخدام Get.deviceLocale ليكون أكثر دقة في اكتشاف لغة الموبايل
    String languageCode = bleController.userProfile?.localeCode.split('-').first ??
        Get.deviceLocale?.languageCode ??
        'en';

    // 2. التحقق من الدعم وتعيين الكود
    if (!supportedLanguages.any((l) => l['code'] == languageCode)) {
      languageCode = 'en';
    }
    _selectedLanguageCode = languageCode;

    String fullLocaleCode = languageCode == 'ar' ? 'ar-SA' : 'en-US';

    // 4. تعيين اسم اللغة الحالية للنطق (باستخدام الاسم المعرّب)
    final lang = supportedLanguages.firstWhereOrNull(
            (element) => element['code'] == _selectedLanguageCode);
    // ستكون 'العربية' إذا كان موبايلك عربي
    _currentLanguageName = lang?['name'] ?? 'English';

    bleController.stop();

    // 🔑 FIX: يجب وضع الاستدعاءات التي تسبب إعادة البناء (مثل تحديث الـ Locale)
    // داخل WidgetsBinding.instance.addPostFrameCallback لتأخيرها
    // حتى يكتمل بناء الإطار الحالي وتجنب خطأ setState() or markNeedsBuild().
    WidgetsBinding.instance.addPostFrameCallback((_) { // 🔑 بداية التعديل
      // 3. تحديث لغة GetX هنا لضمان أن النص (UI) يظهر بلغة الموبايل الصحيحة فوراً
      // هذا هو الحل لمشكلة: "حتى الشاشة بتبقي مكتوبة انجلش وانا موبايلي عربي"
      Get.updateLocale(Locale(languageCode, languageCode == 'ar' ? 'SA' : 'US'));

      // 🔑 يجب تهيئة TTS/STT مباشرة هنا باستخدام اللغة المكتشفة
      // هذا يضمن أن TTS/STT يعملان بلغة الموبايل الاصلية قبل نطق التعليمات الافتتاحية.
      bleController.setLocaleAndTTS(fullLocaleCode, AssistantVoice.male);

      // 5. نطق التعليمات بعد تأخير بسيط لضمان تهيئة TTS
      Future.delayed(const Duration(milliseconds: 500), () {
        _speakInitialInstructions();
      });
    }); // 🔑 نهاية التعديل
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _languageCycleTimer?.cancel();
    super.dispose();
  }

  Future<void> _speakInstruction(String instruction) async {
    if (!mounted) return;
    // 🔑 TTS يستخدم اللغة التي تم إعدادها في bleController.setLocaleAndTTS
    await bleController.speak(instruction);
  }

  // 🔑 دالة النطق الافتتاحي الجديدة تستخدم مفاتيح الترجمة
  Future<void> _speakInitialInstructions() async {
    // 1. استخدام مفاتيح الترجمة للنطق الأولي (محتوى النطق سيتبع اللغة التي تم تعيينها في initState)
    final String contextAnnouncement = 'lang_screen_context_announcement'.tr;

    // 2. الحصول على اسم اللغة التي سيتم الإعلان عنها في النطق (العربية أو English)
    // نستخدم _currentLanguageName التي تم تعيينها بناءً على لغة الجهاز في initState
    final String languageNameForSpeech = _currentLanguageName;

    final String currentLangAnnouncement = 'lang_screen_current_language'.trArgs([languageNameForSpeech]);

    final String instructions = 'lang_screen_initial_instructions'.tr;

    // 3. نطق الجملة كاملة
    // هذا يضمن نطق "العربية" أو "English" باللغة التي اكتشفها GetX.
    await _speakInstruction(contextAnnouncement + currentLangAnnouncement + instructions);
  }

  // ----------------------------------------------------------------------
  // 👆 Tap Handling Logic
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

  // 🔑 ضغطة واحدة: (1) تأكيد صوتي (2) متابعة (3) بدء دورة اللغات
  void _handleSingleTap() {
    if (_currentPhase == InteractionPhase.awaitingVoiceConfirmation) {
      // 1. تأكيد الأمر الصوتي
      HapticFeedback.heavyImpact();
      _processVoiceCommand(_recognizedCommand);
    }

    // 2. إذا كانت القائمة مغلقة (الحالة الافتتاحية: ضغطة واحدة للثبات والمتابعة)
    else if (_currentPhase == InteractionPhase.initial && !_isDropdownOpen) {
      // 🔑 الثبات على اللغة الحالية والمتابعة، وهذا هو الخيار الافتراضي للغة الموبايل
      _saveAndContinue(_selectedLanguageCode);
    }

    // 3. إذا كانت القائمة مفتوحة (الحالة awaitingChoice: ضغطة واحدة لبدء دورة اللغات)
    else if (_currentPhase == InteractionPhase.awaitingChoice) {
      HapticFeedback.mediumImpact();
      _startLanguageCycle();
    }

    // 4. إذا كانت في وضع الاستعراض (cycling: ضغطة واحدة لإيقاف الدورة)
    else if (_currentPhase == InteractionPhase.cycling) {
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
    // 🔑 رسالة النطق المطلوبة بعد التوقف:
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
        _languageIndex = -1; // إعادة تعيين مؤشر الدورة
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

  // 🔑 ضغطتين: (1) فتح/غلق القائمة (2) اختيار اللغة والمتابعة
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
  // 🔊 منطق الأوامر الصوتية (Long Press)
  // ----------------------------------------------------------------------

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_currentPhase == InteractionPhase.processing) return;

    _languageCycleTimer?.cancel();
    bleController.stop();
    HapticFeedback.vibrate();

    // 🔑 رسالة بدء الاستماع المطلوبة:
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
    // 🔑 يجب أن يتعرف على "العربية" أو "الانجليزية"
    if (lowerResult.contains('عربي') || lowerResult.contains('العربية') || lowerResult.contains('arabic')) {
      selectedCode = 'ar';
    } else if (lowerResult.contains('إنجليزي') || lowerResult.contains('الانجليزية') || lowerResult.contains('english')) {
      selectedCode = 'en';
    }

    if (selectedCode != null) {
      // 🔑 تحديث _selectedLanguageCode قبل المتابعة
      _selectedLanguageCode = selectedCode;
      final langName = supportedLanguages.firstWhere((l) => l['code'] == selectedCode)['name']!;
      // 🔑 استخدام مفتاح الترجمة الجديد هنا
      await bleController.speak('language_confirmed_tts'.trArgs([langName]));
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
  // 🔄 منطق دورة استعراض اللغات (Cycling)
  // ----------------------------------------------------------------------

  void _startLanguageCycle() {
    setState(() {
      _currentPhase = InteractionPhase.cycling;
    });

    // 🔑 رسالة بدء الدورة المطلوبة
    _speakInstruction('بدء استعراض اللغات. اضغط ضغطة واحدة للانتقال للغة التالية، أو ضغطتين للاختيار.');

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
      // 🔑 رسالة الدورة المطلوبة
      message = 'العربية، اضغط ضغطتين للاختيار.';
    } else {
      // 🔑 رسالة الدورة المطلوبة
      message = 'English، اضغط ضغطتين للاختيار.';
    }

    bleController.speak(message);
    HapticFeedback.vibrate();
  }

  // 💡 دالة الحفظ والمتابعة (المسؤولة عن تغيير لغة التطبيق بالكامل)
  void _saveAndContinue(String languageCode) async {
    _tapResetTimer?.cancel();
    _languageCycleTimer?.cancel();

    setState(() => _currentPhase = InteractionPhase.processing);
    HapticFeedback.heavyImpact();

    // 🔑 1. تعيين الـ Locale والـ TTS/STT. هذا يغير لغة التطبيق بالكامل
    String fullLocaleCode = languageCode == 'ar' ? 'ar-SA' : 'en-US';
    // 🔑 هذا يضبط محركات TTS/STT على اللغة الجديدة
    // ✅ FIX: يجب تحديث GetX Locale أيضًا هنا لضمان أن الواجهة (UI) في الشاشات التالية تتغير
    Get.updateLocale(Locale(languageCode, languageCode == 'ar' ? 'SA' : 'US'));

    // 🔑 هذا السطر مفقود ويجب إضافته لتحديث TTS/STT على اللغة الجديدة
    await bleController.setLocaleAndTTS(fullLocaleCode, AssistantVoice.male);

    // 🔑 2. النطق للتأكيد (سيستخدم اللغة الجديدة بعد تحديثها)
    // 🔑 استخدام مفتاح الترجمة للتأكيد
    await _speakInstruction('language_selection_complete_tts'.tr);

    // 🔑 3. الانتقال للشاشة التالية
    Get.offAll(() => const ChooseVoiceScreen());  }


  //
  // 🎨 UI Builders
  //

  // 🔑 البناء الجديد لزر القائمة المنسدلة "Select Language"
  Widget _buildDropdownButton() {

    // 💡 النص الحالي الذي يظهر داخل الزر
    final String displayText = 'select_language'.tr; // 🔑 استخدام مفتاح الترجمة

    // 💡 تحديد لون الحدود
    final Color borderColor = _isDropdownOpen ? accentColor : Colors.transparent;

    // 💡 تحديد لون الخلفية بناءً على ما إذا كانت القائمة مغلقة
    final Color backgroundColor = darkBackgroundPrimary.withOpacity(_isDropdownOpen ? 0.8 : 0.9);


    return InkWell(
      // 🔑 ربط ضغطة مرئية على الزر بمنطق الضغط المزدوج (لفتح/غلق القائمة)
      onTap: _toggleDropdown,
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
            Text( // 🔑 تم استخدام متغير الترجمة
              displayText,
              style: const TextStyle(
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
              // 🔑 الضغط المزدوج المرئي يساوي الاختيار والمتابعة
              _saveAndContinue(languageCode);
            },
            // 💡 عند النقر العادي: نغير اللغة المختارة وننطقها
            onTap: () {
              if (_currentPhase != InteractionPhase.processing) {
                // 🔑 عند النقر على البطاقة، نوقف الدورة ونثبت على اللغة
                if (_currentPhase == InteractionPhase.cycling) {
                  _languageCycleTimer?.cancel();
                }

                setState(() {
                  _selectedLanguageCode = languageCode;
                  // العودة إلى awaitingChoice بعد الاختيار المرئي
                  _currentPhase = InteractionPhase.awaitingChoice;
                  _languageIndex = -1;
                });
                HapticFeedback.lightImpact();
                _speakInstruction('تم اختيار $languageName. اضغط ضغطتين للمتابعة.');
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
                    const Icon(
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
      // 🔑 ربط منطق النقر الموحد بالـ GestureDetector
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
                  Text( // 🔑 استخدام مفتاح الترجمة
                    'choose_language_title'.tr,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. رسالة الشرح
                  Text( // 🔑 استخدام مفتاح الترجمة
                    'choose_language_description'.tr,
                    style: const TextStyle(
                      // 🔑 تطبيق اللون #757575
                      color: secondaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
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
                          // 🔑 نستخدم اللغة المختارة _selectedLanguageCode لحالة التركيز
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
                      // 🔑 استخدام مفاتيح الترجمة
                      child: Text(_currentPhase == InteractionPhase.processing ? 'loading_message'.tr : 'continue_button'.tr),
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