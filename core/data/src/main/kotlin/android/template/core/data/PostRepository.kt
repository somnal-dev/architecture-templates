package android.template.core.data

import android.template.core.database.LikedPost
import android.template.core.database.LikedPostDao
import android.template.core.model.Post
import android.template.core.network.api.PostApi
import android.template.core.network.api.toDomain
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

interface PostRepository {
    val posts: Flow<List<Post>>

    suspend fun toggleLike(postId: Int)
}

class DefaultPostRepository @Inject constructor(
    private val postApi: PostApi,
    private val likedPostDao: LikedPostDao,
) : PostRepository {

    override val posts: Flow<List<Post>>
        get() {
            val apiFlow = flow {
                val response = postApi.getPosts()
                emit(response.posts.map { it.toDomain() })
            }
            return apiFlow.combine(likedPostDao.getAllLikedPosts()) { posts, likedPosts ->
                val likedIds = likedPosts.map { it.postId }.toSet()
                posts.map { post ->
                    post.copy(isLiked = likedIds.contains(post.id))
                }
            }
        }

    override suspend fun toggleLike(postId: Int) {
        val isLiked = likedPostDao.isPostLiked(postId).first()
        if (isLiked) {
            likedPostDao.deleteLikedPost(postId)
        } else {
            likedPostDao.insertLikedPost(LikedPost(postId = postId))
        }
    }
}
