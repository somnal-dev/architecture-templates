plugins {
    alias(libs.plugins.template.android.library.compose)
}

android {
    namespace = "android.template.core.ui"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    // Core Android dependencies
    implementation(libs.androidx.core.ktx)

    // Compose
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
}
