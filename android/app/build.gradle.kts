import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties (release 서명 설정) — 없어도 debug 키로 빌드 가능하게 graceful 처리
// A local fixture build uses a separate Android storage sandbox.
val localMemberTest = (project.findProperty("dart-defines") as? String)
    ?.split(",")?.any {
        String(Base64.getDecoder().decode(it)) == "LOCAL_MEMBER_TEST=true"
    } == true
if (localMemberTest && gradle.startParameter.taskNames.any {
        it.contains("release", ignoreCase = true) || it.contains("profile", ignoreCase = true)
    }) {
    throw GradleException("Local member fixtures are debug-only")
}
val mapsApiKey = (project.findProperty("dart-defines") as? String)?.split(",")
    ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
    ?.firstOrNull { it.startsWith("GOOGLE_MAPS_API_KEY=") }?.substringAfter("=") ?: ""
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.bluetilelab.apt_ev"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play Console 에 등록된 패키지명. namespace(com.bluetilelab.apt_ev) 는 R 클래스
        // 생성용으로 그대로 두고, 게시 식별자만 apt.ev.service 로 분리.
        applicationId = "apt.ev.service"
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
        minSdk = flutter.minSdkVersion
        // Google Play 업데이트 요구사항: Android 16(API 36) 대상.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            if (localMemberTest) applicationIdSuffix = ".localtest"
        }
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
