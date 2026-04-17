package android.template.core.network.api

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * https://dummyjson.com/docs/posts
 *
 * 목록 응답은 `PostsResponse`로 래핑돼 있고(`posts`, `total`, `skip`, `limit`),
 * 단건 조회는 `PostNetwork`를 그대로 반환한다.
 */
interface PostApi {
    @GET("posts")
    suspend fun getPosts(
        @Query("limit") limit: Int = 30,
        @Query("skip") skip: Int = 0,
    ): PostsResponse

    @GET("posts/{id}")
    suspend fun getPost(@Path("id") id: Int): PostNetwork
}
