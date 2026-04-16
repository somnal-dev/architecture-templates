plugins {
    alias(libs.plugins.template.android.application.compose)
    alias(libs.plugins.template.hilt)
}

android {
    namespace = "android.template"

    defaultConfig {
        applicationId = "android.template"
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

// Enable room auto-migrations
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    implementation(project(":core:ui"))
    implementation(project(":feature:post:impl"))
    implementation(project(":feature:post:api"))

    // Network
    implementation(project(":core:network"))

    // Core Android dependencies
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)

    // Arch Components
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    // Compose
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)

    // Navigation
    implementation(libs.androidx.navigation3.ui)
    implementation(libs.androidx.lifecycle.viewmodel.navigation3)

    implementation(libs.timber)


    // Hilt testing
    kspAndroidTest(libs.hilt.compiler)
    kspTest(libs.hilt.compiler)

    // Instrumented tests
    androidTestImplementation(project(":core:testing"))
    androidTestImplementation(project(":core:data"))
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.hilt.android.testing)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
}
