import java.util.Properties

plugins {
    id("com.android.application")
    // Le plugin Kotlin DOIT etre applique, sinon MainActivity.kt n'est pas
    // compile dans le DEX -> ClassNotFoundException au lancement (crash).
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature Terebi : cle UNIQUE (debug + release) lue depuis key.properties
// (gitignore, keystore hors repo). Ainsi les builds locaux et distribues
// partagent la meme signature -> reinstall toujours par-dessus (aucune perte de
// donnees). Absente en CI sans le fichier -> repli signature debug par defaut.
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        keystorePropsFile.inputStream().use { load(it) }
    }
}
val hasKeystore = keystoreProps.getProperty("storeFile") != null

android {
    namespace = "com.terebi.terebi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.terebi.terebi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("terebi") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Cle Terebi si dispo, sinon signature debug (repli CI/sans keystore).
        val terebiOrDebug = if (hasKeystore) {
            signingConfigs.getByName("terebi")
        } else {
            signingConfigs.getByName("debug")
        }
        release {
            signingConfig = terebiOrDebug
        }
        debug {
            signingConfig = terebiOrDebug
        }
    }
}

flutter {
    source = "../.."
}

// Aligne la cible JVM de Kotlin sur Java 17 (sinon Kotlin vise 21 par defaut ->
// "Inconsistent JVM-target compatibility"). Le plugin Kotlin est applique en
// tete, donc le bloc kotlin { } est disponible.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
