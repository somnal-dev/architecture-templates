pluginManagement {
    includeBuild("build-logic")
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

rootProject.name = "multimodule-template"

include(":app")
include(":core:model")
include(":core:network")
include(":core:data")
include(":core:database")
include(":core:datastore")
include(":core:testing")
include(":core:ui")
include(":feature:post:api")
include(":feature:post:impl")
include(":ui-test-hilt-manifest")
