package android.template.core.data.di

import android.template.core.data.DefaultPostRepository
import android.template.core.data.PostRepository
import android.template.core.model.Post
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import javax.inject.Inject
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
interface DataModule {

    @Singleton
    @Binds
    fun bindsPostRepository(
        postRepository: DefaultPostRepository
    ): PostRepository
}

class FakePostRepository @Inject constructor() : PostRepository {
    override val posts: Flow<List<Post>> = flowOf(fakePosts)

    override suspend fun toggleLike(postId: Int) {
        throw NotImplementedError()
    }
}

val fakePosts = listOf(
    Post(
        id = 1,
        userId = 121,
        title = "His mother had always taught him",
        body = "His mother had always taught him not to ever think of himself as better than others.",
        tags = listOf("history", "american", "crime"),
        likes = 192,
        views = 305,
    ),
    Post(
        id = 2,
        userId = 91,
        title = "He was an expert but not in a discipline",
        body = "He was an expert but not in a discipline that anyone could fully appreciate.",
        tags = listOf("french", "fiction", "english"),
        likes = 859,
        views = 4884,
    ),
    Post(
        id = 3,
        userId = 60,
        title = "Dave watched as the forest burned up on the hill",
        body = "Dave watched as the forest burned up on the hill, only a few miles from her house.",
        tags = listOf("magical", "crime"),
        likes = 1437,
        views = 8218,
    ),
)
