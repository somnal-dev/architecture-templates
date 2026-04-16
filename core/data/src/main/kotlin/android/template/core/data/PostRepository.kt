package android.template.core.data

import android.template.core.network.api.PostApi
import android.template.core.model.Post
import android.template.core.database.LikedPost
import android.template.core.database.LikedPostDao
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import javax.inject.Inject

interface PostRepository {
    val posts: Flow<List<Post>>

    suspend fun toggleLike(postId: Int)
}

class DefaultPostRepository @Inject constructor(
    private val postApi: PostApi,
    private val likedPostDao: LikedPostDao
) : PostRepository {

    override val posts: Flow<List<Post>>
        get() {
            val apiFlow = flow { emit(postApi.getPosts()) }
            return apiFlow.combine(likedPostDao.getAllLikedPosts()) { apiPosts, likedPosts ->
                val likedIds = likedPosts.map { it.postId }.toSet()
                apiPosts.map { post ->
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
