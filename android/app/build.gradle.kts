import java.util.Properties
import java.io.FileInputStream
import com.android.build.api.dsl.ApplicationExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val requestsReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

extensions.configure<ApplicationExtension> {
    namespace = "com.thezello.lemongba"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.thezello.lemongba"
        // AAudio is the production audio path; API 26 is its platform floor.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DLIBMGBA_ONLY=ON",
                )
            }
        }

        ndk {
            // Phone + emulator ABIs
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        if (requestsReleaseBuild) {
            check(keystorePropertiesFile.exists()) {
                "Missing android/key.properties — required for release signing. " +
                    "Create upload keystore + key.properties (see project docs)."
            }
            create("release") {
                val alias = keystoreProperties["keyAlias"] as String?
                val keyPassword = keystoreProperties["keyPassword"] as String?
                val storePassword = keystoreProperties["storePassword"] as String?
                val storeFileName = keystoreProperties["storeFile"] as String?
                require(!alias.isNullOrBlank()) { "key.properties: keyAlias is required" }
                require(!keyPassword.isNullOrBlank()) {
                    "key.properties: keyPassword is required"
                }
                require(!storePassword.isNullOrBlank()) {
                    "key.properties: storePassword is required"
                }
                require(!storeFileName.isNullOrBlank()) {
                    "key.properties: storeFile is required"
                }
                keyAlias = alias
                this.keyPassword = keyPassword
                this.storePassword = storePassword
                // key.properties + keystore live under android/ (rootProject).
                storeFile = rootProject.file(storeFileName)
                check(storeFile!!.exists()) {
                    "Keystore not found: ${storeFile!!.absolutePath}"
                }
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            isJniDebuggable = false
            // Never silently fall back to debug signing for Play uploads.
            if (requestsReleaseBuild) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
