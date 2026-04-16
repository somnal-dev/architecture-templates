package android.template.feature.post.ui

import android.template.core.model.Post
import android.template.core.ui.MyApplicationTheme
import android.template.feature.post.ui.PostUiState.Success
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation3.runtime.NavKey

@Composable
fun PostScreen(
    onItemClick: (NavKey) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PostViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    when (uiState) {
        is Success -> {
            PostContent(
                posts = (uiState as Success).data,
                onToggleLike = viewModel::toggleLike,
                modifier = modifier
            )
        }
        is PostUiState.Loading -> {
            Box(
                modifier = modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                androidx.compose.material3.CircularProgressIndicator()
            }
        }
        is PostUiState.Error -> {
            Box(
                modifier = modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(text = "Error: ${(uiState as PostUiState.Error).throwable.message}")
            }
        }
    }
}

@Composable
private fun PostContent(
    posts: List<Post>,
    onToggleLike: (postId: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.safeDrawingPadding(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(posts, key = { it.id }) { post ->
            PostItem(
                post = post,
                onToggleLike = { onToggleLike(post.id) }
            )
        }
    }
}

@Composable
private fun PostItem(
    post: Post,
    onToggleLike: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = post.title,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onToggleLike) {
                    Icon(
                        imageVector = if (post.isLiked) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                        contentDescription = if (post.isLiked) "Unlike" else "Like",
                        tint = if (post.isLiked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = post.body,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

// Previews

@Preview(showBackground = true)
@Composable
private fun DefaultPreview() {
    MyApplicationTheme {
        PostContent(
            posts = listOf(
                Post(1, 1, "First Post Title", "This is the body of the first post", isLiked = true),
                Post(2, 1, "Second Post Title", "This is the body of the second post"),
                Post(3, 2, "Third Post Title", "This is the body of the third post")
            ),
            onToggleLike = {}
        )
    }
}

@Preview(showBackground = true, widthDp = 340)
@Composable
private fun PortraitPreview() {
    MyApplicationTheme {
        PostContent(
            posts = listOf(
                Post(1, 1, "First Post Title", "This is the body of the first post", isLiked = true),
                Post(2, 1, "Second Post Title", "This is the body of the second post")
            ),
            onToggleLike = {}
        )
    }
}
