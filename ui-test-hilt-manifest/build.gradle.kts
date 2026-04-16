plugins {
    alias(libs.plugins.template.android.library)
    alias(libs.plugins.template.hilt)
}

android {
    namespace = "android.template.uitesthiltmanifest"
}

dependencies {
    implementation(libs.androidx.activity.compose)
}
