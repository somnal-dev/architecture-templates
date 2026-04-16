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
    implementation(projects.core.database)

    implementation(libs.kotlinx.coroutines.android)

    api(projects.core.model)
    api(projects.core.network)

    // Local tests
    testImplementation(libs.kotlinx.coroutines.test)
}
