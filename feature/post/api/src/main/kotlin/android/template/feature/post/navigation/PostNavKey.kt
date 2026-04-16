package android.template.feature.post.navigation

import android.template.core.navigation.Navigator
import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object PostNavKey : NavKey

/**
 * 다른 feature에서 post 화면으로 이동할 때 호출하는 진입점.
 * 호출부는 `PostNavKey`의 존재를 알 필요 없이 `navigator.navigateToPost()`만 쓰면 된다.
 */
fun Navigator.navigateToPost() {
    navigate(PostNavKey)
}
