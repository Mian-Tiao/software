plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.memory"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    // ✅ Java 11 + desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11   // ✅ Kotlin DSL 要有 =
        targetCompatibility = JavaVersion.VERSION_11   // ✅ Kotlin DSL 要有 =
        isCoreLibraryDesugaringEnabled = true          // ✅ Kotlin DSL 用 isXXX
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.memory"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Kotlin DSL 語法：要用 ( ) 而不是 ' '
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
