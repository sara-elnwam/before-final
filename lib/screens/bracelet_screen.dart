import 'package:flutter/material.dart';
import '../services/ble_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui';
import 'package:get/get.dart';

import 'main_chat_screen.dart';
import 'glasses_screen.dart';
import 'cane_screen.dart';
import 'gesture_config_screen.dart';
import 'earpods_screen.dart';
// 🚀 الإضافة الجديدة: استيراد الشريط السفلي المشترك
import '../widgets/common_bottom_nav_bar.dart';

const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF2D2929);
const Color cardColor = Color(0xFF282424);
const Color onBackground = Colors.white;

const Color newDarkBackground = Color(0xFF1D1D1D);
const Color gradientTopColor = Color(0xFF2D2929);
const Color gradientMidColor = Color(0xFF221F1F);

class BraceletScreen extends StatefulWidget {
  const BraceletScreen({super.key});

  @override
  State<BraceletScreen> createState() => _BraceletScreenState();
}

class _BraceletScreenState extends State<BraceletScreen> {
  bool _isConnected = true;
  final String _batteryLevel = '36%';
  final String _timeRemaining = '3h 20m';

  bool _showSensorsView = false;

  List<bool> _sensorConnectionStatus = [true, true, true, false];

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
      'device': 'device_bracelet'.tr,
      'level': _batteryLevel,
      'time': _timeRemaining,
    }));
  }

  void _onLongPressStart() {
    if (!_isConnected) {
      _bleController.speak('device_status_off'.trParams({'device': 'device_bracelet'.tr}));
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
    } else if (normalizedCommand.contains('cane') || normalizedCommand.contains('عصا')) {
      navigateTo(const CaneScreen(), 'device_cane');
    } else if (normalizedCommand.contains('earpods') || normalizedCommand.contains('سماعات')) {
      navigateTo(const EarpodsScreen(), 'device_earpods');
    } else if (normalizedCommand.contains('bracelet') || normalizedCommand.contains('سوار')) {
      bleController.speak('already_on_screen'.trParams({'device': 'device_bracelet'.tr}));
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

  void _toggleView() {
    setState(() {
      _showSensorsView = !_showSensorsView;
    });
    if (_showSensorsView) {
      _bleController.speak('bracelet_sensor_view_on'.tr);
    } else {
      _bleController.speak('bracelet_sensor_view_off'.tr);
    }
  }

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
    });
    final statusKey = _isConnected ? 'status_on' : 'status_off';
    _bleController.speak(statusKey.trParams({'device': 'device_bracelet'.tr}));
  }

  void _toggleSensorStatus(int index) {
    setState(() {
      _sensorConnectionStatus[index] = !_sensorConnectionStatus[index];
    });
    final sensorNames = [
      'sensor_left_hand'.tr,
      'sensor_right_hand'.tr,
      'sensor_left_leg'.tr,
      'sensor_right_leg'.tr
    ];
    final sensorName = sensorNames[index];
    final statusKey = _sensorConnectionStatus[index] ? 'status_connected' : 'status_disconnected';

    _bleController.speak('sensor_status_changed'.trParams({
      'sensor': sensorName,
      'status': statusKey.tr,
    }));
  }

  void _handleDoubleTap() {
    _bleController.speak('returning_to_home'.tr);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
                    style: const TextStyle(color: onBackground, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        );

        return GestureDetector(
          onTap: _toggleView,
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: _onLongPressEnd,
          onDoubleTap: () => _handleDoubleTap(),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _showSensorsView ? 'assets/images/bracelet4.jpg' : 'assets/images/bracelet.jpg',
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!_showSensorsView)
                            InkWell(
                              onTap: () => Get.back(),
                              child: const Icon(Icons.arrow_back_ios, color: onBackground, size: 24),
                            ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: _showSensorsView ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'device_bracelet'.tr,
                                  textAlign: _showSensorsView ? TextAlign.start : TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _showSensorsView ? 32 : 24,
                                    fontWeight: _showSensorsView ? FontWeight.w500 : FontWeight.w600,
                                    color: const Color(0xFFF8F8F8),
                                  ),
                                ),
                                if (_showSensorsView)
                                  Text(
                                    'sensor_count'.trParams({'count': '4'}),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: onBackground,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          if (!_showSensorsView)
                            const Icon(Icons.notifications_none, color: onBackground, size: 24),
                        ],
                      ),
                    ],
                  ),
                ),

                if (!_showSensorsView)
                  Positioned(
                    bottom: screenHeight * 0.10,
                    left: screenWidth * 0.112,
                    right: screenWidth * 0.112,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
                      decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _batteryLevel,
                            textAlign: TextAlign.left,
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: onBackground),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'time_remaining'.trParams({'time': _timeRemaining}),
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 14, color: onBackground.withOpacity(0.8)),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isConnected ? 'status_on'.tr : 'status_off'.tr,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: onBackground,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Switch(
                                value: _isConnected,
                                onChanged: (val) => _toggleConnection(),
                                activeTrackColor: neonColor,
                                activeThumbColor: Colors.black,
                                inactiveTrackColor: Colors.black.withOpacity(0.5),
                                inactiveThumbColor: Colors.black,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    top: 150,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
                      child: GridView.builder(
                        itemCount: 4,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final namesKeys = ['sensor_left_hand', 'sensor_right_hand', 'sensor_left_leg', 'sensor_right_leg'];
                          final names = namesKeys[index].tr;
                          final statusKey = _sensorConnectionStatus[index] ? 'status_connected' : 'status_disconnected';
                          final status = statusKey.tr;

                          return _buildSensorCard(
                            names,
                            status,
                            isConnected: _sensorConnectionStatus[index],
                            onTap: () => _toggleSensorStatus(index),
                          );
                        },
                      ),
                    ),
                  ),

                if (_isAwaitingInput || bleController.isListening)
                  chatOverlay,
              ],
            ),
            // 🚀 الإضافة الجديدة: الشريط السفلي
            bottomNavigationBar: CommonBottomNavBar(currentIndex: 0),
          ),
        );
      },
    );
  }

  Widget _buildSensorCard(String title, String status, {bool isConnected = true, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                title,
                style: const TextStyle(
                  color: onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isConnected ? neonColor : onBackground.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}