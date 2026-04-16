# 테스트 코드 작성 가이드

이 문서는 이 프로젝트에서 테스트 코드를 어느 위치에, 어떤 방식으로 작성해야 하는지 단계별로 설명합니다. 처음부터 따라 하면 되도록 실제 예제 코드를 포함합니다.

---

## 1. 테스트 전략 개요

이 프로젝트는 세 종류의 테스트를 서로 다른 위치에 둡니다. 용도를 먼저 이해하세요.

| 테스트 종류 | 위치 | 실행 환경 | 대표 대상 | 실행 속도 |
|---|---|---|---|---|
| JVM 단위 테스트 | `module/src/test/kotlin/...` | 로컬 JVM | ViewModel, Repository, 유틸 | 빠름 (초 단위) |
| Compose UI 테스트 | `feature/xxx/impl/src/androidTest/...` | 에뮬레이터/실기기 | 개별 Composable 화면 | 중간 |
| E2E 네비게이션 테스트 | `app/src/androidTest/...` | 에뮬레이터/실기기 | 앱 전체 플로우, 네비게이션 | 느림 |

**원칙**
- 가능한 한 **JVM 단위 테스트**로 커버한다. 빠르고 디버깅 쉽다.
- Composable의 화면 로직은 **개별 UI 테스트**로 검증한다.
- 앱 전체 시나리오(화면 A → B → C)는 **E2E 테스트**로 소수만 유지한다.
- 테스트가 느려지면 대부분의 원인은 UI 테스트를 과하게 쓴 것. 로직은 ViewModel 테스트로 내린다.

---

## 2. 공통 준비 사항

### 2-1. 관련 모듈

- `core/testing` — 테스트 공용 유틸, `HiltTestRunner`가 들어있는 모듈.
- `ui-test-hilt-manifest` — Hilt를 쓰는 Composable을 격리 테스트할 때 Host가 되는 빈 액티비티를 제공.

### 2-2. build.gradle.kts에 의존성 (feature/xxx/impl 기준)

이 템플릿의 convention plugin이 대부분 자동 설정하지만, 필요한 라이브러리가 누락되면 다음을 추가합니다.

```kotlin
dependencies {
    // JVM 테스트
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)

    // Hilt 테스트 (JVM/AndroidTest 양쪽)
    testImplementation(libs.hilt.android.testing)
    kspTest(libs.hilt.compiler)
    androidTestImplementation(libs.hilt.android.testing)
    kspAndroidTest(libs.hilt.compiler)

    // Compose UI 테스트
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // 공용 Fake
    androidTestImplementation(project(":core:testing"))
}
```

---

## 3. JVM 단위 테스트 작성 (Repository)

### 3-1. 위치 규칙

Repository는 `core/data` 모듈에 있으므로 테스트는 `core/data/src/test/kotlin/...`에 둡니다.

```
core/data/src/test/kotlin/android/template/data/DefaultCommentRepositoryTest.kt
```

### 3-2. 작성 예시

`PostRepository`의 기존 테스트(`DefaultMyModelRepositoryTest.kt`)가 좋은 레퍼런스입니다. `CommentRepository` 기준으로 다음처럼 작성합니다.

```kotlin
package android.template.data

import android.template.core.data.DefaultCommentRepository
import android.template.core.model.Comment
import android.template.core.network.api.CommentApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class DefaultCommentRepositoryTest {

    @Test
    fun commentsForPost_returnsDataFromApi() = runTest {
        val repository = DefaultCommentRepository(FakeCommentApi())

        val comments = repository.commentsForPost(postId = 1).first()

        assertEquals(2, comments.size)
        assertEquals("첫 번째 댓글", comments[0].name)
    }
}

private class FakeCommentApi : CommentApi {
    override suspend fun getComments(postId: Int?): List<Comment> = listOf(
        Comment(id = 1, postId = 1, name = "첫 번째 댓글", email = "a@a.com", body = "body1"),
        Comment(id = 2, postId = 1, name = "두 번째 댓글", email = "b@b.com", body = "body2")
    )
}
```

### 3-3. 작성 요령

- **Mock 대신 Fake를 쓴다.** 실제 interface를 구현한 private 클래스로 만드는 편이 유지보수하기 쉽고 리팩터링에 강하다.
- **`runTest { ... }`**로 감싸 코루틴을 동기적으로 실행한다.
- **Flow 검증**은 `.first()`, `.toList()` 같은 terminal operator로 값을 꺼내서 확인한다.
- **에러 경로**도 반드시 테스트한다. Fake에 예외를 던지게 해두고 Repository가 어떻게 전파하는지 검증.

