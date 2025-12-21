import java.util.Properties

val secrets = Properties()
val secretsFile = rootProject.file("secrets.properties")
if (secretsFile.exists()) {
    secretsFile.inputStream().use { secrets.load(it) }
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    defaultConfig {
        // 先讀 secrets.properties，沒有就讀環境變數
        val mapsKey = (secrets["GOOGLE_MAPS_API_KEY"] as String?)
            ?: System.getenv("GOOGLE_MAPS_API_KEY")
            ?: ""

        manifestPlaceholders["googleMapsApiKey"] = mapsKey
    }

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
        minSdk = 23
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
