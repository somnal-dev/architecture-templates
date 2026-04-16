# 기능 추가 개발 가이드

이 문서는 이 템플릿 프로젝트에 새로운 기능(화면/도메인)을 추가할 때 따라야 하는 절차를 처음부터 끝까지 설명합니다. 예시로 "댓글(Comment)" 기능을 추가하는 과정을 가정합니다.

---

## 1. 프로젝트 아키텍처 이해하기

이 프로젝트는 **멀티모듈 + 클린 아키텍처** 구조입니다. 의존성은 아래 방향으로만 흐릅니다.

```
feature/xxx/impl  ──▶  feature/xxx/api
       │                      │
       └──────────┬───────────┘
                  ▼
             core/data
                  │
          ┌───────┴────────┐
          ▼                ▼
    core/network      core/database
          │                │
          └──────┬─────────┘
                 ▼
            core/model
```

**모듈별 책임**

| 모듈               | 책임                 | 넣는 것                                |
| ------------------ | -------------------- | -------------------------------------- |
| `core/model`       | 도메인 데이터 클래스 | `Post`, `Comment` 등 순수 data class   |
| `core/network`     | 원격 API 통신        | Retrofit interface, NetworkModule      |
| `core/database`    | 로컬 영속화          | Room Entity/DAO, DatabaseModule        |
| `core/data`        | Repository 계층      | `XxxRepository` interface + Impl       |
| `core/ui`          | 공용 Composable      | 재사용 UI 컴포넌트, Theme              |
| `core/testing`     | 공용 테스트 유틸     | HiltTestRunner, 공용 Fake              |
| `feature/xxx/api`  | 기능 외부 진입점     | `NavigationKeys`, (선택) 외부 노출 API |
| `feature/xxx/impl` | 기능 구현            | ViewModel, Composable, EntryProvider   |
| `app`              | 앱 진입점            | MainActivity, 네비게이션 그래프 조립   |

**중요 원칙**

- `feature/xxx/impl`은 다른 feature의 `impl`을 참조하면 안 됩니다. 다른 feature가 필요하면 그쪽 `api`만 의존합니다.
- `core/data`는 `core/network`와 `core/database`를 조합해 저장소의 단일 진실 원천(single source of truth)을 만듭니다.
- UI에서 바로 `PostApi`를 호출하지 않습니다. 반드시 Repository를 통합니다.

---

## 2. 새 기능 추가: 단계별 체크리스트

### 상황 설정

"Comment" 기능을 추가한다고 가정합니다.

- API: `GET https://jsonplaceholder.typicode.com/comments`
- 화면: 댓글 목록을 보여주는 `CommentScreen`

아래 단계를 순서대로 진행합니다.

---

### 단계 1. 도메인 모델 추가

위치: `core/model/src/main/kotlin/android/template/core/model/Comment.kt`

```kotlin
package android.template.core.model

data class Comment(
    val id: Int,
    val postId: Int,
    val name: String,
    val email: String,
    val body: String
)
```

체크리스트

- [ ] `core/model`에만 둔다 (데이터 클래스는 어느 레이어에서도 접근 가능해야 함).
- [ ] 기본값을 주지 말고 생성자 파라미터로만 정의한다 (누락 시 컴파일러가 잡도록).
- [ ] JSON 필드와 이름이 다르면 Gson annotation 대신 Kotlin 이름을 API 필드와 일치시키거나 `@SerializedName` 사용.

---

### 단계 2. 네트워크 API 추가

위치: `core/network/src/main/kotlin/android/template/core/network/api/CommentApi.kt`

```kotlin
package android.template.core.network.api

import android.template.core.model.Comment
import retrofit2.http.GET
import retrofit2.http.Query

interface CommentApi {
    @GET("comments")
    suspend fun getComments(@Query("postId") postId: Int? = null): List<Comment>
}
```

이어서 `core/network/src/main/kotlin/android/template/core/network/di/NetworkModule.kt`에 provider 추가:

```kotlin
@Provides
@Singleton
fun provideCommentApi(retrofit: Retrofit): CommentApi {
    return retrofit.create(CommentApi::class.java)
}
```

체크리스트

- [ ] 모든 API 메서드는 `suspend`로 선언한다.
- [ ] 파라미터가 있다면 `@Path`, `@Query`, `@Body` 중 적절한 것을 쓴다.
- [ ] Retrofit은 `NetworkModule`에 이미 구성돼 있어 provider만 추가하면 된다 (OkHttp 로깅 포함).

