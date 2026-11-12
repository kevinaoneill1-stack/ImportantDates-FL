plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kevinaoneill.importantdates"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (scheduled reminders).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kevinaoneill.importantdates"
        // Firebase needs Android 6.0 (API 23) or newer.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Version 3 / Build 61 come from pubspec.yaml (version: 3.0.0+61).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two editions from one code base (see FLAVORS_SETUP.md):
    //   personal: Firebase Cloud Sync, com.kevinaoneill.importantdates.personal
    //   public:   Google Drive sync, com.kevinaoneill.importantdates (Play Store)
    // Build with e.g. flutter run --flavor personal -t lib/main_personal.dart
    flavorDimensions += "edition"
    productFlavors {
        create("personal") {
            dimension = "edition"
            applicationIdSuffix = ".personal"
            resValue("string", "app_name", "Important Dates Personal")
        }
        create("public") {
            dimension = "edition"
            resValue("string", "app_name", "Important Dates")
        }
    }

    buildFeatures {
        resValues = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for Play Store release builds.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// The public edition does not use Firebase: skip google-services.json for it,
// so no Firebase project details end up in the Play Store app.
tasks.configureEach {
    if (name.startsWith("process") && name.contains("Public") && name.endsWith("GoogleServices")) {
        enabled = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AppCompat themes (styles.xml) for the local_auth biometric prompt.
    implementation("androidx.appcompat:appcompat:1.7.0")
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
