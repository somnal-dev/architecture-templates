# 기능 추가 개발 가이드

이 문서는 이 템플릿 프로젝트에 새로운 기능(화면/도메인)을 추가할 때 따라야 하는 절차를 처음부터 끝까지 설명합니다. 예시로 **"게시글(Post)"** 기능을 추가하는 과정을 가정합니다.

---

## 1. 프로젝트 아키텍처 이해하기

이 프로젝트는 **멀티모듈 + 클린 아키텍처** 구조입니다. 의존성은 아래 방향으로만 흐릅니다.

```
feature/xxx/impl  ──▶  feature/xxx/api ──▶ core/navigation
       │                      │
       └──────────┬───────────┘
                  ▼
             core/data
                  │
       ┌──────────┼──────────┬────────────┐
       ▼          ▼          ▼            ▼
  core/network core/database core/datastore
       │          │          │
       └──────────┴────┬─────┘
                       ▼
                  core/model
```

**모듈별 책임**

| 모듈               | 책임                 | 넣는 것                                |
| ------------------ | -------------------- | -------------------------------------- |
| `core/model`       | 도메인 데이터 클래스 | `Post`, `User` 등 순수 data class      |
| `core/network`     | 원격 API 통신        | Retrofit interface, NetworkModule      |
| `core/database`    | 로컬 영속화(구조형)  | Room Entity/DAO, DatabaseModule. 상세: [database-development-guide.md](./database-development-guide.md) |
| `core/datastore`   | 사용자 환경설정      | Preferences DataStore, UserPreferencesDataSource. 상세: [datastore-development-guide.md](./datastore-development-guide.md) |
| `core/navigation`  | 네비게이션 진입점    | `Navigator` 클래스 (NavBackStack을 감싼 얇은 래퍼) |
| `core/data`        | Repository 계층      | `XxxRepository` interface + Impl       |
| `core/ui`          | 공용 Composable      | 재사용 UI 컴포넌트, Theme              |
| `core/testing`     | 공용 테스트 유틸     | HiltTestRunner, 공용 Fake              |
| `feature/xxx/api`  | 기능 외부 진입점     | `NavKey` + `Navigator.navigateToXxx()` 확장 |
| `feature/xxx/impl` | 기능 구현            | ViewModel, Composable, Entry           |
| `app`              | 앱 진입점            | MainActivity, Navigator 생성, 네비게이션 그래프 조립 |

**중요 원칙**

- `feature/xxx/impl`은 다른 feature의 `impl`을 참조하면 안 됩니다. 다른 feature가 필요하면 그쪽 `api`만 의존합니다.
- `core/data`는 `core/network`와 `core/database`를 조합해 저장소의 단일 진실 원천(single source of truth)을 만듭니다.
- UI에서 바로 `PostApi`를 호출하지 않습니다. 반드시 Repository를 통합니다.
- 화면 간 이동은 Composable에 `NavKey`를 누출시키지 않습니다. `Navigator` 객체를 받아 `navigator.navigateToXxx()` 확장 함수를 호출합니다 (자세한 건 5-3 참조).

---

## 2. 새 기능 추가: 단계별 체크리스트

### 상황 설정

"Post" 기능을 추가한다고 가정합니다.

- API: `GET https://dummyjson.com/posts` — 게시글 목록
- 화면: 게시글 목록을 보여주는 `PostScreen`
- 응답 형태: `{ "posts": [...], "total", "skip", "limit" }`

아래 단계를 순서대로 진행합니다.

---

### 단계 1. 도메인 모델 추가

위치: `core/model/src/main/kotlin/android/template/core/model/Post.kt`

```kotlin
package android.template.core.model

data class Post(
    val id: Int,
    val title: String,
    val body: String,
    val tags: List<String>,
    val likes: Int,
    val userId: Int,
)
```

체크리스트

- [ ] `core/model`에만 둔다 (데이터 클래스는 어느 레이어에서도 접근 가능해야 함).
- [ ] 서버 응답 구조와 다르더라도 **UI가 쓰기 편한 형태**로 정의한다. 매핑은 Repository에서 한다.
- [ ] 네트워크 DTO(`PostNetwork`)를 별도로 만들고 `toDomain()`으로 변환한다.

---

### 단계 2. 네트워크 DTO + API 추가

#### 2-1. DTO 정의

위치: `core/network/src/main/kotlin/android/template/core/network/api/PostNetwork.kt`