---

### 단계 3. Repository 계층 추가

위치: `core/data/src/main/kotlin/android/template/core/data/CommentRepository.kt`

```kotlin
package android.template.core.data

import android.template.core.model.Comment
import android.template.core.network.api.CommentApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

interface CommentRepository {
    fun commentsForPost(postId: Int): Flow<List<Comment>>
}

class DefaultCommentRepository @Inject constructor(
    private val commentApi: CommentApi
) : CommentRepository {

    override fun commentsForPost(postId: Int): Flow<List<Comment>> = flow {
        emit(commentApi.getComments(postId = postId))
    }
}
```

`core/data/src/main/kotlin/android/template/core/data/di/DataModule.kt`에 바인딩 추가:

```kotlin
@Module
@InstallIn(SingletonComponent::class)
interface DataModule {

    @Singleton
    @Binds
    fun bindsPostRepository(
        postRepository: DefaultPostRepository
    ): PostRepository

    @Singleton
    @Binds
    fun bindsCommentRepository(
        commentRepository: DefaultCommentRepository
    ): CommentRepository
}
```

체크리스트

- [ ] Repository는 반드시 `interface` + `DefaultXxxRepository` 쌍으로 만든다 (테스트에서 Fake 교체용).
- [ ] 네트워크와 DB를 섞어야 한다면 `PostRepository`처럼 `Flow.combine`을 활용한다.
- [ ] Repository는 예외를 삼키지 않는다. UI 레이어에서 `.catch`로 처리한다.
- [ ] `@Binds` 함수는 Repository가 추가될 때마다 `DataModule`에 추가한다.

---

### 단계 4. feature 모듈 생성

`feature/` 아래에 두 개의 Gradle 모듈을 만듭니다: `api`와 `impl`.

#### 4-1. 디렉토리 구조 만들기

```
feature/comment/
├── api/
│   ├── build.gradle.kts
│   └── src/main/kotlin/android/template/feature/comment/api/NavigationKeys.kt
└── impl/
    ├── build.gradle.kts
    └── src/main/kotlin/android/template/feature/comment/
        ├── api/CommentEntryProvider.kt
        └── ui/
            ├── CommentScreen.kt
            └── CommentViewModel.kt
```

#### 4-2. `settings.gradle.kts`에 모듈 등록

```kotlin
include(":feature:comment:api")
include(":feature:comment:impl")
```

#### 4-3. `feature/comment/api/build.gradle.kts`

기존 `feature/post/api/build.gradle.kts`를 참고합니다. 최소 내용:

```kotlin
plugins {
    alias(libs.plugins.template.android.feature.navigation)
}

android {
    namespace = "android.template.feature.comment.api"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}
```

`template.android.feature.navigation` convention plugin이 Navigation3 의존성을 자동으로 포함합니다.

#### 4-4. `feature/comment/impl/build.gradle.kts`

기존 `feature/post/impl/build.gradle.kts`를 템플릿으로 씁니다:

```kotlin
plugins {
    alias(libs.plugins.template.android.feature)
}

android {
    namespace = "android.template.feature.comment"

    defaultConfig {
        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":feature:comment:api"))

    androidTestImplementation(project(":core:testing"))

    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.hilt.lifecycle.viewmodel.compose)

    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    androidTestImplementation(libs.hilt.android.testing)
    kspAndroidTest(libs.hilt.compiler)
    testImplementation(libs.hilt.android.testing)
    kspTest(libs.hilt.compiler)

    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
```

#### 4-5. NavigationKey 정의 (api 모듈)

`feature/comment/api/src/main/kotlin/android/template/feature/comment/api/NavigationKeys.kt`:

```kotlin
package android.template.feature.comment.api

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data class CommentList(val postId: Int) : NavKey
```

체크리스트

- [ ] 네비게이션 인자(`postId`)가 필요하면 `data class`로, 없으면 `data object`로 선언한다.
- [ ] 반드시 `@Serializable`을 붙인다 (Navigation3의 타입 안전성).
- [ ] 외부 모듈(다른 feature, app)은 이 키만 보고 이동한다.

#### 4-6. ViewModel 구현 (impl 모듈)

`feature/comment/impl/src/main/kotlin/android/template/feature/comment/ui/CommentViewModel.kt`:

