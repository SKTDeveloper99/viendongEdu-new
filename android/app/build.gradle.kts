import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseSigningKey = keyPropertiesFile.exists()
if (hasReleaseSigningKey) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.viendong.vidostudentbeta"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.viendong.vidostudentbeta"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Google Play refuses a versionCode that is not higher than the last
        // upload (91 = 6.1.0+91). iOS uses pubspec's build number (6.0.6 (1));
        // Android keeps its own counter. Raise by 1 for every Play upload.
        versionCode = 95
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningKey) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningKey) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
