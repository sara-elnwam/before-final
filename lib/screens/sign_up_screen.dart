// sign_up_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:ui'; // لتأثير التغبيش (BackdropFilter)

import '../services/ble_controller.dart';
import '../models/user_profile.dart';
import 'registration_screen.dart'; // Contains MedicalProfileScreen
import 'local_auth_screen.dart'; // Biometric authentication screen

// مسارات ملفات الصور (تم إضافة مسارات أيقونات التواصل الاجتماعي)
const String kHeaderImagePath = 'assets/images/create_account.png';
const String kBackgroundImagePath = 'assets/images/signup.png';
const String kGoogleIconPath = 'assets/images/google.png';
const String kAppleIconPath = 'assets/images/apple.png';

// 🎨 ثوابت التصميم المطابقة لـ Figma
const Color primaryAccentColor = Color(0xFFCA8428);
const Color primaryDarkBackground = Color(0xFF1B1B1B);
const Color whiteOverlayColor = Color(0x33FFFFFF); // لون البوكس: أبيض شفاف (20% opacity)
const Color socialIconColor = Color(0xFFD5D5D5); // اللون الأساسي للرموز/الروابط
const Color signInLinkColor = Color(0xFFCA8428);
const Color alreadyHaveAccountColor = Color(0xFFD5D5D5);
const Color inputFieldFillColor = Colors.white;
const Color orDividerColor = Color(0xFFD5D5D5);

// لون نص "Or with" الجديد
const Color orTextColor = Color(0xD9D9D9CC); // #D9D9D9CC

