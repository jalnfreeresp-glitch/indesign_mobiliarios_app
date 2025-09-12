import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
    }
    return properties
}

fun keyProperties(): Properties {
    val properties = Properties()
    val keyPropertiesFile = rootProject.file("android/key.properties")
    if (keyPropertiesFile.exists()) {
        properties.load(FileInputStream(keyPropertiesFile))
    }
    return properties
}

android {
    namespace = "com.example.indesign_mobiliarios_app"
    compileSdk = 36   // 👈 subido a 36 para compatibilidad

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"  // 👈 actualizado, evita warnings de Java 8 obsoleto
    }

    defaultConfig {
        applicationId = "com.example.indesign_mobiliarios_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36   // 👈 actualizado también
        versionCode = localProperties().getProperty("flutter.versionCode")?.toInt() ?: 1
        versionName = localProperties().getProperty("flutter.versionName") ?: "1.0"
    }

    signingConfigs {
        create("release") {
            if (keyProperties().containsKey("storeFile")) {
                storeFile = file(keyProperties()["storeFile"] as String)
                storePassword = keyProperties()["storePassword"] as String
                keyAlias = keyProperties()["keyAlias"] as String
                keyPassword = keyProperties()["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