```kotlin
package android.template.feature.comment.ui

import android.template.core.data.CommentRepository
import android.template.core.model.Comment
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class CommentViewModel @Inject constructor(
    private val commentRepository: CommentRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val postId: Int = checkNotNull(savedStateHandle["postId"])

    val uiState: StateFlow<CommentUiState> = commentRepository
        .commentsForPost(postId)
        .map<List<Comment>, CommentUiState> { CommentUiState.Success(it) }
        .catch { emit(CommentUiState.Error(it)) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CommentUiState.Loading)
}

sealed interface CommentUiState {
    data object Loading : CommentUiState
    data class Error(val throwable: Throwable) : CommentUiState
    data class Success(val data: List<Comment>) : CommentUiState
}
```

체크리스트

- [ ] `@HiltViewModel` + `@Inject constructor` 필수.
- [ ] UI 상태는 하나의 `sealed interface`로 모든 분기를 표현한다.
- [ ] `.catch { }`로 에러를 Error 상태로 바꾼다. 예외를 삼키지 말 것.
- [ ] `SharingStarted.WhileSubscribed(5_000)`로 구독자 이탈 후 5초 유지 (회전 시 재요청 방지).

#### 4-7. Composable 구현

`feature/comment/impl/src/main/kotlin/android/template/feature/comment/ui/CommentScreen.kt`:

```kotlin
package android.template.feature.comment.ui

import android.template.core.model.Comment
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun CommentScreen(
    modifier: Modifier = Modifier,
    viewModel: CommentViewModel = hiltViewModel()
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    CommentContent(state = state, modifier = modifier)
}

@Composable
private fun CommentContent(state: CommentUiState, modifier: Modifier = Modifier) {
    when (state) {
        is CommentUiState.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        is CommentUiState.Error -> Text(
            text = "Error: ${state.throwable.message}",
            modifier = modifier.padding(16.dp)
        )
        is CommentUiState.Success -> LazyColumn(
            modifier = modifier,
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(16.dp)
        ) {
            items(state.data, key = { it.id }) { comment ->
                CommentItem(comment)
            }
        }
    }
}

@Composable
private fun CommentItem(comment: Comment) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(text = comment.name, style = MaterialTheme.typography.titleSmall)
            Text(text = comment.email, style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(4.dp))
            Text(text = comment.body, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
```

체크리스트

- [ ] 공개 Composable은 stateless 버전(`CommentContent`)과 Hilt 연결 버전(`CommentScreen`)을 분리한다. Preview/Test가 쉬워진다.
- [ ] `collectAsStateWithLifecycle()` 사용 (라이프사이클 인지 수집).
- [ ] `LazyColumn`에는 반드시 `key = { ... }`를 지정한다 (성능).
- [ ] `when (state)`는 sealed로 exhaustive하게 작성, `else` 분기 금지.

#### 4-8. EntryProvider 작성

`feature/comment/impl/src/main/kotlin/android/template/feature/comment/api/CommentEntryProvider.kt`:

```kotlin
package android.template.feature.comment.api

import android.template.feature.comment.ui.CommentScreen
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavBackStack
import androidx.navigation3.runtime.NavKey

@Composable
fun EntryProviderScope<NavKey>.CommentEntryProvider(backStack: NavBackStack<NavKey>) {
    entry<CommentList> { key ->
        CommentScreen(modifier = Modifier.padding(16.dp))
    }
}
```

체크리스트

- [ ] EntryProvider는 impl 모듈에 두고, 패키지는 `...feature.comment.api`로 둬 외부에서 호출 시 이름이 깔끔하게 나오게 한다.
- [ ] `entry<CommentList> { key -> ... }`에서 `key`로 `postId`에 접근 가능 (현재는 ViewModel이 `SavedStateHandle`로 받음).

---

### 단계 5. app 모듈에 기능 연결

#### 5-1. `app/build.gradle.kts`에 의존성 추가

```kotlin
dependencies {
    implementation(project(":core:ui"))
    implementation(project(":feature:post:impl"))
    implementation(project(":feature:post:api"))
    implementation(project(":feature:comment:impl"))   // 추가
    implementation(project(":feature:comment:api"))    // 추가
    // ...
}
```

#### 5-2. 네비게이션 그래프에 EntryProvider 등록

`app/src/main/kotlin/android/template/ui/MainActivity.kt` (또는 네비게이션 그래프가 조립되는 파일)에서:

