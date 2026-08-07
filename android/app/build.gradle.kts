plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    namespace = "com.example.stock_control_elcope"

    compileSdk = 36

    ndkVersion = "30.0.15729638"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {

        applicationId = "com.example.stock_control_elcope"

        minSdk = flutter.minSdkVersion

        targetSdk = 36

        versionCode = flutter.versionCode

        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}