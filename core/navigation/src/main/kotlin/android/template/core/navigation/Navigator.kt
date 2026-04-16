package android.template.core.navigation

import androidx.navigation3.runtime.NavBackStack
import androidx.navigation3.runtime.NavKey

/**
 * 앱 전역에서 공유되는 네비게이션 진입점.
 *
 * 각 feature의 `api` 모듈은 이 Navigator를 수신자로 하는 확장 함수로
 * "나로 가는 길"(예: `Navigator.navigateToComment(postId)`)을 노출한다.
 * 그래서 feature/impl은 상대 feature의 NavKey 내부 구조를 몰라도 된다.
 */
class Navigator(val backStack: NavBackStack<NavKey>) {

    fun navigate(key: NavKey) {
        backStack.add(key)
    }

    fun back() {
        backStack.removeLastOrNull()
    }
}
