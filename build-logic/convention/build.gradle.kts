import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    `kotlin-dsl`
}

group = "android.template.buildlogic"

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.kotlin.gradlePlugin)
    compileOnly(libs.ksp.gradlePlugin)
    compileOnly(libs.compose.gradlePlugin)
}

tasks {
    validatePlugins {
        enableStricterValidation = true
        failOnWarning = true
    }
}

gradlePlugin {
    plugins {
        register("androidApplication") {
            id = "template.android.application"
            implementationClass = "AndroidApplicationConventionPlugin"
        }
        register("androidApplicationCompose") {
            id = "template.android.application.compose"
            implementationClass = "AndroidApplicationComposeConventionPlugin"
        }
        register("androidLibrary") {
            id = "template.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidLibraryCompose") {
            id = "template.android.library.compose"
            implementationClass = "AndroidLibraryComposeConventionPlugin"
        }
        register("androidFeature") {
            id = "template.android.feature"
            implementationClass = "AndroidFeatureConventionPlugin"
        }
        register("androidFeatureNavigation") {
            id = "template.android.feature.navigation"
            implementationClass = "AndroidFeatureNavigationConventionPlugin"
        }
        register("androidTest") {
            id = "template.android.test"
            implementationClass = "AndroidTestConventionPlugin"
        }
        register("hilt") {
            id = "template.hilt"
            implementationClass = "HiltConventionPlugin"
        }
        register("androidRoom") {
            id = "template.android.room"
            implementationClass = "AndroidRoomConventionPlugin"
        }
    }
}
