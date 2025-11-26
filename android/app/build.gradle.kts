plugins {
    // 💡 تم تصحيح الصيغة هنا من 'id "..."' إلى id("...")'
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 💡 تمت الإضافة لتصحيح خطأ 'Namespace not specified'
    namespace = "com.example.blind_new"
    compileSdk = 36 // يمكن تحديثه إلى 34 أو 36 للتوافق

    defaultConfig {
        applicationId = "com.example.blind_new"
        minSdk = flutter.minSdkVersion // لضمان التوافق مع حزم مثل telephony
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Java 8 متوافق مع Android
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
        // إعدادات إضافية للتوافق مع مكتبات Kotlin/Flutter
        freeCompilerArgs += listOf("-Xjvm-default=all")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // تم حذف أي مراجع غير مستخدمة
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}
