plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString() ?: "1"
val flutterVersionName = project.findProperty("flutter.versionName")?.toString() ?: "1.0"

android {
    namespace = "com.example.sinkplayer"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    lint {
        checkReleaseBuilds = false
    }

    defaultConfig {
        applicationId = "com.example.sinkplayer"
        minSdk = 24
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}

dependencies {
    // implementation("com.github.TeamNewPipe:NewPipeExtractor:v0.24.4")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
