package android.template

import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.dsl.TestExtension
import org.gradle.api.Project

private const val COMPILE_SDK = 36
private const val MIN_SDK = 24

internal fun Project.configureKotlinAndroid(extension: ApplicationExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}

internal fun Project.configureKotlinAndroid(extension: LibraryExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}

internal fun Project.configureKotlinAndroid(extension: TestExtension) {
    extension.apply {
        compileSdk = COMPILE_SDK
        defaultConfig { minSdk = MIN_SDK }
    }
}
