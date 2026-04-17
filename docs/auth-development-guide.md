# 인증(Auth) 개발 가이드

이 문서는 `dummyjson.com/auth` API를 예제로 **로그인 → 토큰 저장 → 자동 헤더 주입 → 토큰 갱신** 흐름을 구현하는 방법을 설명합니다.

> **테스트 계정:** `emilys` / `emilyspass`

---

## 1. 전체 흐름

```
[LoginScreen] → [AuthRepository.login()] → POST /auth/login
                        │
                        ▼
              TokenDataSource에 accessToken + refreshToken 저장
                        │
                        ▼
              AuthInterceptor가 모든 요청에 Authorization 헤더 자동 주입
                        │
                        ▼
              401 응답 시 TokenAuthenticator가 /auth/refresh 호출 → 토큰 갱신 → 재시도
```

---

## 2. 모듈 배치

| 파일                              | 모듈             | 역할                        |
| --------------------------------- | ---------------- | --------------------------- |
| `AuthApi.kt`                      | `core:network`   | Retrofit 인터페이스          |
| `AuthNetwork.kt`                  | `core:network`   | 로그인/토큰 DTO             |
| `AuthInterceptor.kt`              | `core:network`   | 요청마다 토큰 헤더 주입      |
| `TokenAuthenticator.kt`           | `core:network`   | 401 시 토큰 갱신 + 재시도    |
| `TokenDataSource.kt`              | `core:datastore` | DataStore에 토큰 저장/읽기   |
| `AuthRepository.kt`               | `core:data`      | 로그인/로그아웃/토큰 상태 노출 |
| `LoginScreen.kt` / `LoginViewModel.kt` | `feature:login:impl` | 로그인 UI          |

---

## 3. 단계별 구현

### 3-1. DTO 정의 (`core:network`)

`core/network/src/main/kotlin/android/template/core/network/api/AuthNetwork.kt`:

```kotlin
package android.template.core.network.api

data class LoginRequest(
    val username: String,
    val password: String,
    val expiresInMins: Int = 60,
)

data class LoginResponse(
    val id: Int,
    val username: String,
    val email: String,
    val firstName: String,
    val lastName: String,
    val gender: String,
    val image: String,
    val accessToken: String,
    val refreshToken: String,
)

data class RefreshRequest(
    val refreshToken: String,
    val expiresInMins: Int = 60,
)

data class RefreshResponse(
    val accessToken: String,
    val refreshToken: String,
)

data class AuthUser(
    val id: Int,
    val username: String,
    val email: String,
    val firstName: String,
    val lastName: String,
    val gender: String,
    val image: String,
)
```

### 3-2. Retrofit 인터페이스 (`core:network`)

`core/network/src/main/kotlin/android/template/core/network/api/AuthApi.kt`:

```kotlin
package android.template.core.network.api

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST

interface AuthApi {
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): LoginResponse

    @POST("auth/refresh")
    suspend fun refresh(@Body request: RefreshRequest): RefreshResponse

    @GET("auth/me")
    suspend fun me(@Header("Authorization") token: String): AuthUser
}
```

> `me()`는 `AuthInterceptor`를 타지 않도록 명시적으로 `@Header`를 받는다. 이유: 인터셉터가 아직 토큰을 모르는 시점에도 호출할 수 있어야 하기 때문.

### 3-3. 토큰 저장소 (`core:datastore`)

`core/datastore/src/main/kotlin/android/template/core/datastore/TokenDataSource.kt`:

```kotlin
package android.template.core.datastore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TokenDataSource @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    val accessToken: Flow<String?> = dataStore.data.map { it[ACCESS_TOKEN] }
    val refreshToken: Flow<String?> = dataStore.data.map { it[REFRESH_TOKEN] }

    val isLoggedIn: Flow<Boolean> = accessToken.map { it != null }

    suspend fun save(accessToken: String, refreshToken: String) {
        dataStore.edit { prefs ->
            prefs[ACCESS_TOKEN] = accessToken
            prefs[REFRESH_TOKEN] = refreshToken
        }
    }

    suspend fun getAccessTokenOnce(): String? = accessToken.first()

    suspend fun getRefreshTokenOnce(): String? = refreshToken.first()

    suspend fun clear() {
        dataStore.edit { prefs ->
            prefs.remove(ACCESS_TOKEN)
            prefs.remove(REFRESH_TOKEN)
        }
    }

    private companion object {
        val ACCESS_TOKEN = stringPreferencesKey("access_token")
        val REFRESH_TOKEN = stringPreferencesKey("refresh_token")
    }
}
```

체크리스트

- [ ] `@Singleton` — 앱 전체에서 하나의 인스턴스만 사용.
- [ ] `getAccessTokenOnce()`는 `suspend`로 한 번만 읽는다 — Interceptor에서 호출.
- [ ] `clear()`로 로그아웃 시 토큰을 완전히 삭제.

### 3-4. OkHttp 인터셉터 — 토큰 자동 주입 (`core:network`)

