// ble_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart'; // يُستخدم لـ firstWhereOrNull

import '../models/user_profile.dart';
import '../enums/action_type.dart';
import '../enums/app_state.dart'; // 🆕 إضافة
import '../screens/sign_up_screen.dart'; // 🆕 إضافة

// ⚠️ ملاحظة: يجب التأكد من وجود مسارات الملفات التالية في مشروعك:
// 1. ../models/user_profile.dart
// 2. ../enums/action_type.dart
// 3. ../enums/app_state.dart
// 4. sign_up_screen.dart
// lib/services/ble_controller.dart
// ...
import '../enums/assistant_voice.dart'; // 🆕 إضافة هذا السطر
// ------------------------------------------------------------------------
// 🆕 المحدد الجديد لنوع الصوت (يفضل وضعه في lib/enums/assistant_voice.dart)
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// ثوابت خدمة Bluetooth
// ------------------------------------------------------------------------
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String DATA_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String CONFIG_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a7";

// ------------------------------------------------------------------------
// مفاتيح SharedPreferences
// ------------------------------------------------------------------------
const String USER_PROFILE_KEY = 'user_profile_data';
const String LANGUAGE_CODE_KEY = 'language_code';
const String USER_PROFILE_PREFS_KEY = 'userProfile';
const String GESTURE_CONFIG_PREFS_KEY = 'gestureConfig';


// ------------------------------------------------------------------------
// ⚠️ مفتاح API الخاص بـ Gemini - يجب تعويضه بمفتاحك الفعلي
// ------------------------------------------------------------------------
const String GEMINI_API_KEY = "AIzaSyBwOMGLGl6GJsKkgvyT2Mz57vmdNWhOZJI"; // مفتاح وهمي

// ------------------------------------------------------------------------
// ثوابت التنقل الصوتي (لنموذج Gemini)
// ------------------------------------------------------------------------
const Map<String, String> _AVAILABLE_SCREENS = {
  'profile': '/profile',
  'settings': '/profile', // Alias
  'sign up': '/profile', // Alias
  'allergies': '/allergies',
  'bluetooth': '/bluetooth',
  'connect': '/bluetooth', // Alias
  'gestures': '/gestures',
  'voice': '/tts_stt',
  'language': '/tts_stt', // Alias
  'home': '/home',
  'main': '/home', // Alias
  'الرئيسية': '/home',
  'الإعدادات': '/profile',
  'الملف الشخصي': '/profile',
  'الحساسية': '/allergies',
  'البلوتوث': '/bluetooth',
  'الإيماءات': '/gestures',
  'الصوت': '/tts_stt',
};


class BleController extends GetxController {
  // ------------------------------------------------------------------------
  // 1. Services & Variables
  // ------------------------------------------------------------------------
  final FlutterTts _flutterTts = FlutterTts();

  // 💡 متغير جديد لحفظ قائمة الأصوات المتاحة
  List<dynamic> _availableVoices = [];

  final SpeechToText _speechToText = SpeechToText();

  // 🆕 متغير جديد لحالة الصوت
  AssistantVoice _assistantVoiceSetting = AssistantVoice.none;
  AssistantVoice get assistantVoiceSetting => _assistantVoiceSetting;

  // 🆕 متغير جديد لحالة التطبيق العامة (تم استخدام متغير AppState.idle.obs في التعديلات)
  // سيتم استخدام متغير AppState لتوضيح الحالة
  final appState = AppState.idle.obs;

  bool _isListening = false;
  bool get isListening => _isListening;

  String _lastWords = '';
  String get lastWords => _lastWords;

  bool _speechToTextInitialized = false;

  late final GenerativeModel _chatModel;
  late final GenerativeModel _navigationModel;

  Timer? _sttTimeoutTimer;
  final Duration _maxListeningDuration = const Duration(seconds: 15);

  final SharedPreferences _prefs;

  bool _isAppInitialized = false;
  bool get isAppInitialized => _isAppInitialized;

  // ------------------------------------------------------------------------
  // 2. User Profile & Locale Logic
  // ------------------------------------------------------------------------
  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;
  set userProfile(UserProfile? profile) {
    _userProfile = profile;
  }

  bool get isUserRegistered => _userProfile != null;

  double get speechRate => _userProfile?.speechRate ?? 0.5;
  double get volume => _userProfile?.volume ?? 1.0;
  // ⚠️ تم تغيير هذا Getter ليتوافق مع Enum الجديد
  String get assistantVoice => _userProfile?.assistantVoice ?? '';

  String _currentLanguageCode = 'en-US';
  String get currentLanguageCode => _currentLanguageCode;
  String get localeCode => _currentLanguageCode;

  String get languageCode => _currentLanguageCode.split('-').first;
  String? get countryCode => _currentLanguageCode.split('-').length > 1 ? _currentLanguageCode.split('-')[1] : null;

  Map<String, ActionType> _gestureConfig = {
    'shakeTwiceAction': ActionType.sos_emergency,
    'tapThreeTimesAction': ActionType.call_contact,
    'longPressAction': ActionType.disable_feature,
  };
  Map<String, ActionType> get gestureConfig => _gestureConfig;

