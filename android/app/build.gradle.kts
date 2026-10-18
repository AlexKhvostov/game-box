import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // The shared PHP account/ranking API and explicit Google OAuth client do
    // not use Firebase. Do not attach the obsolete game's google-services.json.
}

val privateSigningPath = System.getenv("UNTOUCH_SIGNING_PROPERTIES")
val privateSigning = Properties()
if (privateSigningPath != null) {
    val privateFile = file(privateSigningPath).canonicalFile
    val projectRoot = rootProject.projectDir.parentFile.canonicalFile
    val localPrivateSigning = projectRoot.resolve(".private/android-signing/signing.properties").canonicalFile
    require(!privateFile.toPath().startsWith(projectRoot.toPath()) || privateFile == localPrivateSigning) {
        "In-project signing credentials must be in .private/android-signing"
    }
    FileInputStream(privateFile).use { privateSigning.load(it) }
}

android {
    buildFeatures { resValues = true }
    namespace = "com.best4u.untouch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Verified against Best4U / Untouch in Play Console on 2026-10-09.
        applicationId = if (System.getenv("UNTOUCH_UI_PROBE") == "true") {
            // Separate acceptance package preserves an older probe installed
            // under another signature/user. Never uninstall it to capture UI.
            when (System.getenv("UNTOUCH_PROBE_FLAVOR")) {
                "simple-energy" -> "com.best4u.untouch.uiprobe.simpleenergy"
                "review" -> "com.best4u.untouch.uiprobe.review"
                else -> "com.best4u.untouch.uiprobe"
            }
        } else "com.best4u.untouch"
        // Play storefront builds have the stable product name; USB builds keep
        // their number so physical test installations remain identifiable.
        val playBuild = System.getenv("UNTOUCH_PLAY_BUILD") == "true" ||
            gradle.startParameter.taskNames.any { it.substringAfterLast(':').equals("bundleRelease", ignoreCase = true) }
        val phoneLabel = if (System.getenv("UNTOUCH_UI_PROBE") == "true") {
            "QA${flutter.versionCode} Untouch"
        } else if (playBuild) "untouch" else "Untouch ${flutter.versionCode}"
        resValue("string", "app_name", phoneLabel)
        // Optional local UI probe: isolated storage and no production API calls.
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (privateSigningPath != null) {
            create("storeRelease") {
                keyAlias = privateSigning.getProperty("keyAlias")
                keyPassword = privateSigning.getProperty("keyPassword") ?: System.getenv("UNTOUCH_SIGNING_PASSWORD")
                storeFile = file(privateSigning.getProperty("storeFile"))
                storePassword = privateSigning.getProperty("storePassword") ?: System.getenv("UNTOUCH_SIGNING_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            // Local APKs may use debug signing; store bundles must never do so.
            signingConfig = signingConfigs.getByName(if (privateSigningPath == null) "debug" else "storeRelease")
        }
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project.path == ":app" && it.name == "bundleRelease" }) {
        require(privateSigningPath != null) { "Google Play AAB requires private release signing credentials" }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.android.installreferrer:installreferrer:2.2")
}
