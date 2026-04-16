package android.template.feature.post.ui.post


import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import android.template.core.data.PostRepository
import android.template.core.model.Post
import android.template.feature.post.ui.PostUiState
import android.template.feature.post.ui.PostViewModel

/**
 * Example local unit test, which will execute on the development machine (host).
 *
 * See [testing documentation](http://d.android.com/tools/testing).
 */
@OptIn(ExperimentalCoroutinesApi::class) // TODO: Remove when stable
class PostViewModelTest {
    @Test
    fun uiState_initiallyLoading() = runTest {
        val viewModel = PostViewModel(FakePostRepository())
        assertEquals(viewModel.uiState.first(), PostUiState.Loading)
    }

    @Test
    fun uiState_onItemSaved_isDisplayed() = runTest {
        val viewModel = PostViewModel(FakePostRepository())
        assertEquals(viewModel.uiState.first(), PostUiState.Loading)
    }
}

private class FakePostRepository : PostRepository {

    private val data = mutableListOf(
        Post(id = 1, userId = 1, title = "Test", body = "Test body")
    )

    override val posts: Flow<List<Post>>
        get() = flow { emit(data.toList()) }

    override suspend fun toggleLike(postId: Int) {
        val index = data.indexOfFirst { it.id == postId }
        if (index >= 0) {
            data[index] = data[index].copy(isLiked = !data[index].isLiked)
        }
    }
}
