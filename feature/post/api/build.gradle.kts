plugins {
    alias(libs.plugins.template.android.feature.navigation)
}

android {
    namespace = "android.template.feature.post.api"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    api(projects.core.navigation)
}
