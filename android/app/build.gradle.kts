plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chefito.app"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
    applicationId = "com.chefito.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
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

dependencies {
    implementation("com.google.mlkit:image-labeling:17.0.7")
    implementation("com.google.mlkit:object-detection:17.0.0")
    implementation("com.google.mlkit:object-detection-custom:17.0.1")
    implementation("com.google.android.gms:play-services-mlkit-image-labeling:16.0.8")
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