```kotlin
@Test
fun commentsForPost_propagatesApiError() = runTest {
    val repository = DefaultCommentRepository(FailingApi())

    assertFailsWith<IllegalStateException> {
        repository.commentsForPost(postId = 1).first()
    }
}

private class FailingApi : CommentApi {
    override suspend fun getComments(postId: Int?): List<Comment> =
        error("network down")
}
```

### 3-4. 실행

```bash
./gradlew :core:data:test
```

특정 테스트만 실행:

```bash
./gradlew :core:data:test --tests "android.template.data.DefaultCommentRepositoryTest.commentsForPost_returnsDataFromApi"
```

---

## 4. JVM 단위 테스트 작성 (ViewModel)

### 4-1. 위치 규칙

ViewModel은 `feature/xxx/impl` 모듈의 `src/test/kotlin/...`에 둡니다.

```
feature/comment/impl/src/test/kotlin/android/template/feature/comment/ui/CommentViewModelTest.kt
```

### 4-2. 작성 예시

```kotlin
package android.template.feature.comment.ui

import android.template.core.data.CommentRepository
import android.template.core.model.Comment
import androidx.lifecycle.SavedStateHandle
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CommentViewModelTest {

    @Test
    fun uiState_initiallyLoading() = runTest {
        val viewModel = CommentViewModel(
            commentRepository = FakeCommentRepository(),
            savedStateHandle = SavedStateHandle(mapOf("postId" to 1))
        )

        assertEquals(CommentUiState.Loading, viewModel.uiState.value)
    }

    @Test
    fun uiState_emitsSuccess_whenRepositoryReturnsData() = runTest {
        val fakeRepo = FakeCommentRepository().apply {
            emit(listOf(Comment(1, 1, "name", "a@a.com", "body")))
        }

        val viewModel = CommentViewModel(
            commentRepository = fakeRepo,
            savedStateHandle = SavedStateHandle(mapOf("postId" to 1))
        )

        val state = viewModel.uiState.first { it is CommentUiState.Success }
        assertTrue(state is CommentUiState.Success)
        assertEquals(1, (state as CommentUiState.Success).data.size)
    }
}

private class FakeCommentRepository : CommentRepository {
    private var data: List<Comment> = emptyList()
    fun emit(comments: List<Comment>) { data = comments }

    override fun commentsForPost(postId: Int): Flow<List<Comment>> = flow {
        emit(data)
    }
}
```

### 4-3. 작성 요령

- **ViewModel은 Hilt 없이 직접 생성자 호출**로 만든다. `@HiltViewModel`은 프로덕션에서만 의미 있고, 테스트에서는 방해만 된다.
- **`SavedStateHandle`**이 생성자에 있다면 `SavedStateHandle(mapOf(...))`로 값을 주입한다.
- **초기 상태**는 별도 케이스로 꼭 검증한다 (`Loading`).
- **StateFlow 검증**은 `.value`로 현재값만 보거나 `.first { 조건 }`으로 원하는 상태까지 대기한다.

### 4-4. Turbine 활용 (선택)

StateFlow를 시간 순서대로 검증하려면 `app.cash.turbine:turbine` 라이브러리를 추가해서 사용할 수 있습니다. 이 템플릿은 아직 포함돼 있지 않으므로 필요 시 `libs.versions.toml`에 추가합니다.

```kotlin
viewModel.uiState.test {
    assertEquals(CommentUiState.Loading, awaitItem())
    assertTrue(awaitItem() is CommentUiState.Success)
    cancelAndIgnoreRemainingEvents()
}
```

### 4-5. 실행

```bash
./gradlew :feature:comment:impl:test
```

---

## 5. Composable UI 테스트 (화면 단위)

### 5-1. 위치 규칙

`feature/xxx/impl/src/androidTest/kotlin/...`에 둡니다.

```
feature/comment/impl/src/androidTest/kotlin/android/template/feature/comment/ui/CommentScreenTest.kt
```

### 5-2. 기본 작성 예시 (Hilt 불필요)

화면이 외부 상태를 직접 주입받는 stateless 버전(`CommentContent`처럼)을 만들었다면 Hilt 없이 테스트합니다.

```kotlin
package android.template.feature.comment.ui

import android.template.core.model.Comment
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CommentScreenTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun successState_rendersAllComments() {
        composeTestRule.setContent {
            CommentContent(
                state = CommentUiState.Success(FAKE_COMMENTS)
            )
        }

        composeTestRule.onNodeWithText("댓글1 이름").assertIsDisplayed()
        composeTestRule.onNodeWithText("댓글2 이름").assertIsDisplayed()
    }

    @Test
    fun loadingState_showsProgressIndicator() {
        composeTestRule.setContent {
            CommentContent(state = CommentUiState.Loading)
        }

        composeTestRule
            .onNodeWithText("Loading", substring = true, ignoreCase = true)
            .assertDoesNotExist()
    }
}

private val FAKE_COMMENTS = listOf(
    Comment(1, 1, "댓글1 이름", "a@a.com", "body1"),
    Comment(2, 1, "댓글2 이름", "b@b.com", "body2")
)
```

