plugins {
    alias(libs.plugins.template.android.library)
}

android {
    namespace = "android.template.core.navigation"
}

dependencies {
    api(libs.androidx.navigation3.runtime)
}
