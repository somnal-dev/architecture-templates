plugins {
    alias(libs.plugins.template.android.feature)
}

android {
    namespace = "android.template.feature.post"

    defaultConfig {
        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":feature:post:api"))

    androidTestImplementation(project(":core:testing"))

    // Core Android dependencies
    implementation(libs.androidx.activity.compose)

    // Arch Components
    implementation(libs.androidx.hilt.lifecycle.viewmodel.compose)

    // Compose
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    // Hilt testing
    androidTestImplementation(libs.hilt.android.testing)
    kspAndroidTest(libs.hilt.compiler)
    testImplementation(libs.hilt.android.testing)
    kspTest(libs.hilt.compiler)

    // Instrumented tests
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
