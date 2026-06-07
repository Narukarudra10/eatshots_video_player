plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.example.eatshots_video_player"
version = "1.0-SNAPSHOT"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

configure<com.android.build.api.dsl.LibraryExtension> {
    compileSdk = 36
    
    namespace = "com.example.eatshots_video_player"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        minSdk = 21
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
    }
}

dependencies {
    // Add the latest Media3 ExoPlayer modules
    implementation("androidx.media3:media3-exoplayer:1.10.1")
    implementation("androidx.media3:media3-common:1.10.1")
}