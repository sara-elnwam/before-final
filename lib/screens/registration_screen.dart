// registration_screen.dart (الكود المعدل بالكامل)

import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // ❌ تم إزالة: تم استبدالها بـ GetX
import 'package:flutter/services.dart';
import 'package:get/get.dart'; // 💡 نستخدم GetX الآن
import '../models/user_profile.dart';
import '../services/ble_controller.dart';
import 'dart:async';
import 'allergies_detail_screen.dart';
// ✅ استخدام اسم مستعار (as detail) لحل مشكلة التضارب
import 'medications_detail_screen.dart' as detail;
import 'sign_up_screen.dart';
import 'main_chat_screen.dart';
import 'local_auth_screen.dart' show LocalAuthScreen, AuthNextRoute;
import 'language_selection_screen.dart' show LanguageSelectionScreen;

const Color accentColor = Color(0xFFFFB267);
const Color darkBackground = Color(0xFF1B1B1B);
const Color inputSurfaceColor = Color(0x992B2B2B);
const Color onBackground = Color(0xFFF8F8F8);
const Color darkSurface = Color(0xFF2C2C2C);

enum MedicalField {
  sex,
  bloodType,
  allergies,
  medications,
  diseases,
  complete,
}

class MedicalProfileScreen extends StatefulWidget {
  final String nextRoute;
  final UserProfile? initialProfile;

  const MedicalProfileScreen({
    super.key,
    required this.nextRoute,
    this.initialProfile,
  });

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  MedicalField _currentField = MedicalField.sex;

  String _selectedSex = '';
  String _selectedBloodType = '';
  String _selectedAllergies = 'None';
  String _selectedMedications = 'None';
  String _selectedDiseases = 'None';

  bool _isSexDropdownOpen = false;
  bool _isBloodTypeDropdownOpen = false;

  bool _isLoading = false;
  bool _isAwaitingInput = false;
  String _currentValueForConfirmation = '';

  // 💡 التعديل: لم يعد يعتمد على context في البناء، بل يتم البحث عنه مباشرة
  late BleController _bleController;

  int _tapCount = 0;
  Timer? _tapResetTimer;
  final Duration _tapTimeout = const Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    // 💡 التعديل الرئيسي: استخدام Get.find للوصول إلى الكنترولر
    _bleController = Get.find<BleController>(); //

