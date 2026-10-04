import com.android.build.gradle.AppExtension
import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play App Signing: Google holds the app signing key. Release artifacts are
// signed only with the upload key, which stays outside the repository
// (gitignored android/key.properties, or environment variables). Never fall
// back to the debug keystore. Do not print keystore paths or passwords.
val keystorePropertiesFile: File = rootProject.file("key.properties")

val uploadKeyEnv =
    mapOf(
        "storeFile" to "ANDROID_KEYSTORE_FILE",
        "storePassword" to "ANDROID_KEYSTORE_PASSWORD",
        "keyAlias" to "ANDROID_KEY_ALIAS",
        "keyPassword" to "ANDROID_KEY_PASSWORD",
    )

class UploadKey(
    val storeFile: File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
) {
    override fun toString(): String = "UploadKey(redacted)"
}

sealed class UploadKeyStatus {
    class Ready(val material: UploadKey) : UploadKeyStatus() {
        override fun toString(): String = "Ready(redacted)"
    }

    class Missing(val message: String) : UploadKeyStatus()
}

val readUploadKeyStatus: Project.() -> UploadKeyStatus = {
    val properties = Properties()
    val unreadable =
        if (!keystorePropertiesFile.exists()) {
            false
        } else {
            try {
                keystorePropertiesFile.inputStream().use { properties.load(it) }
                false
            } catch (_: Exception) {
                true
            }
        }

    if (unreadable) {
        UploadKeyStatus.Missing(
            "Build de release interrompido: android/key.properties não pôde ser lido. " +
                "O release não usa a debug key.",
        )
    } else {
        fun resolve(propertyName: String): String? {
            val fromFile = properties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }
            if (fromFile != null) {
                return fromFile
            }
            val envName = uploadKeyEnv.getValue(propertyName)
            return System.getenv(envName)?.trim()?.takeIf { it.isNotEmpty() }
        }

        val resolved = uploadKeyEnv.keys.associateWith { resolve(it) }
        val missing = resolved.filterValues { it == null }.keys.toList()
        if (missing.size == uploadKeyEnv.size) {
            UploadKeyStatus.Missing(
                "Build de release interrompido: upload key ausente. " +
                    "Informe android/key.properties (ignorado pelo git) ou as variáveis " +
                    "ANDROID_KEYSTORE_FILE, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS e " +
                    "ANDROID_KEY_PASSWORD. O release não usa a debug key.",
            )
        } else if (missing.isNotEmpty()) {
            UploadKeyStatus.Missing(
                "Build de release interrompido: upload key incompleta. Campos ausentes: " +
                    "${missing.joinToString(", ")}. O release não usa a debug key.",
            )
        } else {
            val storeFile = file(resolved.getValue("storeFile")!!)
            if (!storeFile.isFile) {
                UploadKeyStatus.Missing(
                    "Build de release interrompido: arquivo da upload key não encontrado. " +
                        "Confira storeFile (relativo a android/app) ou ANDROID_KEYSTORE_FILE. " +
                        "O release não usa a debug key.",
                )
            } else {
                UploadKeyStatus.Ready(
                    UploadKey(
                        storeFile = storeFile,
                        storePassword = resolved.getValue("storePassword")!!,
                        keyAlias = resolved.getValue("keyAlias")!!,
                        keyPassword = resolved.getValue("keyPassword")!!,
                    ),
                )
            }
        }
    }
}

val readyUploadKey = (readUploadKeyStatus() as? UploadKeyStatus.Ready)?.material

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

    signingConfigs {
        if (readyUploadKey != null) {
            create("release") {
                keyAlias = readyUploadKey.keyAlias
                keyPassword = readyUploadKey.keyPassword
                storeFile = readyUploadKey.storeFile
                storePassword = readyUploadKey.storePassword
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            if (readyUploadKey != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val verifyReleaseUploadKey =
    tasks.register("verifyReleaseUploadKey") {
        doLast {
            val androidExt = project.extensions.getByType(AppExtension::class.java)
            val release = androidExt.buildTypes.getByName("release")
            if (release.isDebuggable) {
                throw org.gradle.api.GradleException(
                    "Build de release interrompido: o release está debuggable.",
                )
            }
            val signing = release.signingConfig
            if (signing != null && signing.name == "debug") {
                throw org.gradle.api.GradleException(
                    "Build de release interrompido: a assinatura de release é a debug key. Sem fallback.",
                )
            }
            val status = readUploadKeyStatus(project)
            if (signing == null || status is UploadKeyStatus.Missing) {
                val message =
                    (status as? UploadKeyStatus.Missing)?.message
                        ?: "Build de release interrompido: upload key ausente. O release não usa a debug key."
                throw org.gradle.api.GradleException(message)
            }
            if (signing.name != "release" || signing.storeFile == null || !signing.storeFile!!.isFile) {
                throw org.gradle.api.GradleException(
                    "Build de release interrompido: a assinatura de release não é a upload key. Sem fallback para a debug key.",
                )
            }
            if (
                signing.storePassword.isNullOrEmpty() ||
                signing.keyPassword.isNullOrEmpty() ||
                signing.keyAlias.isNullOrEmpty()
            ) {
                throw org.gradle.api.GradleException(
                    "Build de release interrompido: upload key incompleta. O release não usa a debug key.",
                )
            }
        }
    }

tasks.configureEach {
    val isReleasePackaging =
        name.endsWith("Release") &&
            (
                name.contains("package") ||
                    name.contains("bundle") ||
                    name.contains("sign") ||
                    name.contains("assemble")
            )
    if (isReleasePackaging) {
        dependsOn(verifyReleaseUploadKey)
    }
}

flutter {
    source = "../.."
}
