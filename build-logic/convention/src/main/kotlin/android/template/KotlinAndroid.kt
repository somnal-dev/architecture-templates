package android.template

import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.dsl.TestExtension
import org.gradle.api.Project

private const val COMPILE_SDK = 36
private const val MIN_SDK = 24

/**
 * Configure base Android options on ApplicationExtension.
 * Note: In AGP 9.0+, Kotlin plugin is built-in — no need to apply org.jetbrains.kotlin.android.
 */
internal fun Project.configureKotlinAndroid(extension: ApplicationExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}

/**
 * Configure base Android options on LibraryExtension.
 */
internal fun Project.configureKotlinAndroid(extension: LibraryExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}

/**
 * Configure base Android options on TestExtension.
 */
internal fun Project.configureKotlinAndroid(extension: TestExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}