### 5-3. Hilt가 필요한 경우

`CommentScreen()`처럼 `hiltViewModel()`을 내부적으로 호출하는 화면을 테스트하려면 Hilt 구성이 필요합니다. 그럴 때는 `ui-test-hilt-manifest` 모듈이 제공하는 `HiltComponentActivity`를 씁니다.

```kotlin
@HiltAndroidTest
class CommentScreenHiltTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule =
        createAndroidComposeRule<android.template.uitesthiltmanifest.HiltComponentActivity>()

    @Before
    fun setup() {
        hiltRule.inject()
    }

    @Test
    fun screen_loads() {
        composeTestRule.setContent { CommentScreen() }
        // 검증...
    }
}
```

이때 실제 Repository 대신 **Fake Repository를 Hilt에 주입하고 싶다면** `@TestInstallIn`으로 모듈을 교체합니다. `app/src/androidTest/kotlin/android/template/testdi/FakeDataModule.kt` 예시를 참고하세요.

### 5-4. Composable 테스트 작성 요령

- **stateless 버전을 테스트**한다. Hilt 경유 화면은 꼭 필요한 경우에만.
- **텍스트 기반 파인더**보다 **testTag 기반**이 안정적이다. 긴 텍스트나 번역에 의존하면 깨지기 쉽다.
  ```kotlin
  Text(text = comment.name, modifier = Modifier.testTag("comment-name"))
  ```
  ```kotlin
  composeTestRule.onNodeWithTag("comment-name").assertIsDisplayed()
  ```
- **애니메이션**이 있으면 `composeTestRule.mainClock.autoAdvance = false` 후 수동 진행.
- **리스트 스크롤**은 `onNodeWithTag("list").performScrollToNode(hasText("item20"))`.

### 5-5. 실행

```bash
./gradlew :feature:comment:impl:connectedDebugAndroidTest
```

특정 테스트만:

```bash
./gradlew :feature:comment:impl:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=android.template.feature.comment.ui.CommentScreenTest
```

---

## 6. E2E 네비게이션 테스트 (app 모듈)

### 6-1. 위치 규칙

앱 전체 플로우 테스트는 `app/src/androidTest/kotlin/android/template/ui/...`에 둡니다. 이 프로젝트는 이미 `NavigationTest.kt`가 있습니다.

### 6-2. 실제 예시 (이미 존재)

```kotlin
package android.template.ui

import android.template.core.data.di.fakePosts
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@HiltAndroidTest
class NavigationTest {

    @get:Rule(order = 0)
    var hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun mainActivity_showsFirstFakePostTitle() {
        composeTestRule
            .onNodeWithText(fakePosts.first().title, substring = true)
            .assertExists()
    }
}
```

### 6-3. Fake 주입 방식

`app/src/androidTest/kotlin/android/template/testdi/FakeDataModule.kt`가 `DataModule`을 교체합니다:

```kotlin
@Module
@TestInstallIn(
    components = [SingletonComponent::class],
    replaces = [DataModule::class]
)
interface FakeDataModule {
    @Binds
    abstract fun bindRepository(fakeRepository: FakePostRepository): PostRepository
}
```

이 덕분에 E2E 테스트는 실제 네트워크에 의존하지 않고 `fakePosts`를 씁니다. 새 Repository를 Fake로 교체하려면 같은 파일에 `@Binds`를 추가합니다.

### 6-4. E2E 추가 예시 (화면 이동)

```kotlin
@Test
fun clickingPost_navigatesToCommentScreen() {
    composeTestRule
        .onNodeWithText(fakePosts.first().title, substring = true)
        .performClick()

    composeTestRule.waitUntil(timeoutMillis = 2_000) {
        composeTestRule
            .onAllNodesWithTag("comment-name")
            .fetchSemanticsNodes().isNotEmpty()
    }

    composeTestRule.onNodeWithTag("comment-list").assertIsDisplayed()
}
```

### 6-5. 실행

에뮬레이터가 실행 중이어야 합니다.

```bash
./gradlew :app:connectedDebugAndroidTest
```

---

## 7. 테스트 이름 규칙

