package android.template.data

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import android.template.core.data.DefaultPostRepository
import android.template.core.network.api.PostApi
import android.template.core.model.Post
import android.template.core.database.LikedPost
import android.template.core.database.LikedPostDao

/**
 * Unit tests for [DefaultPostRepository].
 */
@OptIn(ExperimentalCoroutinesApi::class) // TODO: Remove when stable
class DefaultPostRepositoryTest {

    @Test
    fun posts_areFetchedFromApi() = runTest {
        val repository = DefaultPostRepository(FakePostApi(), FakeLikedPostDao())

        val posts = repository.posts.first()

        assertEquals(2, posts.size)
        assertEquals("Test Title 1", posts[0].title)
    }
}

private class FakePostApi : PostApi {
    override suspend fun getPosts(): List<Post> = listOf(
        Post(id = 1, userId = 1, title = "Test Title 1", body = "Test Body 1"),
        Post(id = 2, userId = 1, title = "Test Title 2", body = "Test Body 2")
    )

    override suspend fun getPost(id: Int): Post =
        Post(id = id, userId = 1, title = "Test Title $id", body = "Test Body $id")
}

private class FakeLikedPostDao : LikedPostDao {
    private val data = mutableListOf<LikedPost>()

    override fun getAllLikedPosts(): Flow<List<LikedPost>> = flow {
        emit(data.toList())
    }

    override fun isPostLiked(postId: Int): Flow<Boolean> = flow {
        emit(data.any { it.postId == postId })
    }

    override suspend fun insertLikedPost(likedPost: LikedPost) {
        data.add(likedPost)
    }

    override suspend fun deleteLikedPost(postId: Int) {
        data.removeAll { it.postId == postId }
    }
}