  // متغيرات البلوتوث...
  final List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  String _receivedDataMessage = 'No data received yet.';
  StreamSubscription<List<int>>? _dataSubscription;

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String get receivedDataMessage => _receivedDataMessage;
  bool get isConnected => connectedDevice != null;


  // ------------------------------------------------------------------------
  // 3. Constructor & Initialization
  // ------------------------------------------------------------------------
  BleController({required SharedPreferences prefs}) : _prefs = prefs {
    // تهيئة نموذج Gemini
    final String apiKey = (GEMINI_API_KEY.isEmpty || GEMINI_API_KEY == 'AIzaSyBwOMGLGl6GJsKkgvyT2Mz57vmdNWhOZJI')
        ? 'DUMMY_KEY' : GEMINI_API_KEY;

    _chatModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
    _navigationModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
    if (apiKey == 'DUMMY_KEY' && kDebugMode) {
      print("🚨 Warning: Gemini API Key is not set or is DUMMY_KEY. Voice commands may fail.");
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initStt(); // تهيئة STT والأذونات
    initializeController(); // بدء التهيئة الكلية
  }


  Future<void> loadUserProfile() async {
    await _loadUserProfile();
    update();
  }

  Future<void> initializeController() async {
    await _loadUserProfile();

    final String? savedLang = _prefs.getString(LANGUAGE_CODE_KEY);
    final String? savedVoice = _prefs.getString('assistantVoice'); // 🆕 تحميل مفتاح الصوت الجديد

    // توحيد تنسيق الـ locale
    String initialLocale = savedLang ?? _userProfile?.localeCode ?? Get.deviceLocale?.toString() ?? 'en_US';
    initialLocale = initialLocale.replaceAll('_', '-');
    if (initialLocale.length == 2) {
      initialLocale = initialLocale == 'ar' ? 'ar-SA' : 'en-US';
    }

    _currentLanguageCode = initialLocale;

    if (_userProfile != null) {
      // التأكد من أن الملف الشخصي يستخدم اللغة المحدثة
      _userProfile = _userProfile!.copyWith(localeCode: _currentLanguageCode);
      await saveUserProfile(_userProfile!, updateLocale: false);
    }

    // 🆕 تعيين الإعداد الجديد لـ AssistantVoice
    if (savedVoice != null) {
      _assistantVoiceSetting = AssistantVoice.values.firstWhereOrNull((v) => v.name == savedVoice) ?? AssistantVoice.none;
    } else {
      // استخدام القيمة من ملف التعريف إذا كانت متاحة، وتحويلها إلى Enum
      final String profileVoiceKey = _userProfile?.assistantVoice?.toLowerCase() ?? '';
      _assistantVoiceSetting = (profileVoiceKey == 'male') ? AssistantVoice.male :
      (profileVoiceKey == 'female') ? AssistantVoice.female : AssistantVoice.none;
    }


    // 💡 تحديث قائمة الأصوات المتاحة عند التهيئة
    await _loadAvailableVoices();
    await _configureTtsSettings();


    final parts = _currentLanguageCode.split('-');
    Get.updateLocale(Locale(parts[0], parts.length > 1 ? parts[1] : null));

    if(!_speechToTextInitialized) {
      await initSpeech();
    }

    _isAppInitialized = true;
    update();
    if (kDebugMode) print("Controller initialized. Locale set to: $_currentLanguageCode");
  }

  Future<void> _loadAvailableVoices() async {
    try {
      _availableVoices = await _flutterTts.getVoices;
      if (kDebugMode) print("Loaded ${_availableVoices.length} available TTS voices.");
    } catch (e) {
      if (kDebugMode) print("Error loading TTS voices: $e");
      _availableVoices = [];
    }
  }

  Future<void> _loadUserProfile() async {
    final String? jsonString = _prefs.getString(USER_PROFILE_KEY);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        _userProfile = UserProfile.fromJson(jsonMap);
        _gestureConfig = {
          'shakeTwiceAction': ActionTypeExtension.fromCodeName(_userProfile!.shakeTwiceAction),
          'tapThreeTimesAction': ActionTypeExtension.fromCodeName(_userProfile!.tapThreeTimesAction),
          'longPressAction': ActionTypeExtension.fromCodeName(_userProfile!.longPressAction),
        };
        if (kDebugMode) print("UserProfile loaded successfully.");
      } catch (e) {
        if (kDebugMode) print("Error loading UserProfile: $e");
        _userProfile = null;
      }
    } else {
      _userProfile = null;
    }
  }

  // ----------------------------------------------------------------------
  // 🌐 الدوال المطلوبة للغة والملف الشخصي
  // ----------------------------------------------------------------------

  void updateLocale(Locale locale) {
    final newLanguageCode = '${locale.languageCode}-${locale.countryCode}';
    _currentLanguageCode = newLanguageCode;
    Get.updateLocale(locale);
    update();
  }

  // 🆕 دالة للحصول على اسم صوت TTS افتراضي حسب اللغة والجنس (من الإضافات)
  String _getTtsVoiceName(String langCode, AssistantVoice voice) {
    // أمثلة لأصوات TTS (يجب التحقق منها)
    if (langCode.startsWith('ar')) {
      return voice == AssistantVoice.male ? 'ar-SA-Standard-C' : 'ar-SA-Standard-A';
    }
    return voice == AssistantVoice.male ? 'en-US-Standard-C' : 'en-US-Standard-A';
  }

  // 💡 الدالة الشاملة المطلوبة: setLocaleAndTTS - تم تحديثها لاستخدام Enum
  Future<void> setLocaleAndTTS(String fullLocaleCode, AssistantVoice voice) async { // ⚠️ تم تغيير نوع الـ gender إلى AssistantVoice
    if (kDebugMode) print("Setting Locale/TTS to: $fullLocaleCode, Voice: $voice");

    // 1. إيقاف النطق الحالي
    await stopTts();

    final parts = fullLocaleCode.split('-');
    final locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);

    // 2. تحديث وحفظ اللغة وإعدادات GetX
    _currentLanguageCode = fullLocaleCode;
    Get.updateLocale(locale);
    await _prefs.setString(LANGUAGE_CODE_KEY, fullLocaleCode);

    // 3. تحديث وحفظ الصوت
    _assistantVoiceSetting = voice;
    await _prefs.setString('assistantVoice', voice.name); // 🆕 حفظ اسم الـ Enum

    // 4. تجهيز أو تحديث الملف الشخصي
    final String voiceKey = voice.name; // تحويل الـ Enum إلى String للحفظ في UserProfile

    UserProfile currentProfile = _userProfile ?? UserProfile(
      // استخدام قيم افتراضية لملف شخصي جديد
      fullName: '',
      age: 0,
      email: '',
      password: '',
      bloodType: '',
      sex: '',
      allergies: '',
      medications: '',
      diseases: '',
      localeCode: fullLocaleCode,
      speechRate: 0.5,
      volume: 1.0,
      assistantVoice: voiceKey, // استخدام Enum
      shakeTwiceAction: ActionType.sos_emergency.codeName,
      tapThreeTimesAction: ActionType.call_contact.codeName,
      longPressAction: ActionType.disable_feature.codeName,
    );

    if (_userProfile != null) {
      // تحديث وحفظ الملف الشخصي باللغة والصوت الجديدين
      final updatedProfile = _userProfile!.copyWith(
        localeCode: fullLocaleCode,
        assistantVoice: voiceKey, // تحديث الجنس
      );
      await saveUserProfile(updatedProfile, updateLocale: false);
    } else {
      // حفظ الملف الشخصي الجديد
      await saveUserProfile(currentProfile, updateLocale: false);
    }

    // 5. تطبيق إعدادات TTS
    await _configureTtsSettings();

    // 6. ⛔️ FIX: إزالة التنقل Get.offAll() من هنا لكي لا يحدث الخطأ في main() قبل تشغيل GetMaterialApp.
    // التنقل الآن يتم بواسطة SplashScreen.
    // Get.offAll(() => const SignUpScreen());

    Future.microtask(() => update());
  }


  Future<bool> saveUserProfile(UserProfile profile, {bool updateLocale = true}) async {
    try {
      final jsonString = jsonEncode(profile.toJson());
      await _prefs.setString(USER_PROFILE_KEY, jsonString);
      await _prefs.setString(USER_PROFILE_PREFS_KEY, jsonString);

      _userProfile = profile;

      // 🆕 تحديث متغير الـ AssistantVoice
      final String profileVoiceKey = profile.assistantVoice.toLowerCase();
      _assistantVoiceSetting = (profileVoiceKey == 'male') ? AssistantVoice.male :
      (profileVoiceKey == 'female') ? AssistantVoice.female : AssistantVoice.none;
      await _prefs.setString('assistantVoice', _assistantVoiceSetting.name);


      _gestureConfig = {
        'shakeTwiceAction': ActionTypeExtension.fromCodeName(profile.shakeTwiceAction),
        'tapThreeTimesAction': ActionTypeExtension.fromCodeName(profile.tapThreeTimesAction),
        'longPressAction': ActionTypeExtension.fromCodeName(profile.longPressAction),
      };

      if (updateLocale) {
        _currentLanguageCode = profile.localeCode;
        await _prefs.setString(LANGUAGE_CODE_KEY, profile.localeCode);
        final parts = _currentLanguageCode.split('-');
        Get.updateLocale(Locale(parts[0], parts.length > 1 ? parts[1] : null));
      }

      await _configureTtsSettings();
      update();

      if (kDebugMode) print("UserProfile saved: ${profile.fullName}");
      return true;
    } catch (e) {
      if (kDebugMode) print("CRITICAL ERROR: Failed to save user profile: $e");
      await speak("profile_save_failed".tr);
      return false;
    }
  }

  Future<void> _clearUserData() async {
    _userProfile = null;
    await _prefs.remove(USER_PROFILE_KEY);
    await _prefs.remove(LANGUAGE_CODE_KEY);
    await _prefs.remove(USER_PROFILE_PREFS_KEY);
    await _prefs.remove(GESTURE_CONFIG_PREFS_KEY);
    await _prefs.remove('assistantVoice'); // 🆕 إزالة مفتاح الصوت

    _assistantVoiceSetting = AssistantVoice.none; // 🆕 إعادة تعيين
    _currentLanguageCode = 'en-US';
    Get.updateLocale(const Locale('en', 'US'));

    update();
  }

  Future<void> clearUserProfile() async {
    await _clearUserData();
    await speak("profile_cleared_message".tr);
  }

  Future<void> clearUserProfileAndLogout() async {
    await _clearUserData();
  }

  Future<void> clearAllData() async {
    await _prefs.remove(USER_PROFILE_KEY);
    await _prefs.remove(LANGUAGE_CODE_KEY);
    await _prefs.remove(USER_PROFILE_PREFS_KEY);
    await _prefs.remove(GESTURE_CONFIG_PREFS_KEY);
    await _prefs.remove('assistantVoice'); // 🆕 إزالة مفتاح الصوت

    userProfile = null;
    _assistantVoiceSetting = AssistantVoice.none; // 🆕 إعادة تعيين
    _currentLanguageCode = 'en-US';
    Get.updateLocale(const Locale('en', 'US'));

    stopListening(shouldSpeakStop: false);
    if (connectedDevice != null) {
      await disconnect();
    }

    _isAppInitialized = false;

    update();
    if (kDebugMode) print("All user data and connections cleared.");
  }


  // ------------------------------------------------------------------------
  // 4. TTS & STT Logic (Enhancements)
  // ------------------------------------------------------------------------

  Future<void> _configureTtsSettings() async {
    await _flutterTts.stop();
    try {
      // 1. إعداد اللغة
      await _flutterTts.setLanguage(_currentLanguageCode);

      // 2. محاولة إيجاد الصوت المطابق للجنس المفضل
      final String targetVoiceKey = _assistantVoiceSetting.name; // 🆕 استخدام الـ Enum

      if (_assistantVoiceSetting != AssistantVoice.none) {
        // تحديث الأصوات للتأكد من الحصول على القائمة الأحدث
        await _loadAvailableVoices();

        final String currentLanguage = _currentLanguageCode.split('-').first;

        dynamic matchingVoice = _availableVoices.firstWhereOrNull(
              (v) {
            final String voiceName = v['name']?.toString().toLowerCase() ?? '';
            final String voiceLocale = v['locale']?.toString().toLowerCase() ?? '';
            final String? voiceGender = v['gender']?.toString().toLowerCase(); // قد يكون null

            final bool isCorrectLocale = voiceLocale.startsWith(currentLanguage);

            // 🔑 منطق البحث المحسّن: يعتمد على الخاصية 'gender' أولاً، ثم يبحث في اسم الصوت
            final bool isCorrectGenderProperty = (targetVoiceKey == 'male' && voiceGender == 'male') ||
                (targetVoiceKey == 'female' && voiceGender == 'female');

            // بحث في الاسم كاحتياطي
            final bool isCorrectGenderInName = (targetVoiceKey == 'male' && (voiceName.contains('male') || voiceName.contains('boy'))) ||
                (targetVoiceKey == 'female' && (voiceName.contains('female') || voiceName.contains('girl')));

            return isCorrectLocale && (isCorrectGenderProperty || isCorrectGenderInName);
          },
        );

        // 3. تطبيق الصوت إذا وجد
        if (matchingVoice != null) {
          await _flutterTts.setVoice(matchingVoice as Map<String, String>);
          if (kDebugMode) print("TTS Voice set to: ${matchingVoice['name']} in locale $_currentLanguageCode (Gender: $targetVoiceKey)");
        } else {
          if (kDebugMode) print("Warning: Specific ${targetVoiceKey} voice not found for locale $_currentLanguageCode. Using default TTS voice for locale.");
          await _flutterTts.setLanguage(_currentLanguageCode); // العودة إلى اللغة فقط
        }
      } else {
        // لم يتم تحديد جنس الصوت، استخدام الافتراضي للغة
        await _flutterTts.setLanguage(_currentLanguageCode);
      }


      // 4. إعداد السرعة ومستوى الصوت
      await _flutterTts.setSpeechRate(speechRate);
      await _flutterTts.setVolume(volume);

    } catch (e) {
      if (kDebugMode) print("Error configuring TTS: $e");
    }
  }

  Future<void> updateTtsSettings({double? rate, double? vol, String? locale}) async {
    if (_userProfile == null) return;

    final updatedProfile = _userProfile!.copyWith(
      speechRate: rate,
      volume: vol,
      localeCode: locale,
    );
    await saveUserProfile(updatedProfile);
  }

  // 💡 الدالة المطلوبة: updateAssistantVoice - تم تحديثها لاستخدام Enum
  Future<void> updateAssistantVoice(AssistantVoice voice) async { // ⚠️ تم تغيير نوع الإدخال
    if (_userProfile == null) return;

    // 1. تحديث وحفظ الإعداد الجديد
    _assistantVoiceSetting = voice;
    await _prefs.setString('assistantVoice', voice.name); // 🆕 حفظ اسم الـ Enum

    // 2. تحديث وحفظ الملف الشخصي (للحفاظ على التوافق مع بيانات المستخدم)
    final updatedProfile = _userProfile!.copyWith(
      assistantVoice: voice.name,
    );
    // 🔑 حفظ الملف الشخصي دون تحديث الـ locale (يتم الحفظ فقط)
    await saveUserProfile(updatedProfile, updateLocale: false);

    // 3. تطبيق إعدادات TTS فوراً (للتجربة)
    await _configureTtsSettings();

    if (kDebugMode) print("Assistant voice set to $voice and TTS settings configured immediately.");
  }

  /// نطق النص المحدد بعد إيقاف أي عملية استماع أو نطق
  Future<void> speak(String text, {String? localeCode, String? voice}) async {
    await _flutterTts.stop();

    if (_speechToText.isListening) {
      await _speechToText.stop();
      _isListening = false;
      update();
    }

    _flutterTts.setCompletionHandler(() {
      update();
    });

    // 🔑 إعادة تهيئة إعدادات TTS لتطبيق الصوت والجنس الأحدث
    await _configureTtsSettings();

    // 🔑 استخدام .tr لضمان التعريب بناءً على GetX
    await _flutterTts.speak(text.tr);
    update();
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // 💡 الدالة المطلوبة: stopTts
  Future<void> stopTts() async {
    await stop();
    if (kDebugMode) print("TTS speaking stopped.");
  }


  /// 🔑 تم إضافة هذه الدالة لحل خطأ stopSpeaking() الذي ظهر في الـ log
  Future<void> stopSpeaking() async {
    await stop();
  }

  // ------------------------------------------------------------------------
  // 🎙️ STT Logic (Speech-to-Text) - Robust Initialization
  // ------------------------------------------------------------------------

  Future<void> _initStt() async {
    if (kIsWeb) {
      _speechToTextInitialized = true;
      return;
    }

    final status = await Permission.microphone.request();

    if (status.isGranted) {
      await initSpeech();
    } else {
      await speak('microphone_permission_denied_tts'.tr);
      if (kDebugMode) print("Microphone permission denied.");
    }
  }


  Future<void> initSpeech() async {
    if (_speechToTextInitialized) return;

    try {
      if (kIsWeb) {
        _speechToTextInitialized = true;
        return;
      }

      final isAvailable = await _speechToText.initialize(
        onError: (e) {
          if (kDebugMode) print('STT Error: ${e.errorMsg}');
          _isListening = false;
          _sttTimeoutTimer?.cancel();
          update();
          speak("speech_recognition_error".tr);
        },
        onStatus: (status) {
          if (kDebugMode) print('STT Status: $status');
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening') {
            _isListening = false;
            _sttTimeoutTimer?.cancel();
          }
          update();
        },
      );

      if (isAvailable) {
        _speechToTextInitialized = true;
        if (kDebugMode) print("SpeechToText initialized successfully.");
      } else {
        if (kDebugMode) print("SpeechToText not available or permissions denied.");
        speak("speech_not_available".tr);
      }
    } catch (e) {
      if (kDebugMode) print("Critical STT Initialization Error: $e");
      speak("speech_initialization_error".tr);
    } finally {
      update();
    }
  }

  /// بدء عملية الاستماع
  Future<void> startListening({required Function(String) onResult}) async {
    if (!_speechToTextInitialized) {
      await _initStt();
      if (!_speechToTextInitialized) {
        await speak("speech_recognition_error".tr);
        return;
      }
    }

    if (_isListening) return;

    _lastWords = '';
    _isListening = true;
    update();

    _sttTimeoutTimer?.cancel();
    _sttTimeoutTimer = Timer(_maxListeningDuration, () {
      if (kDebugMode) print("STT Timeout reached. Processing last words.");
      stopListening(shouldSpeakStop: false);
      onResult(_lastWords);
      speak('listening_timeout_prompt'.tr);
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          update();

          if (result.finalResult) {
            _sttTimeoutTimer?.cancel();
            stopListening(shouldSpeakStop: false);
            onResult(_lastWords);
          }
        },
        localeId: _currentLanguageCode,
        listenFor: _maxListeningDuration,
      );
    } catch (e) {
      if (kDebugMode) print("Error during listening: $e");
      _sttTimeoutTimer?.cancel();
      stopListening(shouldSpeakStop: false);
      onResult('');
      await speak("speech_recognition_error".tr);
    }
  }

  /// إيقاف عملية الاستماع
  void stopListening({bool shouldSpeakStop = true}) {
    _sttTimeoutTimer?.cancel();
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    if (_isListening) {
      _isListening = false;
      update();
    }
  }

  // ----------------------------------------------------------------------
  // 🧠 Gemini Integration (لمعالجة أوامر الدردشة والتنقل)
  // ----------------------------------------------------------------------

  /// Helper to check if the command is a likely navigation request (للتنقل)
  bool _isNavigationCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    return lowerText.startsWith('go to') ||
        lowerText.startsWith('take me to') ||
        lowerText.startsWith('navigate to') ||
        lowerText.startsWith('open') ||
        lowerText.startsWith('return') ||
        lowerText.startsWith('go back') ||
        lowerText.contains('شاشة') ||
        lowerText.contains('اذهب إلى') ||
        lowerText.contains('العودة') ||
        lowerText.contains('اريد');
  }

  /// **🔑 الدالة المركزية المطلوبة: processSttResultAsCommandOrQuery**
  /// تقوم بتحليل النص المدخل وتوجيهه إما للتنقل أو لنموذج الدردشة.
  Future<String> processSttResultAsCommandOrQuery(String text) async {
    if (text.isEmpty) {
      await speak("no_command_received".tr);
      return "No text received.";
    }

    // 1. محاولة معالجة الأمر كأمر تنقل
    if (_isNavigationCommand(text)) {
      final navigationResult = await handleNavigationCommand(text);

      // نطق نتيجة التنقل فوراً
      await speak(navigationResult);

      // إذا نجح التنقل أو كان أمر 'العودة'
      if (navigationResult != 'screen_not_found'.tr && navigationResult != 'navigation_parse_error'.tr) {
        return navigationResult;
      }

      // إذا فشل التنقل، يتم تمرير النص لنموذج Gemini كـ fallback
    }

    // 2. إذا لم يكن أمراً واضحاً أو أمر تنقل فاشل، يتم إرساله كاستفسار لنموذج الدردشة العام
    final geminiText = await processVoiceCommand(text);
    await speak(geminiText);

    return geminiText;
  }

  /// دالة معالجة الأوامر الصوتية الجاهزة للاستخدام في أي شاشة (Gemini Chat)
  Future<String> processVoiceCommand(String text) async {
    if (GEMINI_API_KEY.isEmpty || GEMINI_API_KEY == 'AIzaSyBwOMGLGl6GJsKkgvyT2Mz57vmdNWhOZJI') {
      return "gemini_not_configured".tr;
    }

    final profile = _userProfile;
    final languageCode = _currentLanguageCode.split('-').first;
    final languageName = languageCode == 'ar' ? 'Arabic' : 'English';

    // 🔑 سياق المستخدم (User Context)
    final String userContext = profile != null ? '''
    User Profile Details:
    - Name: ${profile.fullName}
    - Age: ${profile.age}
    - Blood Type: ${profile.bloodType}
    - Allergies: ${profile.allergies}
    - Medications: ${profile.medications}
    - Diseases/Conditions: ${profile.diseases}
    ''' : 'User profile details are unavailable.';


    final String systemInstruction = '''
    You are an AI assistant specialized for blind and visually impaired users, providing brief, actionable, and voice-friendly responses. 
    Your primary goal is clarity and conciseness for a voice interface.
    
    $userContext
    
    Your tasks are:
    1. **Execute Commands:** If the request is a simple command (like 'call contact' or 'SOS'), respond with a confirmation phrase, but do not execute the action yourself.
    2. **Answer Questions:** If the request is a general question, answer it concisely.
    3. **Use Context:** If the request relates to their medical history, allergies, age, or name, use the available profile details to provide the requested information.
    4. **If the request is nonsensical or unclear, ask the user to repeat the command.**
    Respond in the user's current language: $languageName. Keep the response brief and direct.
    ''';

    try {
      final response = await _chatModel.generateContent(
        [
          Content.system(systemInstruction),
          Content.text(text),
        ],
      );
      return response.text ?? 'no_response_received'.tr;
    } catch (e) {
      if (kDebugMode) {
        print("Gemini Chat Error: $e");
      }
      return 'smart_assistant_error'.tr;
    }
  }


  Future<String> processAllergyCommand(String query) async {
    if (GEMINI_API_KEY.isEmpty || GEMINI_API_KEY == 'AIzaSyBwOMGLGl6GJsKkgvyT2Mz57vmdNWhOZJI') {
      return "gemini_not_configured".tr;
    }

    const List<String> availableAllergens = [
      'Peanut', 'Milk / Dairy', 'Egg', 'Soybean', 'Wheat / Gluten',
      'Other Food', 'Shellfish', 'Fish', 'Cat Dander', 'Dog Dander',
      'Rodent', 'Other Pet', 'Antibiotics', 'Anesthetics',
      'Insect Sting Venom', 'NSAIDs', 'Other Medication', 'Pollen',
      'Dust Mites', 'Mold', 'Cockroach', 'Smoke / Fumes', 'Other Env'
    ];
    final String allergenList = availableAllergens.join(', ');

    final String systemInstruction = '''
    You are an AI command parser for a blind user's device. Your *only* function is to interpret the user's voice command regarding allergies and output a structured command.
    The list of valid allergens is: $allergenList.
    
    Rules for output:
    1. **ACTION:** Determine if the user wants to 'ADD' or 'REMOVE' one or more allergens.
    2. **OUTPUT FORMAT:** The response *must* start with 'ALLERGY_UPDATE:' followed by the action and a comma-separated list of the *exact* allergen names from the list above.
    3. **If the command is unclear or asks a question, respond with a short phrase in the user's language (e.g., 'Please specify which allergy to add.') and do not use the ALLERGY_UPDATE: prefix.**

    Example Commands and Outputs:
    - User: "Add milk and egg." -> Output: "ALLERGY_UPDATE:ADD:Milk / Dairy,Egg"
    - User: "Remove peanut allergy." -> Output: "ALLERGY_UPDATE:REMOVE:Peanut"
    
    Respond in a single, unformatted line.
    ''';

    try {
      final response = await _chatModel.generateContent(
        [
          Content.system(systemInstruction),
          Content.text(query),
        ],
      );
      return response.text?.trim() ?? 'no_response_received'.tr;
    } catch (e) {
      if (kDebugMode) {
        print("Gemini Allergy Error: $e");
      }
      return 'smart_assistant_error'.tr;
    }
  }

  /// دالة طلب الرد من Gemini والنطق به مباشرة (للتوافق مع الاستدعاءات القديمة أو الـ fallbacks)
  Future<String> getGeminiResponse(String prompt) async {
    stopListening(shouldSpeakStop: false);
    await speak("processing_command".tr);
    final geminiText = await processVoiceCommand(prompt);
    await speak(geminiText);

    return geminiText;
  }

  /// الدالة العامة لمعالجة أمر التنقل وتنفيذه والنطق بالنتيجة.
  /// هذه الدالة تقوم بالتنقل وإرجاع الرسالة المطلوبة، والدالة processSttResultAsCommandOrQuery تتولى النطق.
  Future<String> handleNavigationCommand(String voiceCommand) async {
    // 1. تحليل الأمر الصوتي
    final parsedCommand = await _parseVoiceCommand(voiceCommand);
    final action = parsedCommand['action'];
    final target = parsedCommand['target'];

    // 2. معالجة أمر العودة للخلف
    if (action == 'RETURN' && target == 'back') {
      if (Get.previousRoute.isNotEmpty) {
        Get.back();
        return 'going_back'.tr;
      } else {
        return 'screen_not_found'.tr; // يمكن استخدام رسالة مختلفة لعدم وجود مسار سابق
      }
    }

    // 3. معالجة أمر التنقل لشاشة محددة
    if (action == 'NAVIGATE') {
      final String? targetPath = _AVAILABLE_SCREENS[target];

      if (targetPath != null) {
        // التأكد من أننا لسنا على الشاشة المطلوبة بالفعل
        if (Get.currentRoute != targetPath) {
          Get.toNamed(targetPath);
        }

        final screenName = target!.tr;
        return 'navigating_to'.trParams({'screen': screenName});
      } else {
        return 'screen_not_found'.tr;
      }
    } else {
      // UNKNOWN أو ERROR
      return 'navigation_parse_error'.tr;
    }
  }

  /// دالة داخلية لتحليل أمر التنقل الصوتي باستخدام نموذج Gemini
  Future<Map<String, String>> _parseVoiceCommand(String query) async {
    if (GEMINI_API_KEY.isEmpty || GEMINI_API_KEY == 'AIzaSyBwOMGLGl6GJsKkgvyT2Mz57vmdNWhOZJI') {
      return {'action': 'UNKNOWN', 'target': 'ERROR'};
    }

    final languageCode = _currentLanguageCode.split('-').first;
    final screenKeys = _AVAILABLE_SCREENS.keys.toList().join(', ');

    final String systemInstruction = '''
    You are an AI command parser for navigation in a voice-controlled application. Your *only* function is to interpret the user's voice command and output a structured JSON instruction.

    The user speaks in language code: $languageCode.
    Available screen keys are: $screenKeys.
    The user can also say commands like 'go back' or 'return'.

    Rules for output:
    1. **ACTION:** Determine the user's intent: 'NAVIGATE', 'RETURN', or 'UNKNOWN'.
    2. **TARGET:** If 'NAVIGATE', use the exact screen key (lowercase) from the list. If 'RETURN', use 'back'. If 'UNKNOWN', use 'NOT_APPLICABLE'.
    3. **OUTPUT FORMAT:** The response *must* be a single JSON object: {"action": "ACTION_TYPE", "target": "TARGET_NAME"}.
    
    Respond in a single, unformatted line containing only the JSON object.
    ''';

    try {
      final response = await _navigationModel.generateContent(
        [
          Content.system(systemInstruction),
          Content.text(query),
        ],
      );

      String jsonText = response.text!.trim();
      jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();

      final Map<String, dynamic> result = json.decode(jsonText);
      return {
        'action': result['action'] as String,
        'target': result['target'] as String,
      };

    } catch (e) {
      if (kDebugMode) {
        print("Gemini Navigation Error: $e");
      }
      return {'action': 'UNKNOWN', 'target': 'ERROR'};
    }
  }

  // ------------------------------------------------------------------------
  // 5. Bluetooth Logic
  // ------------------------------------------------------------------------

  Future<void> startScan() async {
    if (!kIsWeb) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (statuses.values.any((s) => s != PermissionStatus.granted)) {
        await speak("bluetooth_permissions_denied".tr);
        return;
      }
    }
    if (!await FlutterBluePlus.isSupported) {
      await speak("bluetooth_not_supported".tr);
      return;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      await speak("bluetooth_not_enabled".tr);
      return;
    }
    if (_isScanning) return;
    _isScanning = true;
    scanResults.clear();
    update();
    await speak("scanning_for_devices".tr);
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(SERVICE_UUID)],
        timeout: const Duration(seconds: 4),
      );
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (!scanResults.any((e) => e.device.remoteId == r.device.remoteId)) {
            scanResults.add(r);
          }
        }
        update();
      });
    } catch (e) {
      if (kDebugMode) print("Scan Error: $e");
      await speak("scan_error_occurred".tr);
    } finally {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      update();
      if (scanResults.isEmpty) {
        await speak("no_devices_found".tr);
      } else {
        await speak("found_devices_count".trParams({'count': scanResults.length.toString()}));
      }
    }
  }

  Future<void> stopScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      update();
      if (kDebugMode) print("Manual scan stop requested.");
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    if (_isConnecting) return;
    _isConnecting = true;
    update();
    await speak("connecting_to_device".trParams({'device': device.platformName}));

    try {
      await device.connect(
        timeout: const Duration(seconds: 5),
      );
      connectedDevice = device;
      _isConnecting = false;
      await _subscribeToDataCharacteristic(device);
      await speak("connected_successfully".tr);
    } catch (e) {
      if (kDebugMode) print("Connection failed: $e");
      await speak("connection_failed".tr);
      _isConnecting = false;
      connectedDevice = null;
      update();
    }
  }

  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await _dataSubscription?.cancel();
      await connectedDevice!.disconnect();
      connectedDevice = null;
      _receivedDataMessage = 'No data received yet.';
      update();
      await speak("disconnected_message".tr);
    }
  }

  Future<void> _subscribeToDataCharacteristic(BluetoothDevice device) async {
    final characteristic = await _findServiceCharacteristic(
        device, SERVICE_UUID, DATA_CHAR_UUID);
    if (characteristic != null) {
      await characteristic.setNotifyValue(true);
      _dataSubscription = characteristic.value.listen((value) {
        if (value.isNotEmpty) {
          final command = utf8.decode(value);
          _handleReceivedData(command);
        }
      });
      if (kDebugMode) print('Subscribed to data char.');
    } else {
      await speak('data_channel_not_found'.tr);
    }
  }

  Future<void> sendMockData(String command) async {
    if (connectedDevice == null) {
      await speak("not_connected_to_device".tr);
      return;
    }
    _receivedDataMessage = 'Sent Mock Command: $command';
    update();
    await speak("data_sent_success".trParams({'command': command}));
  }

  Future<void> sendGestureConfig(Map<String, String> config) async {
    if (connectedDevice == null) {
      await speak("not_connected_to_device".tr);
      return;
    }

    try {
      _gestureConfig = config.map((key, value) => MapEntry(key, ActionTypeExtension.fromCodeName(value)));

      final String configJson = jsonEncode(config);
      // 💡 هنا يجب إضافة منطق إرسال البيانات الفعلية عبر BLE

      if (kDebugMode) print("Sending config: $configJson");

      await speak("settings_sent_success".tr);
    } catch (e) {
      if (kDebugMode) print("Error sending config: $e");
      await speak("failed_to_send_settings".tr);
    }
    update();
  }


  void _handleReceivedData(String command) {
    if (kDebugMode) print('Received: $command');
    final spokenMessageKey = _mapCommandToMessage(command);

    final spokenMessage = spokenMessageKey.contains('COMMAND_DEFAULT')
        ? "command_received".trParams({'command': command}) ?? 'Command received: $command'
        : spokenMessageKey.tr;

    speak(spokenMessage);

    _receivedDataMessage = 'Last Command: $command';
    update();
  }

  String _mapCommandToMessage(String command) {
    switch (command) {
      case 'SOS_ACTIVATED':
        return 'sos_activated_message';
      case 'CALL_CONTACT_L':
        return 'calling_contact';
      case 'BATTERY_LOW':
        return 'battery_low';
      case 'SETTINGS_ACK':
        return 'settings_confirmed';
      default:
        return 'COMMAND_DEFAULT';
    }
  }

  Future<BluetoothCharacteristic?> _findServiceCharacteristic(
      BluetoothDevice device, String serviceUuid, String charUuid) async {

    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
    } catch (e) {
      if (kDebugMode) print("Error discovering services: $e");
      return null;
    }

    final candidates = services
        .where((s) => s.uuid.str.toLowerCase() == serviceUuid.toLowerCase())
        .toList();

    final customService = candidates.isNotEmpty ? candidates.first : null;

    if (customService != null) {
      final charCandidates = customService.characteristics
          .where((c) => c.uuid.str.toLowerCase() == charUuid.toLowerCase())
          .toList();

      return charCandidates.isNotEmpty ? charCandidates.first : null;
    }

    return null;
  }

  @override
  void onClose() {
    if (connectedDevice != null) {
      connectedDevice!.disconnect();
    }
    _sttTimeoutTimer?.cancel();
    _speechToText.stop();
    _dataSubscription?.cancel();
    _flutterTts.stop();
    super.onClose();
  }
}