JUnit 관례를 따르되 **`_`로 의도를 잘게 쪼갭니다**. 백틱(`` ` ``)으로 감싼 한국어도 허용됩니다.

```kotlin
@Test
fun uiState_initiallyLoading() { }

@Test
fun uiState_emitsSuccess_whenRepositoryReturnsData() { }

@Test
fun `빈 리스트를 반환하면 EmptyState를 보여준다`() { }
```

규칙
- `메서드명_조건_기대결과` 순서를 지키면 실패 메시지에서 바로 원인 파악이 된다.
- "테스트1", "test1" 같은 의미 없는 이름 금지.

---

## 8. Fake vs Mock, 어느 쪽을 쓸까

이 프로젝트는 **Fake를 기본**으로 합니다.

| 항목 | Fake | Mock (Mockito/MockK) |
|---|---|---|
| 작성 방식 | interface 직접 구현한 private 클래스 | 프레임워크가 동적으로 생성 |
| 리팩터링 내성 | 강함 (컴파일러가 잡아줌) | 약함 (메서드명 문자열 의존) |
| 가독성 | 동작 흐름이 명시적 | 장황해지기 쉬움 |
| 학습 곡선 | 낮음 | 라이브러리 API 숙지 필요 |

**Mock을 쓰는 경우**는 거의 없지만, 외부 라이브러리의 방대한 interface를 전부 구현하기 어려울 때만 예외적으로 사용합니다.

---

## 9. 카테고리별 실행 명령어 요약

```bash
# 전체 JVM 단위 테스트
./gradlew test

# 특정 모듈 JVM 테스트
./gradlew :feature:comment:impl:test
./gradlew :core:data:test

# 특정 테스트 클래스/메서드만
./gradlew :feature:comment:impl:test --tests "*CommentViewModelTest*"
./gradlew :feature:comment:impl:test --tests "*.uiState_initiallyLoading"

# 전체 androidTest (에뮬레이터 필요)
./gradlew connectedDebugAndroidTest

# 특정 모듈 androidTest
./gradlew :app:connectedDebugAndroidTest
./gradlew :feature:comment:impl:connectedDebugAndroidTest

# 실패 시 상세 로그
./gradlew test --info
./gradlew connectedDebugAndroidTest --stacktrace
```

테스트 결과 리포트 위치
- JVM: `module/build/reports/tests/testDebugUnitTest/index.html`
- AndroidTest: `module/build/reports/androidTests/connected/index.html`

---

## 10. TDD 권장 사이클

새 기능을 개발할 때는 다음 순서로 테스트 주도 개발을 하는 것을 권장합니다.

1. **실패하는 ViewModel 테스트 작성** (상태 전이 정의)
2. ViewModel 구현 → 테스트 통과
3. **실패하는 Repository 테스트 작성** (데이터 소스 정의)
4. Repository 구현 → 테스트 통과
5. Composable은 먼저 stateless 버전 구현 후 **UI 테스트로 렌더링 검증**
6. 마지막에 E2E 테스트 1개로 전체 플로우 확인

이 사이클을 지키면
- 불필요한 public API가 줄어든다 (테스트가 요구하는 것만 만들기 때문).
- Repository와 ViewModel이 인터페이스 기반으로 자연스럽게 분리된다.
- UI 회귀를 빨리 잡는다.

---

## 11. 최소 테스트 커버리지 목표

| 레이어 | 최소 목표 |
|---|---|
| Repository | 성공 케이스 1개 + 실패 케이스 1개 |
| ViewModel | 초기 상태 + 각 UiState 전이 1개씩 |
| Composable | 각 주요 UiState별 렌더링 1개 (Loading, Error, Success) |
| E2E | 핵심 네비게이션 경로 1~2개 |

**전체 코드 커버리지 80%**를 목표로 하되, UI보다 ViewModel/Repository에 비중을 둡니다.

---

## 12. 자주 하는 실수 체크리스트

- [ ] `runTest` 없이 `suspend` 함수를 호출 → `Test was run` 이전에 스킵됨
- [ ] Flow 수집을 `.collect { }`로 했는데 `cancelAndIgnoreRemainingEvents()` 안 함 → 테스트 영영 안 끝남
- [ ] ViewModel을 Hilt로 만들려고 시도 → 불필요. 생성자 직접 호출.
- [ ] Composable 테스트에서 `onNodeWithText`로 긴 한글 텍스트 찾기 → 번역/수정 시 깨짐. `testTag` 사용.
- [ ] E2E에서 애니메이션 대기를 `Thread.sleep`으로 처리 → 플레이키 테스트. `waitUntil { }` 사용.
- [ ] `@Binds` 함수에 `abstract` 빠짐 (interface 내부이므로 자동이지만 class에서는 필수)
- [ ] `@HiltAndroidTest` 누락 → `HiltAndroidRule.inject()`에서 크래시
- [ ] `FakeDataModule`에 새 Repository 추가 안 하고 E2E 실행 → "cannot be provided" 에러

---

## 13. 참고

- 기능 추가 방법은 `feature-development-guide.md` 참조.
- 참고 레퍼런스: [nowinandroid](https://github.com/android/nowinandroid) — 특히 `feature/foryou/impl/src/test/` 와 `feature/foryou/impl/src/androidTest/` 구조를 보면 실전 예제가 풍부합니다.
