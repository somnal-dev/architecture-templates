plugins {
    alias(libs.plugins.template.android.library)
    alias(libs.plugins.template.hilt)
}

android {
    namespace = "android.template.core.data"

    defaultConfig {
        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    implementation(project(":core:database"))

    implementation(libs.kotlinx.coroutines.android)

    api(project(":core:model"))
    api(project(":core:network"))

    // Local tests
    testImplementation(libs.kotlinx.coroutines.test)
}
