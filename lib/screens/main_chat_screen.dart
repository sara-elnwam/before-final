// lib/screens/main_chat_screen.dart

import 'package:flutter/material.dart';
import '../services/ble_controller.dart';
import 'dart:async';
import 'settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ble_scan_screen.dart';
import 'glasses_screen.dart';
import 'bracelet_screen.dart';
import 'cane_screen.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'user_profile_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'earpods_screen.dart';
import 'package:get/get.dart';
import '../widgets/common_bottom_nav_bar.dart';

const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF1C1C1C);
const Color darkBackground = Color(0xFF000000);
const Color onBackground = Colors.white;

class MainChatScreen extends StatefulWidget {
  const MainChatScreen({super.key});

  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {

  late BleController _bleController;

  String _geminiResponse = '';
  String _lastSpokenPrompt = '';
  bool _isAwaitingInput = false;

  // ✅ نصوص التعريب الأساسية (Localization)
  static const Map<String, String> _arTexts = {
    // نصوص الواجهة (UI Texts)
    'home_title': 'الرئيسية',
    'devices_count': 'أجهزة',
    'add_device_button': 'إضافة جهاز',
    'status_listening': 'جارٍ الاستماع إليك... ارفع إصبعك لإيقاف التسجيل',
    'status_processing': 'جارٍ معالجة الأمر...',

    // نصوص الأوامر الصوتية والنطق (TTS/STT Prompts)
    'welcome_message': 'مرحباً بك في الشاشة الرئيسية. اضغط مطولاً للتحدث بإحدى الأوامر.',
    'recording_started': 'بدء التسجيل. تحدث الآن.',
    'no_speech_recognized': 'لم يتم التعرف على كلامك. اضغط مطولاً وحاول مرة أخرى.',
    'recording_stopped': 'توقف التسجيل. جارٍ معالجة الأمر.',
    'error_processing': 'حدث خطأ أثناء معالجة أمرك.',
    'speak_prompt': 'اضغط مطولاً على الشاشة لإصدار أمر صوتي.',
    'last_response': 'كان الرد الأخير هو: ',

    // نصوص أوامر التنقل (Navigation Commands)
    'nav_home': 'أنت بالفعل على الشاشة الرئيسية.',
    'nav_devices_view': 'عرض الأجهزة.',
    'nav_profile': 'شاشة ملف المستخدم.',
    'nav_settings': 'انتقال إلى شاشة الإعدادات.',
    'navigating_to': 'انتقال إلى شاشة ',
    'screen_unavailable': 'شاشة ',
    'screen_unavailable_yet': ' ليست متاحة بعد.',

    // مفاتيح تعريب نصوص الأجهزة في البوكسات (Device Localization Keys)
    'glasses_name': 'نظارات',
    'glasses_subtitle': 'نظارات ذكية',
    'cane_name': 'عصا',
    'cane_subtitle': 'عصا ذكية',
    'bracelet_name': 'سوار',
    'bracelet_subtitle': 'سوار المساعدة',
    'earbuds_name': 'سماعات',
    'earbuds_subtitle': 'لوموس سمعيات',
  };

  // 🐛 التصحيح: تم تخزين **دالة بانية** (WidgetBuilder) بدلاً من الـ Widget Instance
  final List<Map<String, dynamic>> _devices = [
    {
      'name_key': 'glasses_name',
      'subtitle_key': 'glasses_subtitle',
      'icon': MdiIcons.glasses,
      'screen_builder': () => GlassesScreen(), // ✅ تخزين دالة
    },
    {
      'name_key': 'cane_name',
      'subtitle_key': 'cane_subtitle',
      'icon': MdiIcons.slashForward,
      'screen_builder': () => const CaneScreen(), // ✅ تخزين دالة
    },
    {
      'name_key': 'bracelet_name',
      'subtitle_key': 'bracelet_subtitle',
      'icon': MdiIcons.watch,
      'screen_builder': () => BraceletScreen(), // ✅ تخزين دالة
    },
    {
      'name_key': 'earbuds_name',
      'subtitle_key': 'earbuds_subtitle',
      'icon': FluentIcons.surface_earbuds_20_regular,
      'screen_builder': () => const EarpodsScreen(), // ✅ تخزين دالة
    },
  ];

  @override
  void initState() {
    super.initState();

    _bleController = Get.find<BleController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bleController.speak(_arTexts['welcome_message']!);
    });
  }

  // ----------------------------------------------------------------------
  // 🎙️ STT & Voice Command Logic
  // ----------------------------------------------------------------------

  void _onLongPressStart() {
    // 🐛 التصحيح: إزالة .value
    if (_isAwaitingInput || _bleController.isListening) return;

    setState(() {
      _isAwaitingInput = true;
    });

    _bleController.speak(_arTexts['recording_started']!);

    _bleController.startListening(
      onResult: (spokenText) async {
        if (mounted) {
          setState(() {
            _lastSpokenPrompt = spokenText;
          });
          if (spokenText.isNotEmpty) {
            _processVoiceCommand(spokenText);
          } else {
            _bleController.speak(_arTexts['no_speech_recognized']!);
            if (mounted) setState(() {
              _isAwaitingInput = false;
            });
          }
        }
      },
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    // 🐛 التصحيح: إزالة .value
    if (_bleController.isListening) {
      _bleController.stopListening(shouldSpeakStop: false);
      _bleController.speak(_arTexts['recording_stopped']!);
    }
  }

  Future<void> _processVoiceCommand(String query) async {
    await Future.delayed(const Duration(seconds: 1));
    _bleController.stop();

    try {
      final normalizedQuery = query.toLowerCase();

      final String navigationMessage = await _bleController.handleNavigationCommand(normalizedQuery);

      if (navigationMessage != 'navigation_parse_error'.tr) {
        if (mounted) setState(() {
          _isAwaitingInput = false;
        });
        return;
      }

      String response = await _bleController.processVoiceCommand(query);

      if (mounted) {
        setState(() {
          _geminiResponse = response;
        });
      }

      await _bleController.speak(response);

    } catch (e) {
      if (mounted) {
        setState(() {
          _geminiResponse = 'Error processing command: ${e.toString()}';
        });
      }
      _bleController.speak(_arTexts['error_processing']!);
    }

    if (mounted) setState(() {
      _isAwaitingInput = false;
    });
  }

  // ----------------------------------------------------------------------
  // ⚙️ Navigation Logic (وظيفة التنقل المصححة)
  // ----------------------------------------------------------------------

  void _navigateToDevice(Map<String, dynamic> device) {
    final deviceNameKey = device['name_key'] as String;
    final deviceNameLocalized = _arTexts[deviceNameKey] ?? 'الجهاز';

    // 🐛 التصحيح: استخدام 'screen_builder' وتمريره مباشرة لـ Get.to()
    final Widget Function()? screenBuilder = device['screen_builder'];

    if (screenBuilder != null) {
      _bleController.speak('${_arTexts['navigating_to']!}$deviceNameLocalized');
      // ✅ أصبح screenBuilder دالة بانية (Widget Function) يتم تمريرها مباشرة
      Get.to(screenBuilder);
    } else {
      _bleController.speak('${_arTexts['screen_unavailable']!}$deviceNameLocalized ${_arTexts['screen_unavailable_yet']!}');
    }
  }

  void _goToSettings() {
    _bleController.speak(_arTexts['nav_settings']!);
    Get.to(() => const SettingsScreen());
  }

  void _goToProfile() {
    _bleController.speak(_arTexts['nav_profile']!);
    Get.to(() => const UserProfileScreen());
  }

  // ----------------------------------------------------------------------
  // 🎨 UI Helpers (Device Card)
  // ----------------------------------------------------------------------

  Widget _buildDeviceCard(BuildContext context, Map<String, dynamic> device) {
    final nameKey = device['name_key'] as String;
    final subtitleKey = device['subtitle_key'] as String;
    final iconData = device['icon'] as IconData;

    final name = _arTexts[nameKey] ?? 'خطأ: اسم الجهاز مفقود';
    final subtitle = _arTexts[subtitleKey] ?? 'خطأ: وصف الجهاز مفقود';

    final originalKeySegment = nameKey.split('_').first;

    Widget iconWidget = Icon(
      iconData,
      size: 35,
      color: neonColor,
      shadows: const [
        Shadow(blurRadius: 15.0, color: neonColor),
      ],
    );

    if (originalKeySegment == 'bracelet') {
      iconWidget = Transform.rotate(
        angle: 90 * pi / 180,
        child: iconWidget,
      );
    }

    if (originalKeySegment == 'earbuds') {
      iconWidget = Transform.rotate(
        angle: 15 * pi / 180,
        child: iconWidget,
      );
    }

    if (originalKeySegment == 'cane' && iconData == MdiIcons.slashForward) {
      iconWidget = Icon(
        iconData,
        size: 60,
        color: neonColor,
        shadows: const [
          Shadow(blurRadius: 15.0, color: neonColor),
        ],
      );
    }


    return GestureDetector(
      onTap: () => _navigateToDevice(device),
      child: Card(
        color: darkSurface.withOpacity(0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconWidget,
                  const SizedBox(height: 5),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: onBackground,
                    ),
                  ),
                ],
              ),

              Center(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: onBackground.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🎨 Main Build
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onLongPressStart: (_) => _onLongPressStart(),
      onLongPressEnd: _onLongPressEnd,
      onTap: () {
        if (_geminiResponse.isNotEmpty) {
          _bleController.speak('${_arTexts['last_response']!}$_geminiResponse');
        } else {
          _bleController.speak(_arTexts['speak_prompt']!);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: darkBackground,
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
            opacity: 1.0,
            alignment: Alignment(0.1, -0.2),
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,

          bottomNavigationBar: const CommonBottomNavBar(currentIndex: 0),

          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        const SizedBox(height: 100),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            _arTexts['home_title']!,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            '${_devices.length} ${_arTexts['devices_count']!}',
                            style: TextStyle(
                              fontSize: 16,
                              color: onBackground.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildListDelegate(
                        _devices.map((device) {
                          return _buildDeviceCard(context, device);
                        }).toList(),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                ],
              ),

              // شاشة التحميل/الاستماع العائمة (Gemini/STT status)
              // 🐛 التصحيح: استبدال Obx بـ GetBuilder ليتوافق مع المتغيرات غير التفاعلية
              GetBuilder<BleController>(
                init: _bleController,
                builder: (controller) {
                  final isListening = controller.isListening;
                  if (_isAwaitingInput || isListening) {
                    return Container(
                      color: Colors.black.withOpacity(0.8),
                      constraints: const BoxConstraints.expand(),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: neonColor),
                            const SizedBox(height: 20),
                            Text(
                              isListening
                                  ? _arTexts['status_listening']!
                                  : _arTexts['status_processing']!,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}