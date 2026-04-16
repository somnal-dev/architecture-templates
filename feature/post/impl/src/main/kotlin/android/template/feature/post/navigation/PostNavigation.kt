package android.template.feature.post.navigation

import android.template.core.navigation.Navigator
import android.template.feature.post.ui.PostScreen
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey

@Composable
fun EntryProviderScope<NavKey>.PostEntry(navigator: Navigator) {
    entry<PostNavKey> {
        PostScreen(
            onPostClick = { /* TODO: navigate to detail — e.g. navigator.navigateToPostDetail(id) */ },
            modifier = Modifier.padding(16.dp)
        )
    }
}