`core/network/src/main/kotlin/android/template/core/network/auth/AuthInterceptor.kt`:

```kotlin
package android.template.core.network.auth

import android.template.core.datastore.TokenDataSource
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenDataSource: TokenDataSource,
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val original = chain.request()

        // 이미 Authorization 헤더가 있으면 건드리지 않는다 (AuthApi.me() 등)
        if (original.header("Authorization") != null) {
            return chain.proceed(original)
        }

        // auth/ 경로는 토큰이 필요 없다
        if (original.url.encodedPath.startsWith("/auth/")) {
            return chain.proceed(original)
        }

        val token = runBlocking { tokenDataSource.getAccessTokenOnce() }
            ?: return chain.proceed(original)

        val request = original.newBuilder()
            .header("Authorization", "Bearer $token")
            .build()
        return chain.proceed(request)
    }
}
```

### 3-5. OkHttp Authenticator — 401 시 토큰 갱신 (`core:network`)

`core/network/src/main/kotlin/android/template/core/network/auth/TokenAuthenticator.kt`:

```kotlin
package android.template.core.network.auth

import android.template.core.datastore.TokenDataSource
import android.template.core.network.api.AuthApi
import android.template.core.network.api.RefreshRequest
import kotlinx.coroutines.runBlocking
import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TokenAuthenticator @Inject constructor(
    private val tokenDataSource: TokenDataSource,
    private val authApi: dagger.Lazy<AuthApi>,  // 순환 의존 방지
) : Authenticator {

    override fun authenticate(route: Route?, response: Response): Request? {
        // 이미 갱신 시도했으면 무한 루프 방지
        if (response.request.header("X-Retry") != null) {
            runBlocking { tokenDataSource.clear() }
            return null
        }

        val newTokens = runBlocking {
            val refreshToken = tokenDataSource.getRefreshTokenOnce() ?: return@runBlocking null
            try {
                val result = authApi.get().refresh(RefreshRequest(refreshToken))
                tokenDataSource.save(result.accessToken, result.refreshToken)
                result
            } catch (e: Exception) {
                Timber.e(e, "Token refresh failed")
                tokenDataSource.clear()
                null
            }
        } ?: return null

        return response.request.newBuilder()
            .header("Authorization", "Bearer ${newTokens.accessToken}")
            .header("X-Retry", "true")
            .build()
    }
}
```

핵심 포인트

- `dagger.Lazy<AuthApi>` — `AuthApi`가 `Retrofit`에 의존하고, `Retrofit`이 `OkHttpClient`에 의존하고, `OkHttpClient`가 `TokenAuthenticator`에 의존하므로 **순환이 생긴다.** `Lazy`로 느리게 주입하면 해결.
- `X-Retry` 헤더 — 갱신 시도 후에도 401이면 재시도를 멈추고 `null` 반환 (무한 루프 방지).
- 갱신 실패 시 `tokenDataSource.clear()` — 앱은 로그아웃 상태로 돌아간다.

### 3-6. NetworkModule 수정 (`core:network`)

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        tokenAuthenticator: TokenAuthenticator,
    ): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .authenticator(tokenAuthenticator)
            .addInterceptor(
                HttpLoggingInterceptor { message ->
                    Timber.tag("OkHttp").d(message)
                }.apply {
                    level = HttpLoggingInterceptor.Level.BODY
                }
            )
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl("https://dummyjson.com/")
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }

    @Provides
    @Singleton
    fun providePostApi(retrofit: Retrofit): PostApi {
        return retrofit.create(PostApi::class.java)
    }

    @Provides
    @Singleton
    fun provideAuthApi(retrofit: Retrofit): AuthApi {
        return retrofit.create(AuthApi::class.java)
    }
}
```

체크리스트

- [ ] `authInterceptor`는 `addInterceptor`로 — 모든 요청에 토큰 주입.
- [ ] `tokenAuthenticator`는 `authenticator`로 — 401 응답에만 반응.
- [ ] 로깅 인터셉터는 **가장 마지막**에 추가 — Authorization 헤더가 포함된 최종 요청을 로그로 볼 수 있다.
- [ ] `provideAuthApi`를 잊지 말 것 — 없으면 Hilt가 "cannot be provided" 에러.

### 3-7. build.gradle.kts 의존성 추가 (`core:network`)

`core:network`가 `core:datastore`에 의존해야 `TokenDataSource`를 주입받을 수 있다.

```kotlin
// core/network/build.gradle.kts
dependencies {
    implementation(projects.core.datastore)  // TokenDataSource 주입
    // ... 기존 의존성
}
```

### 3-8. AuthRepository (`core:data`)

```kotlin
package android.template.core.data

import android.template.core.datastore.TokenDataSource
import android.template.core.network.api.AuthApi
import android.template.core.network.api.AuthUser
import android.template.core.network.api.LoginRequest
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

interface AuthRepository {
    val isLoggedIn: Flow<Boolean>
    suspend fun login(username: String, password: String): Result<AuthUser>
    suspend fun me(): Result<AuthUser>
    suspend fun logout()
}