```kotlin
package android.template.core.network.api

import android.template.core.model.Post

data class PostsResponse(
    val posts: List<PostNetwork>,
    val total: Int,
    val skip: Int,
    val limit: Int,
)

data class PostNetwork(
    val id: Int,
    val title: String,
    val body: String,
    val tags: List<String> = emptyList(),
    val reactions: PostReactions = PostReactions(),
    val userId: Int,
) {
    data class PostReactions(
        val likes: Int = 0,
        val dislikes: Int = 0,
    )
}

fun PostNetwork.toDomain(): Post = Post(
    id = id,
    title = title,
    body = body,
    tags = tags,
    likes = reactions.likes,
    userId = userId,
)
```

#### 2-2. Retrofit 인터페이스

위치: `core/network/src/main/kotlin/android/template/core/network/api/PostApi.kt`

```kotlin
package android.template.core.network.api

import retrofit2.http.GET
import retrofit2.http.Query

interface PostApi {
    @GET("posts")
    suspend fun getPosts(
        @Query("limit") limit: Int = 30,
        @Query("skip") skip: Int = 0,
    ): PostsResponse
}
```

이어서 `core/network/src/main/kotlin/android/template/core/network/di/NetworkModule.kt`에 provider 추가:

```kotlin
@Provides
@Singleton
fun providePostApi(retrofit: Retrofit): PostApi {
    return retrofit.create(PostApi::class.java)
}
```

체크리스트

- [ ] 모든 API 메서드는 `suspend`로 선언한다.
- [ ] **도메인 모델(`Post`)을 직접 반환하지 않는다.** DTO(`PostsResponse`)를 반환하고 Repository에서 `toDomain()`으로 변환.
- [ ] Retrofit은 `NetworkModule`에 이미 구성돼 있어 provider만 추가하면 된다 (OkHttp 로깅 포함).

---

### 단계 3. Repository 계층 추가

위치: `core/data/src/main/kotlin/android/template/core/data/PostRepository.kt`

```kotlin
package android.template.core.data

import android.template.core.model.Post
import android.template.core.network.api.PostApi
import android.template.core.network.api.toDomain
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

interface PostRepository {
    fun posts(): Flow<List<Post>>
}

class DefaultPostRepository @Inject constructor(
    private val postApi: PostApi,
) : PostRepository {

    override fun posts(): Flow<List<Post>> = flow {
        val response = postApi.getPosts()
        emit(response.posts.map { it.toDomain() })
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
}
```

체크리스트

- [ ] Repository는 반드시 `interface` + `DefaultXxxRepository` 쌍으로 만든다 (테스트에서 Fake 교체용).
- [ ] Repository는 예외를 삼키지 않는다. UI 레이어에서 `.catch`로 처리한다.
- [ ] `@Binds` 함수는 Repository가 추가될 때마다 `DataModule`에 추가한다.

---

### 단계 4. feature 모듈 생성

`feature/` 아래에 두 개의 Gradle 모듈을 만듭니다: `api`와 `impl`.

#### scaffold 스크립트 사용 (권장)

```bash
yarn new
```

대화형으로 이름(`post`)과 레이어를 선택하면 파일 및 `settings.gradle.kts` 등록까지 자동으로 처리됩니다.

#### 수동으로 직접 생성

```bash
# api 모듈
mkdir -p feature/post/api/src/main/kotlin/android/template/feature/post/navigation

# impl 모듈
mkdir -p feature/post/impl/src/main/kotlin/android/template/feature/post/ui
mkdir -p feature/post/impl/src/main/kotlin/android/template/feature/post/navigation
mkdir -p feature/post/impl/src/test/kotlin/android/template/feature/post/ui
mkdir -p feature/post/impl/src/androidTest/kotlin/android/template/feature/post/ui
```

#### 최종 디렉토리 구조

```
feature/post/
├── api/
│   ├── build.gradle.kts
│   └── src/main/kotlin/android/template/feature/post/navigation/PostNavKey.kt
└── impl/
    ├── build.gradle.kts
    └── src/main/kotlin/android/template/feature/post/
        ├── navigation/PostNavigation.kt
        └── ui/
            ├── PostScreen.kt
            └── PostViewModel.kt
```

#### 4-1. `settings.gradle.kts`에 모듈 등록

```kotlin
include(":feature:post:api")
include(":feature:post:impl")
```

#### 4-2. `feature/post/api/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.template.android.feature.navigation)
}

android {
    namespace = "android.template.feature.post.api"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    api(projects.core.navigation)
}
```

#### 4-3. `feature/post/impl/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.template.android.feature)
}

