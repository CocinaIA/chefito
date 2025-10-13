plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chefito.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    applicationId = "com.chefito.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    configurations.all {
        resolutionStrategy {
            force("androidx.exifinterface:exifinterface:1.3.7")
        }
    }
}

flutter {
    source = "../.."
}


apply(plugin = "com.google.gms.google-services")

afterEvaluate {
    tasks.findByName("assembleDebug")?.let { assembleTask ->
        tasks.register<Copy>("copyDebugApk") {
            from("$buildDir/outputs/apk/debug/app-debug.apk")
            into("$rootDir/../build/app/outputs/flutter-apk")
            dependsOn(assembleTask)
        }
    }
}
