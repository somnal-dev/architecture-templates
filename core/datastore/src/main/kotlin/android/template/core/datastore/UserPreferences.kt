package android.template.core.datastore

data class UserPreferences(
    val darkThemeEnabled: Boolean = false,
    val lastOpenedPostId: Int? = null,
)
