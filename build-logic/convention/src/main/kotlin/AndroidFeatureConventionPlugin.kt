import android.template.configureAndroidCompose
import android.template.configureKotlinAndroid
import android.template.libs
import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * Convention plugin for Android Feature modules (with Compose + Hilt + ViewModel).
 * Applies: android.library + compose + hilt + navigation3 dependencies
 *
 * Usage: plugins { alias(libs.plugins.template.android.feature) }
 */
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            apply(plugin = "template.android.library.compose")
            apply(plugin = "template.hilt")

            extensions.configure<LibraryExtension> {
                defaultConfig.testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
            }

            dependencies {
                "implementation"(libs.findLibrary("androidx-lifecycle-runtime-compose").get())
                "implementation"(libs.findLibrary("androidx-lifecycle-runtime-ktx").get())
                "implementation"(libs.findLibrary("androidx-lifecycle-viewmodel-compose").get())
                "implementation"(libs.findLibrary("androidx-navigation3-runtime").get())

                // Testing
                "testImplementation"(libs.findLibrary("junit").get())
                "testImplementation"(libs.findLibrary("kotlinx-coroutines-test").get())
            }
        }
    }
}
