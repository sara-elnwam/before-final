// lib/screens/medications_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/ble_controller.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

// 💡 ألوان متناسقة مع تصميمك
const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF2C2C2C);
const Color darkBackground = Color(0xFF1B1B1B);
const Color onBackground = Color(0xFFF8F8F8);
const Color lightGreyText = Color(0xFFCCCCCC);
const Color inputSurfaceColor = Color(0x402B2B2B);

// ✅ التعديل: تغيير اسم الفصل إلى MedicationsDetailScreen وإضافة المعلمات المطلوبة
class MedicationsDetailScreen extends StatefulWidget {
  final String title;
  final String currentValueString;
  final String profileField; // medications or diseases

  const MedicationsDetailScreen({
    super.key,
    required this.title,
    required this.currentValueString,
    required this.profileField,
  });

  @override
  State<MedicationsDetailScreen> createState() => _MedicationsDetailScreenState();
}

class _MedicationsDetailScreenState extends State<MedicationsDetailScreen> {
  late BleController _bleController;
  final TextEditingController _textController = TextEditingController();
  final Set<String> _selectedItems = {};

  bool _isAwaitingInput = false;

  @override
  void initState() {
    super.initState();
    _bleController = Get.find<BleController>();

    // ✅ التعديل: تحليل السلسلة النصية الممررة (currentValueString) إلى قائمة عناصر
    if (widget.currentValueString.toLowerCase() != 'none' && widget.currentValueString.isNotEmpty) {
      _selectedItems.addAll(widget.currentValueString.split(',').map((s) => s.trim()));
    }

    Future.delayed(Duration.zero, () {
      _speakInstruction('instr_detail_screen_prompt'.trParams({'field': widget.title}));
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _bleController.stopListening(shouldSpeakStop: false);
    super.dispose();
  }

  void _speakInstruction(String instruction) {
    if (!mounted) return;
    _bleController.speak(instruction);
  }

  // =======================================================================
  // 🎙️ TTS/STT Logic & Interaction
  // =======================================================================

  void _onLongPressStart() {
    if (_bleController.isListening) return;

    setState(() => _isAwaitingInput = true);
    _speakInstruction('instr_speaking_start'.tr);

    _bleController.startListening(
      onResult: (spokenText) {
        if (mounted) {
          setState(() => _isAwaitingInput = false);
          _handleVoiceInput(spokenText.trim());
        }
      },
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_bleController.isListening) {
      _bleController.stopListening(shouldSpeakStop: false);
    }
  }

  void _handleVoiceInput(String text) {
    final normalizedText = text.toLowerCase().trim();
    String message = 'instr_recognition_failed'.tr;

    if (normalizedText.isEmpty) {
      message = 'instr_please_speak'.tr;
    } else if (normalizedText.contains('done') || normalizedText.contains('finish') || normalizedText.contains('انهاء'.tr)) {
      _saveAndExit();
      return;
    } else {
      _addItem(text);
      message = 'instr_item_added'.trParams({'item': text});
    }

    setState(() {});
    _speakInstruction(message);
  }

  void _addItem(String item) {
    final trimmedItem = item.trim();
    if (trimmedItem.isNotEmpty && !_selectedItems.contains(trimmedItem.capitalizeFirst!)) {
      setState(() {
        _selectedItems.add(trimmedItem.capitalizeFirst!);
      });
      _textController.clear();
      _speakInstruction('instr_item_added_confirm'.trParams({'item': trimmedItem.capitalizeFirst!}));
    } else if (_selectedItems.contains(trimmedItem.capitalizeFirst!)) {
      _speakInstruction('instr_item_already_added'.trParams({'item': trimmedItem.capitalizeFirst!}));
    }
  }

  void _removeItem(String item) {
    setState(() {
      _selectedItems.remove(item);
    });
    _speakInstruction('instr_item_removed'.trParams({'item': item}));
  }

  void _saveAndExit() async {
    setState(() {
      _isAwaitingInput = true;
    });

    final List<String> finalItems = _selectedItems.toList();
    final String resultString = finalItems.isEmpty ? 'None' : finalItems.join(', ');

    // 💡 تحديث ملف التعريف في الكنترولر
    final UserProfile? currentProfile = _bleController.userProfile;
    if (currentProfile != null) {
      UserProfile newProfile;
      if (widget.profileField == 'medications') {
        newProfile = currentProfile.copyWith(medications: resultString);
      } else if (widget.profileField == 'diseases') {
        newProfile = currentProfile.copyWith(diseases: resultString);
      } else {
        newProfile = currentProfile;
      }
      await _bleController.saveUserProfile(newProfile);
    }

    setState(() {
      _isAwaitingInput = false;
    });

    // ✅ إرجاع السلسلة النصية الناتجة (String)
    Get.back(result: resultString);
  }

  // =======================================================================
  // 🎨 UI Builders
  // =======================================================================

  Widget _buildItemInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: TextField(
        controller: _textController,
        style: const TextStyle(color: onBackground),
        decoration: InputDecoration(
          hintText: 'add_item_hint'.trParams({'field': widget.title.toLowerCase()}),
          hintStyle: TextStyle(color: onBackground.withOpacity(0.5)),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.add, color: neonColor),
            onPressed: () {
              if (_textController.text.isNotEmpty) {
                _addItem(_textController.text);
              }
            },
          ),
        ),
        onSubmitted: _addItem,
      ),
    );
  }

  Widget _buildItemList() {
    final list = _selectedItems.toList();
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text(
            'no_items_added'.trParams({'field': widget.title.toLowerCase()}),
            style: TextStyle(color: onBackground.withOpacity(0.6), fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: list.map((item) {
        return Chip(
          label: Text(
            item,
            style: const TextStyle(
              color: darkBackground,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          backgroundColor: neonColor,
          deleteIcon: const Icon(Icons.close, color: darkBackground, size: 18),
          onDeleted: () => _removeItem(item),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: neonColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        );
      }).toList(),
    ).paddingSymmetric(horizontal: 20.0);
  }


  @override
  Widget build(BuildContext context) {
    // ✅ استخدام GetBuilder
    return GetBuilder<BleController>(
      builder: (bleController) {
        final isListening = bleController.isListening;
        return GestureDetector(
          onLongPressStart: (_) => _onLongPressStart(),
          onLongPressEnd: _onLongPressEnd,
          onDoubleTap: _saveAndExit,
          child: Scaffold(
            backgroundColor: darkBackground,
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios),
                                  color: onBackground,
                                  onPressed: () => Get.back(result: widget.currentValueString),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          'medical_profile_title'.tr,
                                          style: TextStyle(
                                            color: onBackground,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        // 💡 استخدام عنوان الشاشة الممرر
                                        Text(
                                          widget.title,
                                          style: const TextStyle(
                                            color: lightGreyText,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 1. حقل الإدخال
                      _buildItemInput().paddingSymmetric(horizontal: 20.0, vertical: 10.0),

                      // 2. قائمة العناصر المضافة
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                          child: _buildItemList(),
                        ),
                      ),

                      // 3. زر "تم"
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 30.0),
                        child: InkWell(
                          onTap: _saveAndExit,
                          child: Container(
                            height: 60,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: neonColor,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: _isAwaitingInput
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: darkBackground, strokeWidth: 2),
                            )
                                : Text(
                              'done_button'.tr,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: darkBackground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Overlay
                  if (_isAwaitingInput || isListening)
                    Container(
                      color: Colors.black.withOpacity(0.8),
                      constraints: const BoxConstraints.expand(),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: neonColor),
                            const SizedBox(height: 20),
                            Text(
                              _isAwaitingInput
                                  ? 'saving_message'.tr
                                  : isListening
                                  ? 'listening_to_you'.tr
                                  : 'processing_command'.tr,
                              style: const TextStyle(color: onBackground, fontSize: 18),
                            ),
                            if (isListening && bleController.lastWords.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                bleController.lastWords,
                                style: const TextStyle(color: onBackground, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}