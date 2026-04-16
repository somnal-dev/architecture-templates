import android.template.libs
import com.android.build.gradle.api.AndroidBasePlugin
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.dependencies

/**
 * Convention plugin for Hilt dependency injection.
 * Automatically applies KSP and adds hilt-android / hilt-compiler dependencies.
 *
 * Usage: plugins { alias(libs.plugins.template.hilt) }
 */
class HiltConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            apply(plugin = "com.google.devtools.ksp")

            // Add support for Android modules, based on AndroidBasePlugin
            pluginManager.withPlugin("com.android.base") {
                apply(plugin = "com.google.dagger.hilt.android")
                dependencies {
                    "implementation"(libs.findLibrary("hilt-android").get())
                    "ksp"(libs.findLibrary("hilt-compiler").get())
                }
            }
        }
    }
}
