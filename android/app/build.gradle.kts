import com.google.firebase.appdistribution.gradle.firebaseAppDistribution

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.appdistribution")
}

val googleServicesFile = layout.projectDirectory.file("google-services.json").asFile
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val firebaseAppId = providers.environmentVariable("FIREBASE_APP_ID")
val firebaseTesterGroups = providers.environmentVariable("FIREBASE_TESTER_GROUPS")
val firebaseTesters = providers.environmentVariable("FIREBASE_TESTERS")
val firebaseReleaseNotes =
    providers.environmentVariable("FIREBASE_RELEASE_NOTES").orElse("Build de teste do Meu Agente de Emprego")
val firebaseServiceCredentialsFile = providers.environmentVariable("GOOGLE_APPLICATION_CREDENTIALS")

fun com.google.firebase.appdistribution.gradle.AppDistributionExtension.configureFirebaseDistribution() {
    artifactType = "APK"
    releaseNotes = firebaseReleaseNotes.get()
    val directTesters = firebaseTesters.orNull?.takeIf { it.isNotBlank() }
    if (directTesters != null) {
        testers = directTesters
    } else {
        firebaseTesterGroups.orNull?.takeIf { it.isNotBlank() }?.let { groups = it }
    }
    firebaseAppId.orNull?.takeIf { it.isNotBlank() }?.let { appId = it }
    firebaseServiceCredentialsFile.orNull?.takeIf { it.isNotBlank() }?.let {
        serviceCredentialsFile = it
    }
}

android {
    namespace = "br.com.meuagentedeemprego.app"
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
        applicationId = "br.com.meuagentedeemprego.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            firebaseAppDistribution {
                configureFirebaseDistribution()
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            firebaseAppDistribution {
                configureFirebaseDistribution()
            }
        }
    }
}

flutter {
    source = "../.."
}
