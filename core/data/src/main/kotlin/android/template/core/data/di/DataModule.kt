package android.template.core.data.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import android.template.core.data.PostRepository
import android.template.core.data.DefaultPostRepository
import android.template.core.model.Post
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
    Post(id = 1, userId = 1, title = "First Post", body = "This is the first post body"),
    Post(id = 2, userId = 1, title = "Second Post", body = "This is the second post body"),
    Post(id = 3, userId = 2, title = "Third Post", body = "This is the third post body")
)
