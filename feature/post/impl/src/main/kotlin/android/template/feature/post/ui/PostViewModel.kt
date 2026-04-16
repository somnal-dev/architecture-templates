package android.template.feature.post.ui

import android.template.core.data.PostRepository
import android.template.core.model.Post
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import android.template.feature.post.ui.PostUiState.Error
import android.template.feature.post.ui.PostUiState.Loading
import android.template.feature.post.ui.PostUiState.Success
import javax.inject.Inject

@HiltViewModel
class PostViewModel @Inject constructor(
    private val postRepository: PostRepository
) : ViewModel() {

    val uiState: StateFlow<PostUiState> = postRepository
        .posts.map<List<Post>, PostUiState> { Success(data = it) }
        .catch { emit(Error(it)) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), Loading)

    fun toggleLike(postId: Int) {
        viewModelScope.launch {
            postRepository.toggleLike(postId)
        }
    }
}

sealed interface PostUiState {
    object Loading : PostUiState
    data class Error(val throwable: Throwable) : PostUiState
    data class Success(val data: List<Post>) : PostUiState
}
