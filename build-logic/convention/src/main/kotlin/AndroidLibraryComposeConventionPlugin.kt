import android.template.configureAndroidCompose
import android.template.configureKotlinAndroid
import com.android.build.api.dsl.LibraryExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure

class AndroidLibraryComposeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            apply(plugin = "com.android.library")
            apply(plugin = "org.jetbrains.kotlin.plugin.compose")

            extensions.configure<LibraryExtension> {
                configureKotlinAndroid(this)
                defaultConfig.testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
                buildFeatures {
                    aidl = false
                    buildConfig = false
                    renderScript = false
                    shaders = false
                }
                configureAndroidCompose(this)
            }
        }
    }
}
