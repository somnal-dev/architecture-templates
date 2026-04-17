package android.template.core.network.api

import android.template.core.model.Post

/**
 * dummyjson.com `/posts` 응답 스키마.
 *
 * 외부 API 스키마는 도메인 모델과 분리해 둔다. 이렇게 해야:
 *  - API가 필드를 바꿔도 `core/model`이 흔들리지 않는다.
 *  - Repository에서 `.toDomain()`으로 명시적으로 변환되어 경계가 눈에 보인다.
 *  - UI 레이어에 `reactions.likes` 같은 서버측 구조가 누출되지 않는다.
 */
data class PostsResponse(
    val posts: List<PostNetwork>,
    val total: Int,
    val skip: Int,
    val limit: Int,
)

data class PostNetwork(
    val id: Int,
    val userId: Int,
    val title: String,
    val body: String,
    val tags: List<String> = emptyList(),
    val reactions: Reactions = Reactions(),
    val views: Int = 0,
) {
    data class Reactions(
        val likes: Int = 0,
        val dislikes: Int = 0,
    )
}

fun PostNetwork.toDomain(): Post = Post(
    id = id,
    userId = userId,
    title = title,
    body = body,
    tags = tags,
    likes = reactions.likes,
    views = views,
)