    Future.delayed(Duration.zero, () {
      _loadCurrentProfile();
      _speakInstruction('instr_profile_setup_sex'.tr);
    });
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _bleController.stopListening(shouldSpeakStop: false);
    super.dispose();
  }

  void _loadCurrentProfile() {
    final profile = widget.initialProfile ?? _bleController.userProfile;
    if (profile != null) {
      if (mounted) {
        setState(() {
          _selectedSex = profile.sex == 'Not Set' ? '' : profile.sex;
          _selectedBloodType = profile.bloodType == 'Not Set' ? '' : profile.bloodType;
          _selectedAllergies = profile.allergies == 'None' ? 'None' : profile.allergies;
          _selectedMedications = profile.medications == 'None' ? 'None' : profile.medications;
          _selectedDiseases = profile.diseases == 'None' ? 'None' : profile.diseases;
        });
      }
    }
  }

  String _getFieldTitle(MedicalField field) {
    switch (field) {
      case MedicalField.sex: return 'sex_label'.tr;
      case MedicalField.bloodType: return 'blood_type_label'.tr;
      case MedicalField.allergies: return 'allergies_label'.tr;
      case MedicalField.medications: return 'medications_label'.tr;
      case MedicalField.diseases: return 'diseases_label'.tr;
      case MedicalField.complete: return 'done_button'.tr;
    }
  }

  void _speakInstruction(String instruction) {
    if (!mounted) return;
    _bleController.speak(instruction);
  }

  // =======================================================================
  // 🎙️ TTS/STT & Voice Command Logic (Long Press)
  // =======================================================================

  // 💡 التعديل: إزالة bleController من المعاملات لأنها أصبحت متاحة كـ _bleController في الـ State
  void _onLongPressStart() {
    if (_isLoading || _bleController.isListening || _currentField.index >= MedicalField.allergies.index) {
      if (_currentField.index >= MedicalField.allergies.index) {
        _speakInstruction('instr_voice_not_available'.tr);
      }
      return;
    }

    setState(() {
      _isSexDropdownOpen = false;
      _isBloodTypeDropdownOpen = false;
      _isAwaitingInput = true;
    });

    final fieldName = _getFieldTitle(_currentField);
    _speakInstruction('instr_recording_started'.trParams({'fieldName': fieldName}));

    _bleController.startListening( // 💡 استخدام _bleController مباشرة
      onResult: (spokenText) {
        if (mounted) {
          setState(() {
            _isAwaitingInput = false;
            _currentValueForConfirmation = spokenText.toLowerCase().trim();
          });
          if (_currentValueForConfirmation.isNotEmpty) {
            _processSpokenText(_currentValueForConfirmation);
          } else {
            _speakInstruction('instr_recognition_failed'.tr);
          }
        }
      },
    );
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_bleController.isListening) {
      _bleController.stopListening(shouldSpeakStop: false);
    }
  }

  // 🛠️ تم تعديل هذه الدالة لاستقبال القيمة المرجعة من نوع String
  void _processSpokenText(String command) async {
    _bleController.stop(); // إيقاف TTS الحالي

    // 1. معالجة أوامر التنقل العالمية أولاً باستخدام Gemini
    final normalizedCommand = command.toLowerCase();

    // ✅ التعديل: استقبال الرسالة النصية (String) بدلاً من القيمة المنطقية (bool).
    // الكنترولر (BleController) يتولى النطق برسالة التنقل.
    final String navigationMessage = await _bleController.handleNavigationCommand(normalizedCommand);

    // إذا لم تكن الرسالة هي رسالة الخطأ العامة لتحليل التنقل (navigation_parse_error)،
    // فهذا يعني أن الأمر تم التعامل معه بواسطة الكنترولر (تم التنقل أو تم النطق بخطأ تنقل محدد)،
    // لذا نتوقف عن المعالجة هنا.
    if (navigationMessage != 'navigation_parse_error'.tr) {
      return;
    }


    // 2. معالجة المدخلات الخاصة بالملف الطبي (الجنس وفصيلة الدم)
    if (_currentField == MedicalField.sex || _currentField == MedicalField.bloodType) {
      _handleFieldInput(command);
    }
    // 3. إذا لم يكن أمراً تنقل أو مدخل حقل، يتم إرساله إلى نموذج الدردشة/الاستفسار العام
    else {
      // إرسال الأمر للدردشة/الاستفسار العام
      _bleController.getGeminiResponse(command);
    }
  }

  void _handleFieldInput(String spokenText) {
    String message = 'instr_input_recorded'.tr;
    bool isHandled = false;
    String recordedValue = '';

    if (_currentField == MedicalField.sex) {
      final maleKey = 'option_male'.tr.toLowerCase();
      final femaleKey = 'option_female'.tr.toLowerCase();

      if (spokenText.contains(maleKey) || spokenText.contains('male'.toLowerCase())) {
        recordedValue = 'Male';
        isHandled = true;
      } else if (spokenText.contains(femaleKey) || spokenText.contains('female'.toLowerCase())) {
        recordedValue = 'Female';
        isHandled = true;
      } else {
        message = 'instr_sex_not_recognized'.tr;
      }
    } else if (_currentField == MedicalField.bloodType) {
      final validBloodTypes = ['a+', 'a-', 'b+', 'b-', 'ab+', 'ab-', 'o+', 'o-'];
      final cleanedText = spokenText
          .replaceAll(' ', '')
          .replaceAll('positive'.tr.toLowerCase(), '+')
          .replaceAll('negative'.tr.toLowerCase(), '-')
          .replaceAll('minus'.tr.toLowerCase(), '-')
          .replaceAll('plus'.tr.toLowerCase(), '+');

      String tempValue = '';
      for (var type in validBloodTypes) {
        if (cleanedText.contains(type.replaceAll(RegExp(r'[+-]'), '')) || cleanedText.contains(type.toLowerCase())) {
          tempValue = type;
          isHandled = true;
          break;
        }
      }

      if(isHandled) {
        recordedValue = tempValue.toUpperCase();
      } else {
        message = 'instr_blood_type_invalid'.tr;
      }
    }

    setState(() {
      _currentValueForConfirmation = isHandled ? recordedValue : '';
    });

    if (isHandled && _currentValueForConfirmation.isNotEmpty) {
      message = 'instr_recorded_confirm'.trParams({'value': _currentValueForConfirmation});
    }

    _speakInstruction(message);
  }

  // =======================================================================
  // ⚡ Actions & Navigation
  // =======================================================================

  void _handleScreenTap() {
    if (_isLoading) return;
    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(_tapTimeout, () => _processTapCount());
  }

  void _processTapCount() {
    final int count = _tapCount;
    _tapCount = 0;

    if (count == 2) {
      _handleDoubleTap();
    } else if (count == 3) {
      _handleTripleTap();
    }
  }

  void _handleDoubleTap() {
    if (_isAwaitingInput || _bleController.isListening) {
      _speakInstruction('instr_wait_for_voice'.tr);
      return;
    }

    if (_currentField == MedicalField.complete) {
      _saveProfile();
      return;
    }

    if (_currentField == MedicalField.sex) {
      if (_currentValueForConfirmation.isNotEmpty) {
        _applyAndMoveToNextField(_currentValueForConfirmation);
        _currentValueForConfirmation = '';
        return;
      }

      setState(() => _isSexDropdownOpen = !_isSexDropdownOpen);
      if (_isSexDropdownOpen) {
        _speakInstruction('instr_sex_dropdown_open'.tr);
      } else if (_selectedSex.isNotEmpty) {
        _applyAndMoveToNextField(_selectedSex);
      } else {
        _speakInstruction('instr_sex_dropdown_closed'.tr);
      }
      return;

    } else if (_currentField == MedicalField.bloodType) {
      if (_currentValueForConfirmation.isNotEmpty) {
        _applyAndMoveToNextField(_currentValueForConfirmation);
        _currentValueForConfirmation = '';
        return;
      }

      setState(() => _isBloodTypeDropdownOpen = !_isBloodTypeDropdownOpen);
      if (_isBloodTypeDropdownOpen) {
        _speakInstruction('instr_blood_type_dropdown_open'.tr);
      } else if (_selectedBloodType.isNotEmpty) {
        _applyAndMoveToNextField(_selectedBloodType);
      } else {
        _speakInstruction('instr_blood_type_dropdown_closed'.tr);
      }
      return;
    }

    if (_currentField.index >= MedicalField.allergies.index) {
      _navigateToDetailScreen(_currentField);
    } else {
      _speakInstruction('instr_input_data_or_next'.tr);
    }
  }

  void _handleTripleTap() {
    if (_isAwaitingInput || _bleController.isListening) return;

    if (_currentField == MedicalField.sex) {
      setState(() {
        _selectedSex = '';
        _currentValueForConfirmation = '';
        _isSexDropdownOpen = false;
      });
      _speakInstruction('instr_sex_field_cleared'.tr);
    } else if (_currentField == MedicalField.bloodType) {
      setState(() {
        _selectedBloodType = '';
        _currentValueForConfirmation = '';
        _isBloodTypeDropdownOpen = false;
      });
      _speakInstruction('instr_blood_type_field_cleared'.tr);
    } else {
      _speakInstruction('instr_triple_tap_not_allowed'.tr);
    }
  }

  void _applyAndMoveToNextField(String value) {
    MedicalField nextField = MedicalField.complete;
    String nextInstruction = 'instr_profile_complete_save'.tr;

    if (_currentField == MedicalField.sex) {
      _selectedSex = value;
      _isSexDropdownOpen = false;
      nextField = MedicalField.bloodType;
      // تحديث الرسالة لتعكس القيمة المعروضة للمستخدم وليس القيمة الإنجليزية المحفوظة
      final displaySex = _selectedSex == 'Male' ? 'option_male'.tr : 'option_female'.tr;
      nextInstruction = 'instr_sex_recorded_next_blood'.trParams({'value': displaySex});
    } else if (_currentField == MedicalField.bloodType) {
      _selectedBloodType = value;
      _isBloodTypeDropdownOpen = false;
      nextField = MedicalField.allergies;
      nextInstruction = 'instr_blood_recorded_next_allergies'.trParams({'value': _selectedBloodType});
    } else if (_currentField == MedicalField.allergies) {
      nextField = MedicalField.medications;
      nextInstruction = 'instr_allergies_saved_next_meds'.tr;
    } else if (_currentField == MedicalField.medications) {
      nextField = MedicalField.diseases;
      nextInstruction = 'instr_meds_saved_next_diseases'.tr;
    } else if ( _currentField == MedicalField.diseases) {
      nextField = MedicalField.complete;
      nextInstruction = 'instr_details_set_next_done'.tr;
    }

    setState(() {
      _currentField = nextField;
      _currentValueForConfirmation = '';
    });
    _speakInstruction(nextInstruction);
  }

  void _navigateToDetailScreen(MedicalField field) async {
    _speakInstruction('nav_to_detail_screen'.trParams({'field': _getFieldTitle(field)}));

    dynamic result;

    if (field == MedicalField.allergies) {
      // ✅ التعديل 1: تجهيز القائمة الأولية وتحويلها من سلسلة نصية
      final initialList = _selectedAllergies.toLowerCase() != 'none'
          ? _selectedAllergies.split(',').map((s) => s.trim()).toList()
          : <String>[];

      // ✅ التعديل 2: تمرير القائمة الأولية إلى الشاشة الجديدة (FIX: تم الآن إصلاح AllergiesDetailScreen لقبول هذا المعامل)
      result = await Get.to(() => AllergiesDetailScreen(initialList: initialList));

      // ✅ التعديل 3: التعامل مع القائمة العائدة
      if (mounted && result is List<String>) {
        setState(() {
          // تصفية القائمة للتأكد من عدم وجود 'None' إذا كان هناك عناصر حقيقية
          final filteredList = result.where((s) => s != 'None' && s.isNotEmpty).toList();

          // تحويل العناصر إلى سلسلة نصية
          final formattedString = filteredList.map((s) => s.capitalizeFirst!).join(', ');

          // تحديد القيمة النهائية
          _selectedAllergies = formattedString.isEmpty ? 'None' : formattedString;
        });
      }
    } else if (field == MedicalField.medications) {
      // ✅ FIX: استخدام الاسم الصحيح MedicationsDetailScreen
      result = await Get.to(() => detail.MedicationsDetailScreen(
        title: 'medications_label'.tr,
        currentValueString: _selectedMedications,
        profileField: 'medications',
      ));

      if (mounted && result is String) setState(() => _selectedMedications = result);
    } else if (field == MedicalField.diseases) {
      // ✅ FIX: استخدام الاسم الصحيح MedicationsDetailScreen
      result = await Get.to(() => detail.MedicationsDetailScreen(
        title: 'diseases_label'.tr,
        currentValueString: _selectedDiseases,
        profileField: 'diseases',
      ));

      if (mounted && result is String) setState(() => _selectedDiseases = result);
    }

    // الانتقال إلى الحقل التالي بعد العودة من شاشة التفاصيل
    _applyAndMoveToNextField('');
  }


  void _saveProfile() async {
    if (_selectedSex.isEmpty || _selectedBloodType.isEmpty) {
      _speakInstruction('instr_sex_blood_required'.tr);
      setState(() => _currentField = MedicalField.sex);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _speakInstruction('instr_saving_profile'.tr);

    final UserProfile? currentProfile = _bleController.userProfile;
    if (currentProfile != null) {
      final newProfile = currentProfile.copyWith(
        sex: _selectedSex,
        bloodType: _selectedBloodType,
        allergies: _selectedAllergies,
        medications: _selectedMedications,
        diseases: _selectedDiseases,
        isProfileComplete: true,
      );

      await _bleController.saveUserProfile(newProfile);
    }

    setState(() {
      _isLoading = false;
    });

    _speakInstruction('instr_profile_saved_auth_required'.tr);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // تم تغيير المسار هنا ليتناسب مع منطق LocalAuthScreen
        Get.offAll(() => const LocalAuthScreen(nextRoute: AuthNextRoute.mainScreen));
      }
    });
  }

  // =======================================================================
  // 🎨 UI Builders
  // =======================================================================

  Widget _buildSelectionBox({
    required String title,
    required String value,
    required MedicalField field,
    required bool isDropdownOpen,
    required List<String> options,
    required Function(String) onSelectOption,
  }) {
    final displayValue = value.isEmpty || value == 'Not Set' ? '' : value;
    final bool isSex = field == MedicalField.sex;

    final double dropdownHeight = isSex ? (options.length * 48.0) + 16.0 : (options.length * 48.0) + 16.0;

    const double boxRadius = 24.0;
    final Color valueColor = accentColor.withOpacity(0.9);
    final Color borderColor = accentColor.withOpacity(0.25);
    const double borderWidth = 1.0;

    final bool isActiveField = field == _currentField;
    const Color activeBorderColor = accentColor;
    const double activeBorderWidth = 2.0;

    const double verticalPadding = 14;


    return GestureDetector(
      onDoubleTap: () {
        setState(() => _currentField = field);
        _handleDoubleTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: inputSurfaceColor,
                borderRadius: BorderRadius.circular(boxRadius),
                border: Border.all(
                    color: isActiveField ? activeBorderColor : borderColor,
                    width: isActiveField ? activeBorderWidth : borderWidth),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        color: onBackground.withOpacity(0.8),
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Text(
                        // عرض القيمة المترجمة للجنس فقط
                        isSex && displayValue.isNotEmpty
                            ? (displayValue == 'Male' ? 'option_male'.tr : 'option_female'.tr)
                            : displayValue,
                        style: TextStyle(
                            color: value.isEmpty || value == 'Not Set' ? onBackground.withOpacity(0.4) : valueColor,
                            fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSex || field == MedicalField.bloodType
                            ? (isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                            : Icons.arrow_forward_ios,
                        color: valueColor,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isDropdownOpen)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: isDropdownOpen ? dropdownHeight : 0,
                margin: const EdgeInsets.only(top: 8.0),
                decoration: BoxDecoration(
                  color: inputSurfaceColor,
                  borderRadius: BorderRadius.circular(boxRadius),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: options.map((option) {
                      final isSelected = option == value;
                      final optionDisplay = (field == MedicalField.sex && option == 'Male')
                          ? 'option_male'.tr
                          : (field == MedicalField.sex && option == 'Female')
                          ? 'option_female'.tr
                          : option;

                      return InkWell(
                        onTap: () {
                          // إغلاق القائمة واختيار القيمة والانتقال للحقل التالي
                          onSelectOption(option);
                          _applyAndMoveToNextField(option);
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(boxRadius),
                          ),
                          child: Text(
                            optionDisplay,
                            style: TextStyle(
                              fontSize: 18,
                              color: isSelected ? accentColor : onBackground.withOpacity(0.9),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBox({
    required String title,
    required String value,
    required MedicalField field,
  }) {
    // عرض عدد العناصر المسجلة أو قيمة "تم التحديد"
    final displayValue = value == 'None'
        ? ''
        : (value.contains(',') ? '${value.split(',').length} ${'value_items_set'.tr}' : 'value_set'.tr);

    const double boxRadius = 24.0;
    final Color valueColor = accentColor.withOpacity(0.9);
    final Color borderColor = accentColor.withOpacity(0.25);
    const double borderWidth = 1.0;

    final bool isActiveField = field == _currentField;
    const Color activeBorderColor = accentColor;
    const double activeBorderWidth = 2.0;

    const double verticalPadding = 14;

    return InkWell(
      onTap: () => setState(() => _currentField = field),
      onDoubleTap: () {
        setState(() => _currentField = field);
        _handleDoubleTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: inputSurfaceColor,
          borderRadius: BorderRadius.circular(boxRadius),
          border: Border.all(
              color: isActiveField ? activeBorderColor : borderColor,
              width: isActiveField ? activeBorderWidth : borderWidth),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: onBackground.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Text(
                  displayValue,

                  style: TextStyle(
                      color: value == 'None' ? onBackground.withOpacity(0.4) : valueColor,
                      fontSize: 18),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: valueColor,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    // 🔴 تم توحيد ارتفاع الزر لـ 50.0 ونصف القطر لـ 10.0 ليتناسب مع شاشات التفاصيل
    const double buttonHeight = 50.0;
    const double buttonRadius = 10.0;

    final bool isActiveField = MedicalField.complete == _currentField;
    const Color activeColor = accentColor;
    const Color inactiveColor = Color(0xAAFFB267);

    return GestureDetector(
      onDoubleTap: _saveProfile,
      child: Container(
        height: buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isActiveField ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        alignment: Alignment.center,
        child: _isLoading
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<String> sexOptions = ['Male', 'Female'];
    const List<String> bloodTypeOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    // 💡 التعديل الرئيسي: استخدام GetBuilder بدلاً من Consumer
    return GetBuilder<BleController>(
      init: _bleController, // يُفضل تمرير الـ Controller الذي تم العثور عليه مسبقًا
      builder: (bleController) {
        // لا نحتاج لتعيين _bleController = bleController; هنا لأنه تم تعيينه بالفعل في initState

        return GestureDetector(
          onTap: _handleScreenTap,
          onLongPressStart: (_) => _onLongPressStart(), // 💡 إزالة معامل الكنترولر
          onLongPressEnd: _onLongPressEnd,
          child: Scaffold(
            backgroundColor: darkBackground,
            body: Stack(
              children: [
                // 1. الشريط العلوي الثابت ومحتوى التمرير
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. رأس الصفحة الثابت (Title/Back Button)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                color: onBackground,
                                onPressed: () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  } else {
                                    // إذا لم يكن هناك شاشة سابقة، نعود إلى شاشة التسجيل
                                    Get.offAll(() => const SignUpScreen());
                                  }
                                },
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'sign up'.tr,
                                    style: TextStyle(
                                      color: onBackground,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Center(
                            child: Text(
                              'medical profile'.tr,
                              style: TextStyle(
                                color: onBackground,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // B. محتوى القائمة القابل للتمرير
                    Expanded(
                      child: SingleChildScrollView(
                        // ترك مسافة للزر الثابت في الأسفل (50 ارتفاع الزر + 20 أسفل + 15 علوي = 85 تقريباً)
                        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 85.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // 1. Sex Selection
                            _buildSelectionBox(
                              title: _getFieldTitle(MedicalField.sex),
                              value: _selectedSex,
                              field: MedicalField.sex,
                              isDropdownOpen: _isSexDropdownOpen,
                              options: sexOptions,
                              onSelectOption: (sex) => setState(() => _selectedSex = sex),
                            ),

                            // 2. Blood Type Selection
                            _buildSelectionBox(
                              title: _getFieldTitle(MedicalField.bloodType),
                              value: _selectedBloodType,
                              field: MedicalField.bloodType,
                              isDropdownOpen: _isBloodTypeDropdownOpen,
                              options: bloodTypeOptions,
                              onSelectOption: (type) => setState(() => _selectedBloodType = type),
                            ),

                            // 3. Allergies Navigation
                            _buildNavigationBox(
                              title: _getFieldTitle(MedicalField.allergies),
                              value: _selectedAllergies,
                              field: MedicalField.allergies,
                            ),

                            // 4. Medications Navigation
                            _buildNavigationBox(
                              title: _getFieldTitle(MedicalField.medications),
                              value: _selectedMedications,
                              field: MedicalField.medications,
                            ),

                            // 5. Chronic Diseases Navigation
                            _buildNavigationBox(
                              title: _getFieldTitle(MedicalField.diseases),
                              value: _selectedDiseases,
                              field: MedicalField.diseases,
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. زر "تم" الثابت في الأسفل
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 20.0),
                    child: _buildDoneButton(),
                  ),
                ),

                // 3. Overlay for Loading/Listening/Processing
                if (_isAwaitingInput || bleController.isListening || _isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    constraints: const BoxConstraints.expand(),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: accentColor),
                          const SizedBox(height: 20),
                          Text(
                            _isLoading
                                ? 'saving_message'.tr
                                : bleController.isListening
                                ? 'listening_to_you'.tr
                                : 'processing_command'.tr,
                            style: const TextStyle(color: onBackground, fontSize: 18),
                          ),
                          if (bleController.lastWords.isNotEmpty && bleController.isListening)
                            const SizedBox(height: 10),
                          Text(
                            bleController.lastWords,
                            style: const TextStyle(color: onBackground, fontSize: 14),
                          ),
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