plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.voicetranslate.voice_translate"
    compileSdk = flutter.compileSdkVersion

    // NDK versione 27 per compatibilità con plugin (whisper.cpp, llama.cpp)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.voicetranslate.voice_translate"
        // minSdk 26 come da requisiti (Android 8.0+)
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ABI filter: solo ARM64 per ottimizzazione
        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        // Configurazione CMake per librerie native
        externalNativeBuild {
            cmake {
                // Flag CMake per ottimizzazioni ARM NEON
                cppFlags += listOf("-std=c++17", "-O3", "-DNDEBUG")
                arguments += listOf(
                    "-DANDROID_ARM_NEON=TRUE",
                    "-DANDROID_STL=c++_shared"
                )
            }
        }
    }

    // Configurazione CMake per compilazione whisper.cpp e llama.cpp
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // Signing con chiavi debug per ora
            signingConfig = signingConfigs.getByName("debug")
            // Ottimizzazioni per release
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "native/lib/osx-aarch64/**",
                "native/lib/osx-x86_64/**",
                "native/lib/linux-aarch64/**",
                "native/lib/linux-x86_64/**",
                "native/lib/win-x86_64/**",
            )
        }
    }
}

dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.24.2")
    implementation(platform("ai.djl:bom:0.33.0"))
    implementation("ai.djl:api")
    implementation("ai.djl.android:core")
    implementation("ai.djl.huggingface:tokenizers")
    runtimeOnly("ai.djl.android:tokenizer-native:0.33.0")
}

flutter {
    source = "../.."
}
