// user_profile_screen.dart

import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // ❌ تم إزالة: تم استبدالها بـ GetX
import '../services/ble_controller.dart';
import 'registration_screen.dart'; // Contains MedicalProfileScreen
import 'package:get/get.dart'; // ✅ إضافة GetX
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../widgets/common_bottom_nav_bar.dart'; // ✅ إضافة استيراد الـ CommonBottomNavBar

const Color neonColor = Color(0xFFFFB267);
const Color darkSurface = Color(0xFF282424);
const Color onBackground = Color(0xFFE0E0E0);
const Color secondaryText = Color(0xFFA0A0A0);
const Color darkText = Color(0xFF1B1B1B);

const Color gradientTopColor = Color(0xFF2D2929);
const Color gradientBottomColor = Color(0xFF110F0F);


class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  Widget _buildInfoField({
    required String labelKey,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelKey.tr,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                icon,
                color: neonColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔑 استخدام GetX للحصول على المتحكم
    final bleController = Get.find<BleController>();
    final profile = bleController.userProfile;

    // 💡 في حالة عدم وجود ملف شخصي، يجب توجيه المستخدم لصفحة التسجيل
    if (profile == null) {
      // Get.offAllNamed('/sign_up'); // يمكن استخدام هذه الطريقة للتنقل
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'profile_not_found'.tr,
                style: const TextStyle(color: onBackground, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Get.offAllNamed('/sign_up');
                },
                child: Text('go_to_registration'.tr),
              ),
            ],
          ),
        ),
      );
    }

    // 🔑 تعيين قيم المتغيرات من ملف المستخدم
    final fullName = profile.fullName;
    final age = profile.age.toString();

    final bloodType = profile.bloodType;
    final homeAddress = profile.homeAddress;

    // ... (بقية المتغيرات من UserProfile)


    return Scaffold(
      // ✅ إضافة CommonBottomNavBar وتعيين الـ currentIndex إلى 2 (الملف الشخصي)
      bottomNavigationBar: const CommonBottomNavBar(currentIndex: 2),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientTopColor, gradientBottomColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'my_profile'.tr,
                      style: const TextStyle(
                        color: onBackground,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.home_20_regular, color: onBackground),
                      onPressed: () {
                        bleController.stopListening(shouldSpeakStop: false);
                        Get.offAllNamed('/home');
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: ListView(
                    children: [
                      // قسم الصورة والاسم
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 50,
                              backgroundColor: darkSurface,
                              child: Icon(FluentIcons.person_48_filled, color: neonColor, size: 50),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: onBackground,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'age_years_old'.trParams({'age': age}),
                              style: const TextStyle(
                                color: secondaryText,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Divider(color: secondaryText, thickness: 0.5),
                      const SizedBox(height: 10),

                      // معلومات الاتصال
                      Text(
                        'contact_information'.tr,
                        style: const TextStyle(
                          color: neonColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      const SizedBox(height: 30),

                      // المعلومات الطبية
                      Text(
                        'medical_information'.tr,
                        style: const TextStyle(
                          color: neonColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),


                      _buildInfoField(
                        labelKey: 'blood_type_label',
                        value: bloodType,
                        icon: FluentIcons.drop_20_filled,
                      ),


                      const SizedBox(height: 30),

                      // العنوان
                      Text(
                        'address'.tr,
                        style: const TextStyle(
                          color: neonColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      _buildInfoField(
                        labelKey: 'home_address_label',
                        value: homeAddress,
                        icon: FluentIcons.location_20_filled,
                      ),

                      const SizedBox(height: 30),

                      // زر التعديل
                      ElevatedButton(
                        onPressed: () {
                          // إيقاف أي نطق قبل التنقل
                          bleController.stopListening(shouldSpeakStop: false);
                          // 💡 التوجيه إلى شاشة تعديل الملف الطبي/التسجيل
                          Get.to(() => const MedicalProfileScreen(
                            nextRoute: '/user_profile', // العودة لصفحة الملف الشخصي بعد التعديل
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonColor,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          'edit_profile_button'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}