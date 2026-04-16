package android.template.feature.post.navigation

import android.template.feature.post.ui.PostScreen
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavBackStack
import androidx.navigation3.runtime.NavKey

@Composable
fun EntryProviderScope<NavKey>.postEntry(backStack: NavBackStack<NavKey>) {
    entry<PostNavKey> {
        PostScreen(
            onItemClick = { navKey -> backStack.add(navKey) },
            modifier = Modifier.padding(16.dp)
        )
    }
}
