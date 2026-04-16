package android.template.core.datastore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class UserPreferencesDataSource @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    val userPreferences: Flow<UserPreferences> = dataStore.data.map { prefs ->
        UserPreferences(
            darkThemeEnabled = prefs[KEY_DARK_THEME] ?: false,
            lastOpenedPostId = prefs[KEY_LAST_OPENED_POST_ID],
        )
    }

    suspend fun setDarkThemeEnabled(enabled: Boolean) {
        dataStore.edit { it[KEY_DARK_THEME] = enabled }
    }

    suspend fun setLastOpenedPostId(postId: Int) {
        dataStore.edit { it[KEY_LAST_OPENED_POST_ID] = postId }
    }

    private companion object {
        val KEY_DARK_THEME = booleanPreferencesKey("dark_theme_enabled")
        val KEY_LAST_OPENED_POST_ID = intPreferencesKey("last_opened_post_id")
    }
}
