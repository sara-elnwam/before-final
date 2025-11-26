// lib/screens/allergies_detail_screen.dart

import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // ❌ تم إزالة: استبدال بـ GetX
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

// ✅ هيكل الحساسيات باستخدام مفاتيح تعريب
const Map<String, List<String>> structuredAllergies = {
  'food_allergens': [
    'Peanut', 'Milk / Dairy', 'Egg',
    'Soybean', 'Wheat / Gluten', 'Other Food',
    'Shellfish', 'Fish',
  ],
  'animal_allergens': [
    'Cat Dander', 'Dog Dander',
    'Rodent', 'Other Pet',
  ],
  'medication_allergens': [
    'Antibiotics', 'Anesthetics',
    'Insect Sting Venom', 'NSAIDs',
    'Other Medication',
  ],
  'environmental_allergens': [
    'Pollen', 'Dust Mites', 'Mold',
    'Cockroach', 'Smoke / Fumes', 'Other Env',
  ],
};


class AllergiesDetailScreen extends StatefulWidget {
  // ✅ FIX: إضافة المعامل المطلوب (initialList)
  final List<String> initialList;
  const AllergiesDetailScreen({super.key, required this.initialList});

  @override
  State<AllergiesDetailScreen> createState() => _AllergiesDetailScreenState();
}

class _AllergiesDetailScreenState extends State<AllergiesDetailScreen> {
  // 💡 إضافة BleController كـ late field
  late BleController _bleController;

  bool _isAwaitingInput = false;
  // 💡 نستخدم Set داخلياً لضمان عدم التكرار
  final Set<String> _selectedAllergies = {};

  @override
  void initState() {
    super.initState();
    // ✅ FIX: استبدال Provider.of بـ Get.find
    _bleController = Get.find<BleController>();

    // ✅ استخدام القائمة الأولية الممررة بدلاً من التحميل من ملف التعريف
    if (widget.initialList.isNotEmpty) {
      final currentAllergies = widget.initialList.where((s) => s.toLowerCase() != 'none').map((s) => s.toLowerCase().trim());
      _selectedAllergies.addAll(currentAllergies);
    }
  }

  Widget _buildAllergyTile(String allergyKey, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: inputSurfaceColor,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: neonColor.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Row(
              children: [
                Text(
                  allergyKey.tr,
                  style: const TextStyle(
                    color: onBackground,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: items.map((item) {
              final isSelected = _selectedAllergies.contains(item.toLowerCase());
              return GestureDetector(
                onTap: () {
                  setState(() {
                    final normalizedItem = item.toLowerCase();
                    if (isSelected) {
                      _selectedAllergies.remove(normalizedItem);
                    } else {
                      _selectedAllergies.add(normalizedItem);
                    }
                  });
                },
                child: Chip(
                  label: Text(
                    item.tr,
                    style: TextStyle(
                      color: isSelected ? darkBackground : onBackground,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  backgroundColor: isSelected ? neonColor : darkSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                    side: BorderSide(
                      color: isSelected ? neonColor : darkSurface,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              );
            }).toList(),
          ).paddingOnly(left: 20.0, right: 20.0, bottom: 20.0),
        ],
      ),
    );
  }

  // ✅ FIX: إزالة معامل bleController من الدالة
  void _saveAndNavigate() async {
    setState(() {
      _isAwaitingInput = true;
    });

    final String allergiesString = _selectedAllergies.isEmpty
        ? 'None'
        : _selectedAllergies.map((s) => s.capitalizeFirst!).join(', ');

    // 💡 استخدام _bleController مباشرة
    final UserProfile? currentProfile = _bleController.userProfile;
    if (currentProfile != null) {
      final newProfile = currentProfile.copyWith(
        allergies: allergiesString,
      );
      await _bleController.saveUserProfile(newProfile);
    }

    setState(() {
      _isAwaitingInput = false;
    });

    // ✅ إرجاع القائمة (List<String>) لتطابق ما يتوقعه registration_screen
    final List<String> finalItems = _selectedAllergies.toList();
    final List<String> resultList = finalItems.isEmpty ? ['None'] : finalItems;
    Get.back(result: resultList);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: استبدال Consumer بـ GetBuilder
    return GetBuilder<BleController>(
      builder: (bleController) {
        final isListening = bleController.isListening;

        return Scaffold(
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
                                // ✅ FIX: إرجاع القائمة عند العودة (لأن registration_screen يتوقع قائمة)
                                onPressed: () => Get.back(result: _selectedAllergies.isEmpty ? ['None'] : _selectedAllergies.toList()),
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
                                      Text(
                                        'allergies_label'.tr,
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
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        children: structuredAllergies.entries.map((entry) {
                          return _buildAllergyTile(entry.key, entry.value);
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 30.0),
                      child: InkWell(
                        onTap: _saveAndNavigate, // ✅ FIX: إزالة bleController من الاستدعاء
                        child: Container(
                          height: 60,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: neonColor,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
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
        );
      },
    );
  }
}