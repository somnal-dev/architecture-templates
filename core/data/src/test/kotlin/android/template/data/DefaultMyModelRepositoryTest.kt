package android.template.data

import android.template.core.data.DefaultPostRepository
import android.template.core.database.LikedPost
import android.template.core.database.LikedPostDao
import android.template.core.network.api.PostApi
import android.template.core.network.api.PostNetwork
import android.template.core.network.api.PostsResponse
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for [DefaultPostRepository].
 */
@OptIn(ExperimentalCoroutinesApi::class) // TODO: Remove when stable
class DefaultPostRepositoryTest {

    @Test
    fun posts_areFetchedFromApi_andMappedToDomain() = runTest {
        val repository = DefaultPostRepository(FakePostApi(), FakeLikedPostDao())

        val posts = repository.posts.first()

        assertEquals(2, posts.size)
        assertEquals("Test Title 1", posts[0].title)
        assertEquals(10, posts[0].likes)        // mapped from reactions.likes
        assertEquals(listOf("a", "b"), posts[0].tags)
    }
}

private class FakePostApi : PostApi {
    override suspend fun getPosts(limit: Int, skip: Int): PostsResponse = PostsResponse(
        posts = listOf(
            PostNetwork(
                id = 1,
                userId = 1,
                title = "Test Title 1",
                body = "Test Body 1",
                tags = listOf("a", "b"),
                reactions = PostNetwork.Reactions(likes = 10, dislikes = 1),
                views = 100,
            ),
            PostNetwork(
                id = 2,
                userId = 1,
                title = "Test Title 2",
                body = "Test Body 2",
                tags = listOf("c"),
                reactions = PostNetwork.Reactions(likes = 20, dislikes = 0),
                views = 200,
            ),
        ),
        total = 2,
        skip = 0,
        limit = limit,
    )

    override suspend fun getPost(id: Int): PostNetwork = PostNetwork(
        id = id,
        userId = 1,
        title = "Test Title $id",
        body = "Test Body $id",
    )
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
