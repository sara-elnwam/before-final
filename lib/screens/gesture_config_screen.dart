// lib/screens/gesture_config_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // ✅ إضافة kDebugMode
import '../services/ble_controller.dart';
import '../enums/action_type.dart';
import 'package:get/get.dart';
import './sign_up_screen.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

// 🎨 ثوابت التصميم (مستخلصة من الملفات الأخرى)
const Color primaryAccentColor = Color(0xFFCA8428);
const Color primaryDarkBackground = Color(0xFF1B1B1B);

class GestureConfigScreen extends StatefulWidget {
  const GestureConfigScreen({super.key});

  @override
  State<GestureConfigScreen> createState() => _GestureConfigScreenState();
}

class _GestureConfigScreenState extends State<GestureConfigScreen> {
  // ⚠️ تم تغيير نوع المفتاح ليتناسب مع enum Gesture
  Map<Gesture, ActionType> _currentActionConfig = {};
  bool _isAwaitingInput = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeSettings);
  }

  // ----------------------------------------------------------------------
  // ⚙️ الإعدادات والتحميل
  // ----------------------------------------------------------------------
  void _initializeSettings() {
    final bleController = Provider.of<BleController>(context, listen: false);

    // bleController.gestureConfig هو Map<String, ActionType>
    final Map<String, ActionType> currentConfig = bleController.gestureConfig;

    if (currentConfig.isNotEmpty) {
      setState(() {
        // تحويل المفاتيح النصية إلى enum Gesture للمفتاح الداخلي
        _currentActionConfig = {
          Gesture.shake_twice: currentConfig['shakeTwiceAction'] ?? ActionType.disable_feature,
          Gesture.tap_three_times: currentConfig['tapThreeTimesAction'] ?? ActionType.disable_feature,
          Gesture.long_press: currentConfig['longPressAction'] ?? ActionType.disable_feature,
        };
      });
    } else {
      // إعداد القيم الافتراضية
      setState(() {
        _currentActionConfig = {
          Gesture.shake_twice: ActionType.sos_emergency,
          Gesture.tap_three_times: ActionType.call_contact,
          Gesture.long_press: ActionType.disable_feature,
        };
      });
    }
  }

  // ----------------------------------------------------------------------
  // 💾 دالة حفظ الإعدادات (مكان الإصلاح)
  // ----------------------------------------------------------------------
  void _saveSettings(BleController bleController) async {
    if (_currentActionConfig.isEmpty) return;

    setState(() {
      _isAwaitingInput = true; // عرض طبقة التحميل
    });

    try {
      // 1. تحويل الخريطة من Map<Gesture, ActionType> إلى Map<String, String>
      // ✅ Fix: هذا هو التحويل الذي يحل خطأ عدم تطابق النوع.
      // يتم تحويل enum Gesture إلى String (مثال: 'shake_twice') و ActionType إلى String (مثال: 'sos_emergency')
      final Map<String, String> configToSend = {
        'shakeTwiceAction': _currentActionConfig[Gesture.shake_twice]!.codeName,
        'tapThreeTimesAction': _currentActionConfig[Gesture.tap_three_times]!.codeName,
        'longPressAction': _currentActionConfig[Gesture.long_press]!.codeName,
      };

      // 2. تحديث وحفظ الملف الشخصي مع الإيماءات الجديدة
      final profile = bleController.userProfile!.copyWith(
        shakeTwiceAction: configToSend['shakeTwiceAction'],
        tapThreeTimesAction: configToSend['tapThreeTimesAction'],
        longPressAction: configToSend['longPressAction'],
      );
      await bleController.saveUserProfile(profile, updateLocale: false);

      // 3. إرسال الخريطة المحولة إلى المتحكم (هذا هو سطر الإصلاح الفعلي)
      // الآن configToSend هو Map<String, String> ويتوافق مع توقيع الدالة.
      // 💡 هذا السطر هو الذي كان يسبب الخطأ في السطر 68.
      bleController.sendGestureConfig(configToSend);

      // ✅ نطق رسالة نجاح الحفظ
      await bleController.speak('settings_sent_success'.tr);

    } catch (e) {
      await bleController.speak('save_settings_failed_prompt'.tr);
      if (kDebugMode) print('Error saving or sending settings: $e');
    }

    setState(() {
      _isAwaitingInput = false; // إخفاء طبقة التحميل
    });
  }

  // ----------------------------------------------------------------------
  // 🏗️ البناء (Build Methods)
  // ----------------------------------------------------------------------

  Widget _buildGestureSelector(Gesture gesture, ActionType currentAction) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: primaryDarkBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // عنوان الإيماءة
          Flexible(
            child: Text(
              gesture.displayName.tr, // استخدام التعريب
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // قائمة منسدلة للإجراءات
          DropdownButton<ActionType>(
            value: currentAction,
            dropdownColor: primaryDarkBackground,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            icon: const Icon(FluentIcons.chevron_down_20_regular, color: primaryAccentColor),
            underline: Container(height: 1, color: primaryAccentColor.withOpacity(0.5)),
            onChanged: (ActionType? newValue) {
              if (newValue != null) {
                setState(() {
                  _currentActionConfig[gesture] = newValue;
                });
                // نطق الإعداد الجديد فوراً
                Provider.of<BleController>(context, listen: false).speak(
                    '${gesture.displayName.tr} set to ${newValue.displayName.tr}'
                );
              }
            },
            items: ActionType.values.map<DropdownMenuItem<ActionType>>((ActionType value) {
              return DropdownMenuItem<ActionType>(
                value: value,
                // ✅ عرض اسم الإجراء المُعرّب
                child: Text(value.displayName.tr, style: const TextStyle(color: Colors.white70)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay(BleController bleController, ThemeData theme) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      constraints: const BoxConstraints.expand(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryAccentColor),
            const SizedBox(height: 20),
            Text(
              bleController.isListening
                  ? 'listening_to_you'.tr
                  : 'processing_command'.tr, // استخدام مفاتيح تعريب مناسبة
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<BleController>(
      builder: (context, bleController, child) {
        return Scaffold(
          appBar: AppBar(
            // ✅ تعريب عنوان الشاشة
            title: Text('gesture_settings_title'.tr),
            backgroundColor: primaryDarkBackground,
            foregroundColor: primaryAccentColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: primaryAccentColor),
          ),
          body: Container(
            color: primaryDarkBackground,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ تعريب رسالة التوضيح
                      Text(
                        'gesture_settings_description'.tr,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),

                      // بناء محددات الإيماءات باستخدام الـ Enum
                      ...Gesture.values.map((gesture) {
                        final currentAction = _currentActionConfig[gesture] ?? ActionType.disable_feature;
                        return _buildGestureSelector(gesture, currentAction);
                      }).toList(),

                      const SizedBox(height: 30),

                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _currentActionConfig.isNotEmpty
                              ? () => _saveSettings(bleController) // تم استدعاء دالة الحفظ
                              : null,
                          icon: const Icon(Icons.send_rounded, size: 24),
                          // ✅ تعريب نص زر الحفظ
                          label: Text('save_settings_button'.tr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ عرض طبقة المعالجة الصوتية/التحميل
                if (_isAwaitingInput || bleController.isListening)
                  _buildChatOverlay(bleController, theme),
              ],
            ),
          ),
        );
      },
    );
  }
}