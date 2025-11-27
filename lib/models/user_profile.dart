// models/user_profile.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:get/get.dart'; // لتحديث حالة UserProfile عند الحاجة

// 💡 مفتاح حفظ الملف الشخصي في SharedPreferences
const String USER_PROFILE_KEY = 'user_profile_data';

class UserProfile extends GetxController {
  final String fullName;
  final String email;
  final String password;
  final String emergencyPhoneNumber;

  final String sex;
  final String bloodType;

  final String allergies;
  final String medications;
  final String diseases;
  final bool isProfileComplete;
  final int age;
  final String homeAddress;

  // 🔑 FIX 1: تم استبدال 'preferredVoice' بـ 'assistantVoice'
  final String assistantVoice;

  final bool isBiometricEnabled;
  final double speechRate;
  final double volume;
  final String localeCode;

  final String shakeTwiceAction;
  final String tapThreeTimesAction;
  final String longPressAction;

  // ====================================================================
  // 🔨 الدالة البانية (Constructor)
  // ====================================================================

  UserProfile({
    required this.fullName,
    required this.email,
    required this.password,
    required this.sex,
    required this.bloodType,
    required this.allergies,
    required this.medications,
    required this.diseases,
    this.isProfileComplete = false,

    this.age = 0,
    this.homeAddress = 'Not Set',
    this.emergencyPhoneNumber = 'Not Set',
    // 🔑 FIX 2: تحديث اسم الحقل في الدالة البانية
    this.assistantVoice = 'Kore',
    this.isBiometricEnabled = false,
    this.speechRate = 0.5,
    this.volume = 1.0,
    this.localeCode = 'ar-SA',
    this.shakeTwiceAction = 'SilentMode',
    this.tapThreeTimesAction = 'EmergencyCall',
    this.longPressAction = 'VoiceCommand',
  });

  // ====================================================================
  // 🔄 دالة نسخ الكائن مع التعديل (copyWith)
  // ====================================================================

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? password,
    String? emergencyPhoneNumber,
    String? sex,
    String? bloodType,
    String? allergies,
    String? medications,
    String? diseases,
    bool? isProfileComplete,
    int? age,
    String? homeAddress,
    // 🔑 FIX 3: تحديث اسم الحقل في copyWith
    String? assistantVoice,
    bool? isBiometricEnabled,
    double? speechRate,
    double? volume,
    String? localeCode,

    String? shakeTwiceAction,
    String? tapThreeTimesAction,
    String? longPressAction,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      emergencyPhoneNumber: emergencyPhoneNumber ?? this.emergencyPhoneNumber,
      sex: sex ?? this.sex,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      diseases: diseases ?? this.diseases,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      age: age ?? this.age,
      homeAddress: homeAddress ?? this.homeAddress,
      // 🔑 FIX 4: تحديث اسم الحقل عند النسخ
      assistantVoice: assistantVoice ?? this.assistantVoice,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      localeCode: localeCode ?? this.localeCode,
      shakeTwiceAction: shakeTwiceAction ?? this.shakeTwiceAction,
      tapThreeTimesAction: tapThreeTimesAction ?? this.tapThreeTimesAction,
      longPressAction: longPressAction ?? this.longPressAction,
    );
  }

  // ====================================================================
  // 📝 دالة التحويل إلى JSON (toJson)
  // ====================================================================

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'email': email,
    'password': password,
    'emergencyPhoneNumber': emergencyPhoneNumber,
    'sex': sex,
    'bloodType': bloodType,
    'allergies': allergies,
    'medications': medications,
    'diseases': diseases,
    'isProfileComplete': isProfileComplete,
    'age': age,
    'homeAddress': homeAddress,
    // 🔑 FIX 5: تحديث اسم الحقل في toJson
    'assistantVoice': assistantVoice,
    'isBiometricEnabled': isBiometricEnabled,
    'speechRate': speechRate,
    'volume': volume,
    'localeCode': localeCode,
    'shakeTwiceAction': shakeTwiceAction,
    'tapThreeTimesAction': tapThreeTimesAction,
    'longPressAction': longPressAction,
  };

  // ====================================================================
  // 📥 دالة التحويل من JSON (fromJson)
  // ====================================================================

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    password: json['password'] as String? ?? '',
    sex: json['sex'] as String? ?? 'Not Set',
    bloodType: json['bloodType'] as String? ?? 'Not Set',
    allergies: json['allergies'] as String? ?? 'None',
    medications: json['medications'] as String? ?? 'None',
    diseases: json['diseases'] as String? ?? 'None',
    isProfileComplete: json['isProfileComplete'] as bool? ?? false,

    age: json['age'] as int? ?? 0,
    homeAddress: json['homeAddress'] as String? ?? 'Not Set',
    emergencyPhoneNumber: json['emergencyPhoneNumber'] as String? ?? 'Not Set',
    // 🔑 FIX 6: تحديث اسم الحقل في fromJson والتحقق من القيمة
    assistantVoice: json['assistantVoice'] as String? ?? 'Kore',
    isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,

    // التحقق من نوع القيمة قبل التحويل لـ double
    speechRate: (json['speechRate'] is num ? json['speechRate'] as num : 0.5).toDouble(),
    volume: (json['volume'] is num ? json['volume'] as num : 1.0).toDouble(),

    localeCode: json['localeCode'] as String? ?? 'ar-SA',
    shakeTwiceAction: json['shakeTwiceAction'] as String? ?? 'SilentMode',
    tapThreeTimesAction: json['tapThreeTimesAction'] as String? ?? 'EmergencyCall',
    longPressAction: json['longPressAction'] as String? ?? 'VoiceCommand',
  );

  // ====================================================================
  // 🌟 دالة للحالة الأولية (initial)
  // ====================================================================

  static UserProfile get initial => UserProfile(
    fullName: '',
    email: '',
    password: '',
    emergencyPhoneNumber: 'Not Set',
    sex: 'Not Set',
    bloodType: 'Not Set',
    allergies: 'None',
    medications: 'None',
    diseases: 'None',
    isProfileComplete: false,
    age: 0,
    homeAddress: 'Not Set',
    // 🔑 FIX 7: تحديث اسم الحقل في الحالة الأولية
    assistantVoice: 'Kore',
    isBiometricEnabled: false,
    speechRate: 0.5,
    volume: 1.0,
    localeCode: 'ar-SA',
    shakeTwiceAction: 'SilentMode',
    tapThreeTimesAction: 'EmergencyCall',
    longPressAction: 'VoiceCommand',
  );

  // ====================================================================
  // 💾 دالة حفظ الملف الشخصي في SharedPreferences
  // ====================================================================

  Future<void> saveProfile(SharedPreferences prefs) async {
    final profileJson = json.encode(toJson());
    await prefs.setString(USER_PROFILE_KEY, profileJson);
    // إخطار GetX بتحديث المتحكم
    update();
  }

  // ====================================================================
  // 📚 دالة استرجاع الملف الشخصي من SharedPreferences
  // ====================================================================

  static UserProfile? getSavedProfile(SharedPreferences prefs) {
    final profileJson = prefs.getString(USER_PROFILE_KEY);
    if (profileJson != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(profileJson);
        return UserProfile.fromJson(jsonMap);
      } catch (e) {
        // في حال فشل التحويل، نرجع null
        return null;
      }
    }
    return null;
  }
}