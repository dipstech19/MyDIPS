import java.util.Properties
import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.dipsmanagment.dipsmanagment"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dipsmanagment.dipsmanagment"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile")!!)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Flutter may regenerate GeneratedPluginRegistrant with direct plugin references; that can fail
// javac on :app when plugin classes are not on the compile classpath. Copy the reflection-based
// template immediately before compiling Java so the build stays reliable.
val pluginRegistrantTemplate = layout.projectDirectory.file("plugin_registrant_templates/GeneratedPluginRegistrant.java")
val pluginRegistrantGenerated = layout.projectDirectory.file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")

tasks.withType<JavaCompile>().configureEach {
    doFirst {
        val src = pluginRegistrantTemplate.asFile
        val dst = pluginRegistrantGenerated.asFile
        if (!src.exists()) {
            throw GradleException("Missing ${src.absolutePath}")
        }
        dst.parentFile.mkdirs()
        src.copyTo(dst, overwrite = true)
    }
}
