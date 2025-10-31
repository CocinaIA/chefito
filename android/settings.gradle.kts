pluginManagement {
    // Make reading flutter.sdk resilient if local.properties is missing in IDE sync
    val flutterSdkPath =
        run {
            val propertiesFile = file("local.properties")
            val fromEnv = System.getenv("FLUTTER_SDK") ?: System.getenv("FLUTTER_HOME")
            if (propertiesFile.exists()) {
                val properties = java.util.Properties()
                propertiesFile.inputStream().use { properties.load(it) }
                val path = properties.getProperty("flutter.sdk")
                require(!path.isNullOrBlank()) { "flutter.sdk not set in local.properties" }
                path
            } else if (!fromEnv.isNullOrBlank()) {
                fromEnv
            } else {
                throw GradleException(
                    "Could not locate Flutter SDK. Create android/local.properties with flutter.sdk=PATH or set FLUTTER_SDK environment variable."
                )
            }
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.2") apply false
    // END: FlutterFire Configuration
    // Upgrade Kotlin to satisfy Flutter's minimum requirement (>= 2.1.0)
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