android {
    namespace = "android.template.feature.post"

    defaultConfig {
        testInstrumentationRunner = "android.template.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    implementation(projects.core.data)
    implementation(projects.core.ui)
    implementation(projects.core.navigation)
    implementation(projects.feature.post.api)

    androidTestImplementation(projects.core.testing)

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

#### 4-4. NavKey + Navigator 진입 헬퍼 (api 모듈)

`feature/post/api/src/main/kotlin/android/template/feature/post/navigation/PostNavKey.kt`:

```kotlin
package android.template.feature.post.navigation

import android.template.core.navigation.Navigator
import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object PostNavKey : NavKey

fun Navigator.navigateToPost() {
    navigate(PostNavKey)
}
```

> 네비게이션 인자가 필요하면 `data object` 대신 `data class`로 선언합니다.
> 예: `data class PostNavKey(val postId: Int) : NavKey`

체크리스트

- [ ] 반드시 `@Serializable`을 붙인다 (Navigation3의 타입 안전성).
- [ ] 외부 모듈은 `Navigator.navigateToPost()` 확장만 사용한다. `NavKey` 자체는 노출되어 있어도 직접 호출하지 않는다.
- [ ] 이 확장 함수가 이 feature의 **공개 진입 규약**이다.

#### 4-5. ViewModel 구현 (impl 모듈)

`feature/post/impl/src/main/kotlin/android/template/feature/post/ui/PostViewModel.kt`:

```kotlin
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
import javax.inject.Inject

@HiltViewModel
class PostViewModel @Inject constructor(
    private val postRepository: PostRepository,
) : ViewModel() {

    val uiState: StateFlow<PostUiState> = postRepository
        .posts()
        .map<List<Post>, PostUiState> { PostUiState.Success(it) }
        .catch { emit(PostUiState.Error(it)) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), PostUiState.Loading)
}

sealed interface PostUiState {
    data object Loading : PostUiState
    data class Error(val throwable: Throwable) : PostUiState
    data class Success(val data: List<Post>) : PostUiState
}
```

체크리스트

- [ ] `@HiltViewModel` + `@Inject constructor` 필수.
- [ ] UI 상태는 하나의 `sealed interface`로 모든 분기를 표현한다.
- [ ] `.catch { }`로 에러를 Error 상태로 바꾼다. 예외를 삼키지 말 것.
- [ ] `SharingStarted.WhileSubscribed(5_000)`로 구독자 이탈 후 5초 유지 (화면 회전 시 재요청 방지).

#### 4-6. Composable 구현

`feature/post/impl/src/main/kotlin/android/template/feature/post/ui/PostScreen.kt`:

```kotlin
package android.template.feature.post.ui

import android.template.core.model.Post
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun PostScreen(
    modifier: Modifier = Modifier,
    viewModel: PostViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    PostContent(state = uiState, modifier = modifier)
}

@Composable
private fun PostContent(
    state: PostUiState,
    modifier: Modifier = Modifier,
) {
    when (state) {
        is PostUiState.Loading -> {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is PostUiState.Error -> {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "Error: ${state.throwable.message}")
            }
        }
        is PostUiState.Success -> {
            LazyColumn(
                modifier = modifier,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(16.dp),
            ) {
                items(state.data, key = { it.id }) { post ->
                    PostItem(post)
                }
            }
        }
    }
}

@Composable
private fun PostItem(
    post: Post,
    modifier: Modifier = Modifier,
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(text = post.title, style = MaterialTheme.typography.titleSmall)
            Text(
                text = post.body,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
            )
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(text = post.tags.joinToString(" ") { "#$it" }, style = MaterialTheme.typography.labelSmall)
                Text(text = "♥ ${post.likes}", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}
```

체크리스트

- [ ] 공개 Composable은 stateless(`PostContent`)와 Hilt 연결(`PostScreen`)을 분리한다. Preview/Test가 쉬워진다.
- [ ] **Screen은 `NavKey`·`Navigator`·`NavBackStack`을 받지 않는다.** 원시 콜백만 받는다.
- [ ] `collectAsStateWithLifecycle()` 사용 (라이프사이클 인지 수집).
- [ ] `LazyColumn`에는 반드시 `key = { ... }`를 지정한다 (성능).
- [ ] `when (state)`는 sealed로 exhaustive하게 작성, `else` 분기 금지.

#### 4-7. Entry 작성

`feature/post/impl/src/main/kotlin/android/template/feature/post/navigation/PostNavigation.kt`:

```kotlin
package android.template.feature.post.navigation

import android.template.core.navigation.Navigator
import android.template.feature.post.ui.PostScreen
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey

@Composable
fun EntryProviderScope<NavKey>.PostEntry(navigator: Navigator) {
    entry<PostNavKey> {
        PostScreen(
            modifier = Modifier.padding(16.dp),
        )
    }
}
```

체크리스트

- [ ] Entry는 impl 모듈에 두고, 패키지는 `...feature.post.navigation`으로 맞춘다.
- [ ] Entry 함수명은 **PascalCase** (`PostEntry`). `@Composable` 함수 네이밍 규칙.
- [ ] Entry는 **`Navigator` 하나만** 받는다 (`NavBackStack`을 직접 받지 않는다).
- [ ] Screen은 Entry에서 `navigator::back`, `{ id -> navigator.navigateToXxx(id) }` 같은 람다로 엮는다.

---

### 단계 5. app 모듈에 기능 연결

#### 5-1. `app/build.gradle.kts`에 의존성 추가

```kotlin
dependencies {
    implementation(projects.core.ui)
    implementation(projects.core.navigation)
    implementation(projects.feature.post.impl)
    implementation(projects.feature.post.api)
    // ...
}
```

#### 5-2. 네비게이션 그래프 조립

`app/src/main/kotlin/android/template/ui/Navigation.kt`:

```kotlin
@Composable
fun MainNavigation() {
    val backStack = rememberNavBackStack(PostNavKey)
    val navigator = remember(backStack) { Navigator(backStack) }

    NavDisplay(
        backStack = backStack,
        onBack = { navigator.back() },
        entryDecorators = listOf(
            rememberSaveableStateHolderNavEntryDecorator(),
            rememberViewModelStoreNavEntryDecorator()
        ),
        entryProvider = entryProvider {
            PostEntry(navigator = navigator)
        }
    )
}
```

체크리스트

- [ ] `Navigator`는 `remember(backStack)`로 한 번만 만든다.
- [ ] `NavDisplay.onBack`도 `navigator.back()`으로 통일한다.
- [ ] **`app` 모듈이 `NavBackStack`을 다루는 유일한 곳.**

#### 5-3. Feature 간 네비게이션 — `navigator.navigateToXxx(...)`

예: `PostScreen`에서 아이템을 탭하면 `PostDetailScreen`으로 이동하는 경우.

**① `feature/post-detail/api`가 진입 규약을 노출한다**

```kotlin
@Serializable
data class PostDetailNavKey(val postId: Int) : NavKey

fun Navigator.navigateToPostDetail(postId: Int) {
    navigate(PostDetailNavKey(postId))
}
```

**② `PostScreen`은 `NavKey`·`Navigator`를 모른다 — 원시 콜백만 받는다**

```kotlin
@Composable
fun PostScreen(
    onPostClick: (Int) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: PostViewModel = hiltViewModel(),
) { /* ... */ }
```

**③ `PostEntry`에서 `feature:post-detail:api`의 확장으로 엮는다**

```kotlin
// feature/post/impl/build.gradle.kts
dependencies {
    implementation(projects.feature.postDetail.api)  // api만 추가
}

// PostNavigation.kt
@Composable
fun EntryProviderScope<NavKey>.PostEntry(navigator: Navigator) {
    entry<PostNavKey> {
        PostScreen(
            onPostClick = navigator::navigateToPostDetail,
            modifier = Modifier.padding(16.dp),
        )
    }
}
```

**왜 이렇게 하나 (Typed Navigator의 이점)**

- **Screen이 재사용 가능** — `PostScreen`은 `NavKey`·`Navigator`를 모른다. Preview/테스트/다른 앱에서 콜백만 갈아끼우면 된다.
- **진입 규약이 타입으로 강제** — `navigateToPostDetail(postId: Int)`의 시그니처가 바뀌면 호출자 모두 컴파일이 깨진다.
- **`app`만 `NavBackStack`을 안다** — feature들은 `Navigator` 추상만 본다.

체크리스트

- [ ] 상대 feature의 **api만** `implementation` — `impl` 의존은 절대 금지.
- [ ] Screen 시그니처는 `NavKey`·`Navigator` 대신 **원시 콜백**으로 둔다.
- [ ] `navigateToXxx(...)` 확장은 상대 feature의 **api**에 둔다.
- [ ] 두 feature가 서로의 api를 참조해야 한다면 설계 문제일 가능성이 높다 → `core/model`이나 중재자 추출 검토.

---

## 3. 모듈 추가 후 빌드 확인

```bash
./gradlew :feature:post:impl:compileDebugKotlin
./gradlew :app:assembleDebug
```

오류가 나면 대부분은 다음 중 하나입니다.

- `settings.gradle.kts`에 모듈 등록 누락
- `DataModule`에 `@Binds` 추가 누락 → Hilt가 "cannot be provided" 에러를 냄
- `NavKey`에 `@Serializable` 누락 → 런타임 크래시

---

## 4. 작업 순서 권장

새 기능을 개발할 때 아래 순서로 진행하면 막히는 지점이 줄어듭니다.

1. **모델** 정의 (순수 data class, 의존성 없음 → 빠르게 컴파일)
2. **네트워크 API** + `NetworkModule` provider
3. **Repository** interface + Impl + `DataModule` 바인딩
4. **Repository 단위 테스트** 작성
5. **ViewModel** + UiState sealed interface
6. **ViewModel 단위 테스트** 작성
7. **Composable** 구현 (stateless → stateful 순서)
8. **Composable UI 테스트** 작성
9. **EntryProvider** + app 모듈 연결
10. **E2E 네비게이션 테스트** 추가

테스트 작성법은 `test-writing-guide.md` 참조.

---

## 5. 네이밍과 코드 스타일 규칙

| 대상            | 규칙                                               | 예시                                        |
| --------------- | -------------------------------------------------- | ------------------------------------------- |
| 모듈 이름       | 전부 소문자 + 하이픈                               | `feature:user-profile:impl`                 |
| 패키지          | 모듈 경로 매핑                                     | `android.template.feature.userprofile.ui`   |
| Repository      | `XxxRepository` interface + `DefaultXxxRepository` | `PostRepository`, `DefaultPostRepository`   |
| ViewModel       | `XxxViewModel`                                     | `PostViewModel`                             |
| UiState         | `XxxUiState` sealed interface                      | `PostUiState.Loading` 등                    |
| NavKey          | 역할을 드러내는 명사                               | `PostNavKey`, `PostDetailNavKey`            |
| Composable 함수 | PascalCase                                         | `PostScreen`, `PostItem`                    |
| 상수            | `SCREAMING_SNAKE_CASE` + `const val`               | `const val MAX_RETRY = 3`                   |

추가 규칙

- `!!` 금지. `?.`, `?:`, `requireNotNull`, `checkNotNull` 사용.
- `var` 최소화. 가능한 모든 값은 `val`로.
- `when`은 sealed 타입에 대해 exhaustive하게 작성하고 `else` 생략.
- 주석은 "왜"만 적는다. "무엇"은 코드가 말하게 한다.

---

## 6. 자주 하는 실수 체크리스트

- [ ] NavKey에 `@Serializable` 안 붙이고 네비게이션 → 런타임 크래시
- [ ] Repository를 추가했지만 `DataModule`에 `@Binds` 안 걸어줌 → Hilt 컴파일 에러
- [ ] ViewModel에 `@HiltViewModel` 누락 → `hiltViewModel()` 호출 시 런타임 에러
- [ ] `feature/xxx/impl`이 다른 feature의 `impl`을 참조 → 순환 의존 위험
- [ ] Screen에 `NavKey`/`Navigator`를 직접 주입 → Preview/테스트 불가. 원시 콜백으로 바꿀 것.
- [ ] `Navigator`를 `remember` 없이 만들기 → 매 재구성마다 새 인스턴스 생성
- [ ] `navigateToXxx` 확장을 `impl`에 두기 → 호출자가 `impl`에 의존해야 함 (규약 위반)
- [ ] `!!` 사용 → NPE 위험
- [ ] `try/catch`로 예외 삼킴 → 디버깅 불가능
- [ ] `LazyColumn`에 `key` 지정 안 함 → 재구성 성능 저하
- [ ] `viewModel.state.collectAsState()` 사용 (lifecycle 버전 아님) → 백그라운드에서도 수집 계속

---

## 7. 참고 레퍼런스

- [nowinandroid](https://github.com/android/nowinandroid) — 이 프로젝트의 모듈 구조·DI·네비게이션 패턴의 원본.
- [dummyjson.com/docs](https://dummyjson.com/docs) — 이 템플릿에서 사용하는 REST API. [posts](https://dummyjson.com/docs/posts), [auth](https://dummyjson.com/docs/auth) 참조.
- [auth-development-guide.md](./auth-development-guide.md) — 로그인·토큰 저장·자동 갱신 구현 가이드.
