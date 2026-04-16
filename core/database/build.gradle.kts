plugins {
    alias(libs.plugins.template.android.library)
    alias(libs.plugins.template.hilt)
    alias(libs.plugins.template.android.room)
}

android {
    namespace = "android.template.core.database"

    defaultConfig {
        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}
