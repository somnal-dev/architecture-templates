import android.template.libs
import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * Convention plugin for Feature Navigation modules (Compose + Serialization).
 * Applies: android.library + compose + kotlin.serialization
 *
 * Usage: plugins { alias(libs.plugins.template.android.feature.navigation) }
 */
class AndroidFeatureNavigationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            apply(plugin = "template.android.library.compose")
            apply(plugin = "org.jetbrains.kotlin.plugin.serialization")

            dependencies {
                "implementation"(libs.findLibrary("kotlinx-serialization-core").get())
                "implementation"(libs.findLibrary("kotlinx-serialization-json").get())
                "implementation"(libs.findLibrary("androidx-navigation3-runtime").get())
            }
        }
    }
}
