import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart'; // ✅ إضافة مكتبة GetX للتعريب
import '../services/ble_controller.dart';
import 'gesture_config_screen.dart';

// ثوابت الألوان (من الأفضل تعريفها في مكان مركزي)
const Color neonColor = Color(0xFFFFB267);

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  // ✅ حالة لتتبع عرض شاشة المعالجة عند إرسال أمر صوتي
  bool _isAwaitingInput = false;
  late BleController _bleController;

  final List<Map<String, String>> mockCommands = const [
    {"command": "OBSTACLE_FRONT", "label_key": "mock_command_obstacle_front"},
    {"command": "GESTURE_SOS", "label_key": "mock_command_sos"},
    {"command": "OBSTACLE_LEFT", "label_key": "mock_command_obstacle_left"},
    {"command": "GESTURE_CALL", "label_key": "mock_command_call"},
    {"command": "BATTERY_LOW", "label_key": "mock_command_battery_low"},
    {"command": "SETTINGS_ACK", "label_key": "mock_command_settings_ack"},
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      _bleController = Provider.of<BleController>(context, listen: false);
      // نطق إرشادات الشاشة عند الدخول (اختياري، لكن يُفضل للوصولية)
      _bleController.speak('ble_scan_welcome_instruction'.tr);
    });
  }

  // ----------------------------------------------------------------------
  // 🗣️ وظائف التفاعل الصوتي (الموحد)
  // ----------------------------------------------------------------------

  void _onLongPressStart() {
    if (_isAwaitingInput || _bleController.isListening) return;

    // 1. نطق رسالة الاستماع
    _bleController.speak('listening_to_you'.tr);

    // 2. بدء الاستماع (STT)
    _bleController.startListening(
      onResult: (spokenText) => _handleVoiceInput(spokenText),
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_bleController.isListening) {
      _bleController.stopListening(shouldSpeakStop: false);
    }
  }

  void _handleDoubleTap() {
    // ✅ النقرة المزدوجة للعودة إلى الشاشة الرئيسية
    _bleController.speak('returning_to_home'.tr);
    Navigator.of(context).pop();
  }

  void _handleVoiceInput(String text) async {
    if (text.isEmpty) {
      _bleController.speak('command_not_recognized'.tr);
      return;
    }

    // 1. عرض شاشة المعالجة
    setState(() {
      _isAwaitingInput = true;
    });

    // 2. نطق رسالة المعالجة
    await _bleController.speak('processing_command'.tr);

    // 3. التعامل مع الأمر
    await _handleCommand(text);

    // 4. إخفاء شاشة المعالجة
    setState(() {
      _isAwaitingInput = false;
    });
  }

  Future<void> _handleCommand(String command) async {
    final normalizedCommand = command.toLowerCase().trim();

    // أوامر خاصة بشاشة البلوتوث
    if (normalizedCommand.contains('scan') || normalizedCommand.contains('فحص')) {
      await _bleController.startScan();
    } else if (normalizedCommand.contains('stop') || normalizedCommand.contains('توقف')) {
      await _bleController.stopScan();
    } else if (normalizedCommand.contains('disconnect') || normalizedCommand.contains('فصل')) {
      await _bleController.disconnect();
    } else if (normalizedCommand.contains('settings') || normalizedCommand.contains('إعدادات')) {
      _bleController.speak('navigating_to'.trParams({'screen': 'settings_screen'.tr}));
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GestureConfigScreen()));
    } else {
      // محاولة الاتصال بجهاز معين
      final connectMatch = RegExp(r'(connect to|اتصل بـ) (.+)', caseSensitive: false).firstMatch(normalizedCommand);
      if (connectMatch != null) {
        final deviceName = connectMatch.group(2)?.trim() ?? '';
        final results = _bleController.scanResults;
        final targetDevice = results.firstWhereOrNull(
                (r) => r.device.platformName.toLowerCase().contains(deviceName.toLowerCase()));

        if (targetDevice != null) {
          await _bleController.connect(targetDevice.device);
        } else {
          await _bleController.speak('device_not_found'.trParams({'device': deviceName}));
        }
      } else {
        // إرسال الأمر لـ Gemini إذا لم يكن أمر محلي
        await _bleController.getGeminiResponse(command);
      }
    }
  }

  // ----------------------------------------------------------------------
  // 🎨 مكونات الواجهة (UI Components) - تم تحديث النصوص للتعريب
  // ----------------------------------------------------------------------

  Widget _buildScanResultTile(BleController bleController, ScanResult result) {
    final bool isConnectedToThisDevice = bleController.connectedDevice?.remoteId == result.device.remoteId;

    final isScanning = bleController.isScanning;
    final isConnecting = bleController.isConnecting && bleController.connectedDevice?.remoteId == result.device.remoteId;

    Widget trailingWidget;
    Function()? onPressedAction;
    Color buttonColor;
    String buttonText;

    if (isConnectedToThisDevice) {
      trailingWidget = const Icon(Icons.check_circle, color: Colors.green);
      onPressedAction = bleController.disconnect;
      buttonColor = Colors.red.shade300;
      buttonText = 'disconnect_button'.tr; // ✅ تعريب
    } else if (isConnecting) {
      trailingWidget = const CircularProgressIndicator(color: neonColor, strokeWidth: 2);
      onPressedAction = null;
      buttonColor = Colors.grey.shade300;
      buttonText = 'connecting_button'.tr; // ✅ تعريب
    } else {
      trailingWidget = isScanning
          ? const CircularProgressIndicator(color: neonColor, strokeWidth: 2)
          : const Icon(Icons.bluetooth, color: neonColor);
      onPressedAction = () => bleController.connect(result.device);
      buttonColor = neonColor;
      buttonText = 'connect_button'.tr; // ✅ تعريب
    }

    return ListTile(
      leading: trailingWidget,
      title: Text(
        result.device.platformName.isEmpty
            ? 'unknown_device'.tr // ✅ تعريب
            : result.device.platformName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('ID: ${result.device.remoteId} (RSSI: ${result.rssi})'),
      trailing: ElevatedButton(
        onPressed: onPressedAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.black,
        ),
        child: Text(buttonText),
      ),
    );
  }

  Widget _buildStatusSection(BleController bleController) {
    final bool isConnected = bleController.isConnected;

    return Container(
      color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
      padding: const EdgeInsets.all(16.0),
      child: Semantics(
        // ✅ استخدام مفاتيح تعريب
        label: 'connection_status_label'.trParams({
          'status': isConnected ? 'status_connected'.tr : 'status_disconnected'.tr,
          'message': bleController.receivedDataMessage,
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // ✅ استخدام مفاتيح تعريب
              'system_status_title'.trParams({
                'status': isConnected ? 'system_status_ready'.tr : 'system_status_prompt'.tr
              }),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bleController.receivedDataMessage,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockDataSection(BleController bleController) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ تعريب العنوان
          Text(
            'send_mock_data_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mockCommands.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemBuilder: (context, index) {
              final item = mockCommands[index];
              return ElevatedButton(
                onPressed: () => bleController.sendMockData(item["command"]!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                ),
                child: Text(
                  item["label_key"]!.tr, // ✅ تعريب نص الزر
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildChatOverlay(BleController bleController) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      constraints: const BoxConstraints.expand(),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: neonColor),
              const SizedBox(height: 20),
              Text(
                // ✅ استخدام مفاتيح التعريب
                bleController.isListening
                    ? 'listening_to_you'.tr
                    : 'processing_command'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BleController>(
      builder: (context, bleController, child) {
        final bool isScanning = bleController.isScanning;
        final bool isConnected = bleController.isConnected;

        // ✅ إضافة GestureDetector الشامل
        return GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: _onLongPressEnd,
          onDoubleTap: _handleDoubleTap,
          child: Scaffold(
            appBar: AppBar(
              // ✅ تعريب عنوان الشاشة
              title: Text('ble_scan_screen_title'.tr),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  // ✅ إضافة زر الإعدادات
                  onPressed: () {
                    _bleController.speak('navigating_to'.trParams({'screen': 'settings_screen'.tr}));
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GestureConfigScreen()));
                  },
                ),
              ],
            ),
            body: Stack(
              children: [
                ListView(
                  children: <Widget>[
                    _buildStatusSection(bleController),
                    const Divider(height: 1, thickness: 1),
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ تعريب زر الفحص
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isScanning
                                  ? bleController.stopScan
                                  : bleController.startScan,
                              icon: Icon(
                                isScanning ? Icons.stop : Icons.search,
                                color: Colors.black,
                              ),
                              label: Text(
                                isScanning ? 'stop_scan_button'.tr : 'scan_button'.tr,
                                style: const TextStyle(color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isScanning ? Colors.red.shade300 : neonColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (isConnected) const SizedBox(width: 10),
                          // ✅ تعريب زر قطع الاتصال
                          if (isConnected)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: bleController.disconnect,
                                icon: const Icon(Icons.close, color: Colors.black),
                                label: Text(
                                  'disconnect_button'.tr,
                                  style: const TextStyle(color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade300,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    // ✅ تعريب العنوان
                    ListTile(
                      title: Text(
                        'scan_results_title'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        // ✅ تعريب عدد النتائج
                        'device_count'.trParams({'count': bleController.scanResults.length.toString()}),
                        style: TextStyle(color: neonColor),
                      ),
                    ),
                    ...bleController.scanResults.map((r) =>
                        _buildScanResultTile(bleController, r)).toList(),
                    const Divider(height: 1, thickness: 1),
                    _buildMockDataSection(bleController),
                  ],
                ),
                // ✅ عرض شاشة المعالجة عند الحاجة
                if (_isAwaitingInput || bleController.isListening)
                  _buildChatOverlay(bleController),
              ],
            ),
          ),
        );
      },
    );
  }
}