// =======================================================================
// شاشة التسجيل
// =======================================================================

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController = TextEditingController(); // حقل جديد لتكرار كلمة المرور

  // تم استخدام late لتخزين المتحكم
  late BleController _bleController;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  // حالة جديدة لرؤية حقل "Repeat password"
  bool _isRepeatPasswordVisible = false;
  bool _isAwaitingInput = false;
  bool _isProcessingCommand = false;
  int _tapCount = 0;
  Timer? _tapResetTimer;
  final Duration _tapTimeout = const Duration(milliseconds: 600);

  String _currentField = 'fullName';

  @override
  void initState() {
    super.initState();
    // FIX: استخدام Get.find() بدلاً من Provider.of()
    _bleController = Get.find<BleController>();
    Future.delayed(Duration.zero, () {
      _speakInstruction('Welcome. Say your full name, or double-tap to enter manually.'.tr);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose(); // التخلص من المتحكم الجديد
    _tapResetTimer?.cancel();
    _bleController.stopListening(shouldSpeakStop: false);
    super.dispose();
  }

  void _speakInstruction(String instruction) {
    if (!mounted) return;
    _bleController.speak(instruction);
  }

  void _focusNextField(String currentField) {
    setState(() {
      if (currentField == 'fullName') {
        _currentField = 'email';
        _speakInstruction('Enter your email.'.tr);
      } else if (currentField == 'email') {
        _currentField = 'password';
        _speakInstruction('Enter your password.'.tr);
      } else if (currentField == 'password') {
        _currentField = 'repeatPassword'; // تم التعديل على اسم الحقل الجديد
        _speakInstruction('Enter your Repeat password.'.tr);
      } else if (currentField == 'repeatPassword') { // تم التعديل على اسم الحقل الجديد
        _currentField = 'signUp';
        _speakInstruction('Double-tap to sign up.'.tr);
      } else {
        _currentField = 'fullName';
      }
    });
  }

  // =======================================================================
  // 🎙️ TTS/STT Logic
  // =======================================================================

  void _onLongPressStart(BleController bleController) {
    if (_isLoading || bleController.isListening) return;

    setState(() => _isAwaitingInput = true);
    _speakInstruction('Start speaking now.'.tr);

    bleController.startListening(
      onResult: (spokenText) {
        if (mounted) {
          setState(() {
            _isAwaitingInput = false;
            _isProcessingCommand = true;
          });
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

  void _handleVoiceInput(String text) async {
    setState(() => _isProcessingCommand = false);

    final normalizedText = text.toLowerCase();

    // Commands to navigate between fields
    if (normalizedText.contains('next') || normalizedText.contains('go to next')) {
      _focusNextField(_currentField);
      return;
    } else if (normalizedText.contains('back') || normalizedText.contains('go back')) {
      _speakInstruction('Command not supported yet.'.tr);
      return;
    }

    // Command to sign up
    if (_currentField == 'signUp' && (normalizedText.contains('sign up') || normalizedText.contains('register'))) {
      _signUp(context);
      return;
    }

    // Input data for the current field
    if (normalizedText.isNotEmpty) {
      String successMessage = 'Input saved.'.tr;

      if (_currentField == 'fullName') {
        _fullNameController.text = text;
        successMessage = 'Full name recorded: $text. Double-tap to confirm and move to email.'.tr;
      } else if (_currentField == 'email') {
        _emailController.text = text;
        successMessage = 'Email recorded: $text. Double-tap to confirm and move to password.'.tr;
      } else if (_currentField == 'password') {
        _passwordController.text = text;
        successMessage = 'Password recorded.'.tr; // Don't speak the password
      } else if (_currentField == 'repeatPassword') { // تم التعديل على اسم الحقل الجديد
        _repeatPasswordController.text = text;
        successMessage = 'Repeat password recorded. Double-tap to sign up.'.tr;
      }

      _speakInstruction(successMessage);
    } else {
      _speakInstruction('Could not recognize input. Try again.'.tr);
    }
  }

  // =======================================================================
  // 👆 Tap/Navigation Logic
  // =======================================================================

  void _handleScreenTap() {
    if (_isLoading || _isAwaitingInput || _isProcessingCommand) return;
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
    if (_currentField == 'signUp') {
      _signUp(context);
    } else {
      // If data is present, move to the next field (confirmation)
      if (_isFieldFilled(_currentField)) {
        _focusNextField(_currentField);
      } else {
        // If the field is empty, enter manual mode/speak instruction
        _speakInstruction('Please fill the current field manually or use long-press for voice input.'.tr);
      }
    }
  }

  void _handleTripleTap() {
    // Toggle password visibility (useful for triple tap)
    if (_currentField == 'password') {
      setState(() {
        _isPasswordVisible = !_isPasswordVisible;
      });
      _speakInstruction(_isPasswordVisible ? 'Password visible.'.tr : 'Password hidden.'.tr);
    }
    // إضافة تبديل رؤية حقل "Repeat password"
    else if (_currentField == 'repeatPassword') { // تم التعديل على اسم الحقل الجديد
      setState(() {
        _isRepeatPasswordVisible = !_isRepeatPasswordVisible;
      });
      _speakInstruction(_isRepeatPasswordVisible ? 'Repeat password visible.'.tr : 'Repeat password hidden.'.tr);
    }
    else {
      _speakInstruction('Triple-tap action is only for password visibility.'.tr);
    }
  }

  bool _isFieldFilled(String field) {
    if (field == 'fullName') return _fullNameController.text.isNotEmpty;
    if (field == 'email') return _emailController.text.isNotEmpty;
    if (field == 'password') return _passwordController.text.isNotEmpty;
    if (field == 'repeatPassword') return _repeatPasswordController.text.isNotEmpty; // تم التعديل على المتحكم الجديد
    return false;
  }

  // =======================================================================
  // 🚀 Core Functionality
  // =======================================================================

  void _signUp(BuildContext context) async {
    // التحقق من تطابق كلمتي المرور قبل إرسال النموذج
    if (_passwordController.text != _repeatPasswordController.text) {
      _speakInstruction('Passwords do not match. Please re-enter them.'.tr); // يجب إضافة مفتاح تعريب 'passwords_do_not_match'
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _speakInstruction('Please correct the validation errors first.'.tr);
      return;
    }

    setState(() => _isLoading = true);

    // ملاحظة: رقم هاتف الطوارئ ما زال يأخذ قيمة حقل تكرار كلمة المرور. يجب تحديث منطق التطبيق لاحقاً.
    final newProfile = UserProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      emergencyPhoneNumber: _repeatPasswordController.text, // تم استخدام حقل Repeat password كرقم طوارئ مؤقتًا
      // Default medical fields
      sex: 'Not Set',
      bloodType: 'Not Set',
      allergies: 'None',
      medications: 'None',
      diseases: 'None',
    );

    // 1. Save the new profile (saves to shared_preferences)
    await _bleController.saveUserProfile(newProfile);

    // 2. Navigate to medical profile setup
    _navigateToMedicalProfile();

    // We navigate away, so no need to set isLoading to false here
  }

  void _navigateToMedicalProfile() {
    _speakInstruction('Registration successful. Setting up medical profile next.'.tr);

    Get.off(() => const MedicalProfileScreen(
      nextRoute: '/main', // The final destination after the medical profile is completed
    ));
  }

  void _navigateToSignIn() {
    _speakInstruction('Navigating to sign in screen.'.tr);
    Get.offAll(() => const LocalAuthScreen(nextRoute: AuthNextRoute.mainScreen));
  }

  // =======================================================================
  // 🎨 UI Builders
  // =======================================================================

  Widget _buildSocialButton(String iconPath) {
    return InkWell(
      onTap: () {
        _speakInstruction('Social login not implemented yet.'.tr);
      },
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: inputFieldFillColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: orDividerColor.withOpacity(0.5)),
        ),
        child: Image.asset(iconPath),
      ),
    );
  }

  Widget _buildSocialButtonsRow() {
    // تم تقليل التباعد الرأسي إلى 5.0
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSocialButton(kGoogleIconPath),
          const SizedBox(width: 16),
          _buildSocialButton(kAppleIconPath),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    // تم تقليل الـ padding الرأسي إلى 2.0
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 98,
            height: 1,
            color: Colors.black,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              'Or with'.tr,
              style: const TextStyle(
                color: orTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Container(
            width: 98,
            height: 1,
            color: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildSignInLink() {
    return InkWell(
      onTap: _navigateToSignIn,
      child: Padding(
        // تم تقليل الـ padding العلوي إلى 2.0
        padding: const EdgeInsets.only(top: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? '.tr,
              style: const TextStyle(
                color: alreadyHaveAccountColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              ' sign in here'.tr,
              style: const TextStyle(
                color: signInLinkColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintTextKey,
    required TextInputType keyboardType,
    required String fieldName,
    bool isPassword = false,
    bool isVisible = true,
    // لتمرير دالة التبديل لحقل تكرار كلمة المرور
    VoidCallback? onVisibilityToggle,
  }) {
    // Highlight based on current focus
    final bool isFocused = _currentField == fieldName;

    return Padding(
      // تم تقليل التباعد بين الحقول إلى 2.0
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        // التعديل على الإخفاء: يستخدم isPassword لتحديد ما إذا كان حقل كلمة مرور، ثم يستخدم isVisible لتحديد الرؤية الحالية
        obscureText: isPassword && !isVisible,
        style: const TextStyle(color: primaryDarkBackground),
        decoration: InputDecoration(
          hintText: hintTextKey.tr,
          hintStyle: TextStyle(color: primaryDarkBackground.withOpacity(0.5)),
          fillColor: inputFieldFillColor,
          filled: true,
          // التعديل الرئيسي لحل مشكلة الـ Overflow: تقليل الـ contentPadding الرأسي
          contentPadding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(
              color: isFocused ? primaryAccentColor : Colors.transparent,
              width: isFocused ? 2.0 : 0.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: const BorderSide(
              color: primaryAccentColor,
              width: 2.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(
              color: isFocused ? primaryAccentColor : Colors.transparent,
              width: isFocused ? 2.0 : 0.0,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: isFocused ? primaryAccentColor : primaryDarkBackground.withOpacity(0.5),
            ),
            onPressed: () {
              // إذا كانت هناك دالة تبديل محددة (لحقل تكرار كلمة المرور)، استخدمها
              if (onVisibilityToggle != null) {
                onVisibilityToggle();
              } else {
                // وإلا، استخدم السلوك الافتراضي لتبديل رؤية كلمة المرور
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              }
            },
          )
              : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'field_required'.tr; // يجب إضافة مفتاح التعريب هذا
          }
          if (fieldName == 'email' && !GetUtils.isEmail(value)) {
            return 'invalid_email'.tr; // يجب إضافة مفتاح التعريب هذا
          }
          // تنبيه: يتم استخدام حقل 'Repeat password' كرقم هاتف طوارئ
          if (fieldName == 'repeatPassword') { // التعديل على اسم الحقل الجديد
            if (value != _passwordController.text) {
              return 'passwords_do_not_match'.tr; // يجب إضافة مفتاح التعريب هذا
            }
          }
          return null;
        },
        onTap: () {
          // Manually handle focus change to trigger UI update
          setState(() {
            _currentField = fieldName;
          });
        },
      ),
    );
  }

  Widget _buildSignUpButton() {
    final bool isActive = _currentField == 'signUp';

    return Padding(
      // تم تقليل الـ Padding الرأسي إلى 3.0
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: InkWell(
        onTap: () => _signUp(context),
        onDoubleTap: () => _signUp(context),
        child: Container(
          height: 43,
          width: 152,
          decoration: BoxDecoration(
            color: isActive ? primaryAccentColor : primaryAccentColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12.0),
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: primaryDarkBackground, strokeWidth: 2),
          )
              : Text(
            'sign up'.tr, // يجب إضافة مفتاح التعريب هذا
            style: const TextStyle(
              color: primaryDarkBackground,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // FIX: استبدال Consumer بـ GetBuilder للاستماع لتحديثات المتحكم (مثل حالة isListening)
    return GetBuilder<BleController>(
      builder: (bleController) {
        return GestureDetector(
          onTap: _handleScreenTap,
          // تمرير المتحكم لـ _onLongPressStart
          onLongPressStart: (_) => _onLongPressStart(bleController),
          onLongPressEnd: _onLongPressEnd,
          child: Scaffold(
            backgroundColor: primaryDarkBackground,
            body: Stack(
              children: [
                // خلفية الشاشة (بدون تغيير)
                Container(
                  constraints: const BoxConstraints.expand(),
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(kBackgroundImagePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // تأثير التغبيش (بدون تغيير)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: primaryDarkBackground.withOpacity(0.5),
                    ),
                  ),
                ),

                // المحتوى الرئيسي
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            // تم إزالة maxHeight للسماح بالتمرير وحل مشكلة الـ overflow
                          ),
                          child: Column(
                            // هذا يضمن أن البوكس يتوسط عمودياً
                            mainAxisAlignment: MainAxisAlignment.center,
                            // يتم التوسيط الأفقية مبدئياً
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 🔑 التعديل هنا: استخدام Padding مخصص للهوامش 39 يسار و 34 يمين
                              Padding(
                                padding: const EdgeInsets.only(left: 39.0, right: 34.0),
                                child: Container(
                                  width: 317, // عرض البوكس
                                  height: 523, // ارتفاع البوكس
                                  // تم الحفاظ على الـ padding الرأسي عند 8.0
                                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                                  decoration: BoxDecoration(
                                    color: whiteOverlayColor, // لون البوكس: أبيض شفاف (20% opacity)
                                    borderRadius: BorderRadius.circular(24.0), // نصف القطر
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start, // الترتيب من الأعلى
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // 1. Header Image (الصورة الآن داخل البوكس)
                                        Center(
                                          child: Image.asset(
                                            kHeaderImagePath,
                                            height: 80,
                                          ),
                                        ),
                                        // تم تقليل الفاصل من 5 إلى 0
                                        const SizedBox(height: 0),

                                        // عنوان "Create account"
                                        Center(
                                          child: Text(
                                            'Create account'.tr, // يجب إضافة مفتاح التعريب هذا
                                            style: const TextStyle(
                                              color: primaryAccentColor,
                                              fontSize: 30,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // تم تقليل الفاصل من 5 إلى 0
                                        const SizedBox(height: 0),

                                        // Input fields
                                        _buildInputField(
                                          controller: _fullNameController,
                                          hintTextKey: 'Full name', // يجب إضافة مفتاح التعريب هذا
                                          keyboardType: TextInputType.name,
                                          fieldName: 'fullName',
                                        ),
                                        _buildInputField(
                                          controller: _emailController,
                                          hintTextKey: 'Email address', // يجب إضافة مفتاح التعريب هذا
                                          keyboardType: TextInputType.emailAddress,
                                          fieldName: 'email',
                                        ),
                                        _buildInputField(
                                          controller: _passwordController,
                                          hintTextKey: 'Password', // يجب إضافة مفتاح التعريب هذا
                                          keyboardType: TextInputType.visiblePassword,
                                          fieldName: 'password',
                                          isPassword: true,
                                          isVisible: _isPasswordVisible,
                                        ),
                                        // حقل تكرار كلمة المرور مع أيقونة العين المضافة
                                        _buildInputField(
                                          controller: _repeatPasswordController, // تم التعديل على المتحكم الجديد
                                          hintTextKey: 'Repeat password', // يجب إضافة مفتاح التعريب هذا
                                          keyboardType: TextInputType.visiblePassword,
                                          fieldName: 'repeatPassword', // تم التعديل على اسم الحقل الجديد
                                          isPassword: true,
                                          isVisible: _isRepeatPasswordVisible,
                                          onVisibilityToggle: () {
                                            setState(() {
                                              _isRepeatPasswordVisible = !_isRepeatPasswordVisible;
                                            });
                                          },
                                        ),

                                        // Sign Up Button
                                        Center(child: _buildSignUpButton()),

                                        // Or with Divider
                                        _buildOrDivider(),

                                        // Social Buttons Row
                                        Center(child: _buildSocialButtonsRow()),

                                        // "Already have account? Sign in here" link
                                        Center(child: _buildSignInLink()),

                                        // إضافة مساحة سفلية إضافية صغيرة للموازنة
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Overlay (Loading/Listening/Processing) (بدون تغيير)
                if (_isAwaitingInput ||
                    bleController.isListening ||
                    _isLoading ||
                    _isProcessingCommand)
                  Positioned.fill(
                    child: _buildOverlay(bleController),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Overlay for Loading/Listening screen (بدون تغيير)
  Widget _buildOverlay(BleController bleController) {
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
              _isLoading
                  ? 'saving_message'.tr // يجب إضافة مفتاح التعريب هذا
                  : (bleController.isListening || _isProcessingCommand)
                  ? 'listening_message'.tr // يجب إضافة مفتاح التعريب هذا
                  : 'processing_command'.tr,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}