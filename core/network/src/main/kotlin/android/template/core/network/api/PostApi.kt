package android.template.core.network.api

import android.template.core.model.Post
import retrofit2.http.GET
import retrofit2.http.Path

interface PostApi {
    @GET("posts")
    suspend fun getPosts(): List<Post>

    @GET("posts/{id}")
    suspend fun getPost(@Path("id") id: Int): Post
}
