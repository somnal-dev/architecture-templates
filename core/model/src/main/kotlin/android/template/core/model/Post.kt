package android.template.core.model

data class Post(
    val id: Int,
    val userId: Int,
    val title: String,
    val body: String,
    val tags: List<String> = emptyList(),
    val likes: Int = 0,
    val views: Int = 0,
    val isLiked: Boolean = false,
)
