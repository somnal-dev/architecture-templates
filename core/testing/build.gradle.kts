plugins {
    alias(libs.plugins.template.android.library)
    alias(libs.plugins.template.hilt)
}

android {
    namespace = "android.template.core.testing"

    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    implementation(libs.androidx.test.runner)
    implementation(libs.hilt.android.testing)
}