```kotlin
NavDisplay(
    backStack = backStack,
    entryProvider = entryProvider {
        PostEntryProvider(backStack)
        CommentEntryProvider(backStack)   // 추가
    }
)
```

#### 5-3. 다른 화면에서 네비게이션

예: PostScreen에서 아이템 클릭 시 댓글 화면으로 이동

```kotlin
PostScreen(
    onItemClick = { post ->
        backStack.add(CommentList(postId = post.id))
    }
)
```

---

## 3. 모듈 추가 후 빌드 확인

```bash
./gradlew :feature:comment:impl:compileDebugKotlin
./gradlew :app:assembleDebug
```

오류가 나면 대부분은 다음 중 하나입니다.

- `settings.gradle.kts`에 모듈 등록 누락
- `DataModule`에 `@Binds` 추가 누락 → Hilt가 "cannot be provided" 에러를 냄
- NavigationKey에 `@Serializable` 누락 → 런타임 크래시

---

## 4. 작업 순서 권장

새 기능을 개발할 때 아래 순서로 진행하면 막히는 지점이 줄어듭니다.

1. **모델** 정의 (순수 data class, 의존성 없음 → 빠르게 컴파일)
2. **네트워크 API** + `NetworkModule` provider
3. **Repository** interface + Impl + `DataModule` 바인딩
4. **Repository 단위 테스트** 작성 (이 시점이면 UI 없이 데이터 흐름 검증 가능)
5. **ViewModel** + UiState sealed interface
6. **ViewModel 단위 테스트** 작성
7. **Composable** 구현 (stateless → stateful 순서)
8. **Composable UI 테스트** 작성
9. **EntryProvider** + app 모듈 연결
10. **E2E 네비게이션 테스트** 추가

테스트 작성법은 `test-writing-guide.md` 참조.

---

## 5. 네이밍과 코드 스타일 규칙

| 대상            | 규칙                                               | 예시                                            |
| --------------- | -------------------------------------------------- | ----------------------------------------------- |
| 모듈 이름       | 전부 소문자 + 하이픈                               | `feature:user-profile:impl`                     |
| 패키지          | 모듈 경로 매핑                                     | `android.template.feature.userprofile.ui`       |
| Repository      | `XxxRepository` interface + `DefaultXxxRepository` | `CommentRepository`, `DefaultCommentRepository` |
| ViewModel       | `XxxViewModel`                                     | `CommentViewModel`                              |
| UiState         | `XxxUiState` sealed interface                      | `CommentUiState.Loading` 등                     |
| NavigationKey   | 역할을 드러내는 명사                               | `CommentList`, `PostDetail`                     |
| Composable 함수 | PascalCase                                         | `CommentScreen`, `CommentItem`                  |
| 상수            | `SCREAMING_SNAKE_CASE` + `const val`               | `const val MAX_RETRY = 3`                       |

추가 규칙

- `!!` 금지. `?.`, `?:`, `requireNotNull`, `checkNotNull` 사용.
- `var` 최소화. 가능한 모든 값은 `val`로.
- `when`은 sealed 타입에 대해 exhaustive하게 작성하고 `else` 생략.
- 주석은 "왜"만 적는다. "무엇"은 코드가 말하게 한다.

---

## 6. 자주 하는 실수 체크리스트

- [ ] NavigationKey에 `@Serializable` 안 붙이고 네비게이션 → 런타임 크래시
- [ ] Repository를 추가했지만 `DataModule`에 `@Binds` 안 걸어줌 → Hilt 컴파일 에러
- [ ] ViewModel에 `@HiltViewModel` 누락 → `hiltViewModel()` 호출 시 런타임 에러
- [ ] `feature/xxx/impl`이 다른 feature의 `impl`을 참조 → 순환 의존 위험
- [ ] `!!` 사용 → NPE 위험
- [ ] `try/catch`로 예외 삼킴 → 디버깅 불가능
- [ ] `LazyColumn`에 `key` 지정 안 함 → 재구성 성능 저하
- [ ] Composable에서 `viewModel.state.collectAsState()` 사용 (lifecycle 버전 아님) → 백그라운드에서도 수집 계속

---

## 7. 참고 레퍼런스

이 프로젝트 구조는 [nowinandroid](https://github.com/android/nowinandroid) 공식 Android 샘플 앱의 구조를 따릅니다. 추가로 깊이 있는 예시가 필요하면 해당 저장소의 `feature/foryou`, `feature/bookmarks` 등을 참고하세요.
