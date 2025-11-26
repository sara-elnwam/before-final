import 'package:flutter/material.dart';
import '../services/ble_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui'; // لا يزال مستخدماً للـ ImageFilter لكن لن نطبقه
import 'package:get/get.dart';

import 'main_chat_screen.dart';
import 'glasses_screen.dart';
import 'bracelet_screen.dart';
import 'gesture_config_screen.dart';
import 'earpods_screen.dart';
import '../widgets/common_bottom_nav_bar.dart';

const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF242020);
const Color darkBackground = Color(0xFF141318);

const Color generalTextColor = Color(0xFFCCCCCC);
const Color batteryPercentageColor = Color(0xFFFFFFFF);

class CustomOrangeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomOrangeSwitch({
    // ✅ تم إزالة `super.key` من هنا
    super.key, // ✅ واستخدامه فقط هنا لتمريره إلى دالة بناء الأب
    required this.value,
    required this.onChanged,
  }); // ❌ تم إزالة `: super(key: key);` حيث أن `super.key` يفي بالغرض

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 60.0,
        height: 32.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.0),
          color: value ? neonColor : darkSurface,
          border: Border.all(
            color: value ? neonColor : generalTextColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Container(
                width: 22.0,
                height: 22.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? darkBackground : generalTextColor.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaneScreen extends StatefulWidget {
  const CaneScreen({super.key});

  @override
  State<CaneScreen> createState() => _CaneScreenState();
}

class _CaneScreenState extends State<CaneScreen> {
  bool _isDeviceOn = true;
  final String _batteryLevel = '36%';
  final String _timeRemaining = '3h 20m';

  bool _isAwaitingInput = false;
  String _lastSpokenPrompt = '';

  late BleController _bleController;

  @override
  void initState() {
    super.initState();
    _bleController = Get.find<BleController>();
    Future.delayed(Duration.zero, () {
      _speakWelcome(_bleController);
    });
  }

  void _speakWelcome(BleController controller) {
    controller.speak('device_screen_welcome'.trParams({
      'device': 'device_cane'.tr,
      'level': _batteryLevel,
      'time': _timeRemaining,
    }));
  }

  // ----------------------------------------------------------------------
  // 🗣️ وظائف التفاعل الصوتي (الموحد)
  // ----------------------------------------------------------------------

  void _onLongPressStart() {
    if (!_isDeviceOn) {
      _bleController.speak('device_status_off'.trParams({'device': 'device_cane'.tr}));
      return;
    }
    if (_isAwaitingInput || _bleController.isListening) return;

    _bleController.speak('listening_to_you'.tr);

    _bleController.startListening(
      onResult: (spokenText) => _handleVoiceInput(spokenText),
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_bleController.isListening) {
      _bleController.stopListening(shouldSpeakStop: false);
    }
  }

  void _handleVoiceInput(String text) async {
    if (text.isEmpty) {
      _bleController.speak('command_not_recognized'.tr);
      return;
    }

    setState(() {
      _isAwaitingInput = true;
      _lastSpokenPrompt = text;
    });

    await _bleController.speak('processing_command'.tr);

    final bool isNavigation = await _handleCommand(_bleController, text);

    if (!isNavigation) {
      // ✅ افتراض أن الدالة getGeminiResponse ترجع 'void' أو يتم التعامل معها في مكان آخر
      await _bleController.getGeminiResponse(text);
    }

    setState(() {
      _isAwaitingInput = false;
    });
  }

  Future<bool> _handleCommand(BleController bleController, String command) async {
    final normalizedCommand = command.toLowerCase().trim();
    bool isNavigation = false;

    void navigateTo(Widget screen, String key) async {
      await bleController.speak('navigating_to'.trParams({'screen': key.tr}));
      Get.off(() => screen);
      isNavigation = true;
    }

    if (normalizedCommand.contains('glasses') || normalizedCommand.contains('نظارة')) {
      navigateTo(const GlassesScreen(), 'device_glasses');
    } else if (normalizedCommand.contains('bracelet') || normalizedCommand.contains('سوار')) {
      navigateTo(const BraceletScreen(), 'device_bracelet');
    } else if (normalizedCommand.contains('earpods') || normalizedCommand.contains('سماعات')) {
      navigateTo(const EarpodsScreen(), 'device_earpods');
    } else if (normalizedCommand.contains('cane') || normalizedCommand.contains('عصا')) {
      bleController.speak('already_on_screen'.trParams({'device': 'device_cane'.tr}));
      isNavigation = true;
    } else if (normalizedCommand.contains('home') || normalizedCommand.contains('رئيسية') || normalizedCommand.contains('main')) {
      await bleController.speak('returning_to_home'.tr);
      Get.back();
      isNavigation = true;
    } else if (normalizedCommand.contains('settings') || normalizedCommand.contains('اعدادات') || normalizedCommand.contains('إعدادات')) {
      await bleController.speak('navigating_to'.trParams({'screen': 'gesture_config_screen'.tr}));
      _goToSettings();
      isNavigation = true;
    } else if (normalizedCommand.contains('emergency') || normalizedCommand.contains('طوارئ') || normalizedCommand.contains('911') || normalizedCommand.contains('نجدة')) {
      _triggerEmergencyCall(bleController);
      isNavigation = true;
    }

    return isNavigation;
  }

  void _triggerEmergencyCall(BleController bleController) async {
    const url = 'tel:911';
    if (await launchUrl(Uri.parse(url))) {
      bleController.speak('initiating_emergency_call'.tr);
    } else {
      bleController.speak('emergency_call_failed'.tr);
    }
  }

  void _goToSettings() {
    Get.to(() => const GestureConfigScreen());
  }

  void _toggleDevice(bool value) {
    setState(() {
      _isDeviceOn = value;
    });
    final statusKey = _isDeviceOn ? 'status_on' : 'status_off';
    _bleController.speak(statusKey.trParams({'device': 'device_cane'.tr}));
  }

  void _handleDoubleTap() {
    _bleController.speak('returning_to_home'.tr);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final estimatedTimeStyle = TextStyle(
      fontSize: 14,
      color: generalTextColor.withOpacity(0.8),
      fontFamily: 'Manrope',
    );

    return GetBuilder<BleController>(
      builder: (bleController) {
        final chatOverlay = Container(
          color: Colors.black.withOpacity(0.7),
          constraints: const BoxConstraints.expand(),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: darkSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: neonColor),
                  const SizedBox(height: 20),
                  Text(
                    bleController.isListening
                        ? 'listening_to_you'.tr
                        : 'processing_command'.tr,
                    style: const TextStyle(color: generalTextColor, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        );

        return GestureDetector(
          onTap: () => bleController.speak(_isDeviceOn ? 'cane_status_on'.tr : 'cane_status_off'.tr),
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: _onLongPressEnd,
          onDoubleTap: () => _handleDoubleTap(),

          child: Scaffold(
            bottomNavigationBar: CommonBottomNavBar(currentIndex: 0),
            body: Stack(
              children: [
                // 1. صورة الخلفية (الآن حادة جداً)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/cane.jpg',
                    fit: BoxFit.cover,
                  ),
                ),

                // 3. شريط العنوان (Navigation/Title Bar)
                Positioned(
                  top: screenHeight * 0.07,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        child: const Icon(Icons.arrow_back_ios, color: generalTextColor, size: 24),
                      ),
                      Text(
                        'device_cane'.tr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: generalTextColor,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const Icon(Icons.notifications_none, color: generalTextColor, size: 24),
                    ],
                  ),
                ),

                // 4. الصندوق الرئيسي (Card)
                Positioned(
                  top: screenHeight * 0.15,
                  right: 20,
                  child: SizedBox(
                    width: 240,
                    height: 190,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                        decoration: BoxDecoration(
                          color: darkSurface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(color: generalTextColor.withOpacity(0.1), width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _batteryLevel,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: batteryPercentageColor, fontFamily: 'Manrope'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'time_remaining'.trParams({'time': _timeRemaining}),
                              style: estimatedTimeStyle,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isDeviceOn ? 'status_on'.tr : 'status_off'.tr,
                                  style: const TextStyle(
                                    color: generalTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                                CustomOrangeSwitch(
                                  value: _isDeviceOn,
                                  onChanged: _toggleDevice,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. شاشة التحميل/الاستماع
                if (_isAwaitingInput || bleController.isListening)
                  chatOverlay,
              ],
            ),
          ),
        );
      },
    );
  }
}