@Singleton
class DefaultAuthRepository @Inject constructor(
    private val authApi: AuthApi,
    private val tokenDataSource: TokenDataSource,
) : AuthRepository {

    override val isLoggedIn: Flow<Boolean> = tokenDataSource.isLoggedIn

    override suspend fun login(username: String, password: String): Result<AuthUser> =
        runCatching {
            val response = authApi.login(LoginRequest(username, password))
            tokenDataSource.save(response.accessToken, response.refreshToken)
            AuthUser(
                id = response.id,
                username = response.username,
                email = response.email,
                firstName = response.firstName,
                lastName = response.lastName,
                gender = response.gender,
                image = response.image,
            )
        }

    override suspend fun me(): Result<AuthUser> = runCatching {
        val token = tokenDataSource.getAccessTokenOnce()
            ?: error("Not logged in")
        authApi.me("Bearer $token")
    }

    override suspend fun logout() {
        tokenDataSource.clear()
    }
}
```

`DataModule`에 바인딩 추가:

```kotlin
@Singleton
@Binds
fun bindsAuthRepository(
    authRepository: DefaultAuthRepository
): AuthRepository
```

---

## 4. 로그인 feature 모듈 (선택)

### 4-1. `feature:login:api`

```kotlin
// feature/login/api/.../LoginNavKey.kt
@Serializable
data object LoginNavKey : NavKey

fun Navigator.navigateToLogin() {
    navigate(LoginNavKey)
}
```

### 4-2. `feature:login:impl`

```kotlin
// LoginViewModel.kt
@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun login(username: String, password: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            authRepository.login(username, password)
                .onSuccess { _uiState.update { it.copy(isLoading = false, isLoggedIn = true) } }
                .onFailure { e -> _uiState.update { it.copy(isLoading = false, error = e.message) } }
        }
    }
}

data class LoginUiState(
    val isLoading: Boolean = false,
    val isLoggedIn: Boolean = false,
    val error: String? = null,
)
```

```kotlin
// LoginScreen.kt
@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,    // ← 원시 콜백 (Navigator를 모른다)
    modifier: Modifier = Modifier,
    viewModel: LoginViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var username by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(state.isLoggedIn) {
        if (state.isLoggedIn) onLoginSuccess()
    }

    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        OutlinedTextField(value = username, onValueChange = { username = it }, label = { Text("Username") })
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") }, visualTransformation = PasswordVisualTransformation())
        Spacer(Modifier.height(16.dp))
        Button(onClick = { viewModel.login(username, password) }, enabled = !state.isLoading) {
            if (state.isLoading) CircularProgressIndicator(Modifier.size(16.dp))
            else Text("Login")
        }
        state.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    }
}
```

```kotlin
// LoginEntry.kt
@Composable
fun EntryProviderScope<NavKey>.LoginEntry(navigator: Navigator) {
    entry<LoginNavKey> {
        LoginScreen(
            onLoginSuccess = navigator::navigateToPost,
        )
    }
}
```

---

## 5. 동작 요약 표

| 상황 | 동작 |
|------|------|
| 로그인 전 | `AuthInterceptor`가 토큰 없으면 헤더 안 붙임 → API가 401 반환 가능 |
| 로그인 성공 | `TokenDataSource`에 토큰 저장 → 이후 모든 요청에 자동 주입 |
| 토큰 만료 (401) | `TokenAuthenticator`가 `/auth/refresh` 호출 → 새 토큰 저장 → 원래 요청 자동 재시도 |
| 갱신도 실패 | `tokenDataSource.clear()` → 앱이 로그아웃 상태로 복귀 |
| 로그아웃 | `tokenDataSource.clear()` → 토큰 삭제 |

---

## 6. 자주 하는 실수

- [ ] `TokenAuthenticator`에서 `AuthApi`를 직접 주입 → **순환 의존.** 반드시 `dagger.Lazy<AuthApi>` 사용.
- [ ] 갱신 실패 시 `null` 안 반환 → **무한 401 루프.** `X-Retry` 헤더로 1회만 시도.
- [ ] `AuthInterceptor`에서 `runBlocking`이 IO 스레드를 막을까 걱정 → DataStore `first()`는 디스크 캐시 이후 즉시 반환이라 실무에서 문제없다.
- [ ] `auth/login`, `auth/refresh` 요청에도 토큰을 붙임 → 인터셉터에서 `/auth/` 경로는 스킵해야 한다.
- [ ] 로그아웃 시 토큰만 지우고 화면을 안 바꿈 → `isLoggedIn` Flow를 observe해서 UI가 반응하도록.

---

## 7. 참고

- [dummyjson.com/docs/auth](https://dummyjson.com/docs/auth) — API 스펙
- [di-singleton-guide.md](./di-singleton-guide.md) — `@Provides` vs `@Binds`, `Lazy` 주입
- [datastore-development-guide.md](./datastore-development-guide.md) — DataStore 키 추가 규칙
- [feature-development-guide.md](./feature-development-guide.md) — feature 모듈 생성 절차
