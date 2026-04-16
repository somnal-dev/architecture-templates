# Hilt DI / 싱글톤 가이드 — `@Provides` vs `@Binds`

이 문서는 Hilt 모듈을 작성할 때 **언제 `@Provides`를 쓰고 언제 `@Binds`를 쓰는지**, 그리고 `@Singleton` 스코프를 언제 붙이는지를 단계별로 설명합니다.

> 참고 레퍼런스: `/Users/choi/Documents/GitHub/nowinandroid/core/*/src/main/kotlin/**/di/` — NIA의 DI 패턴이 이 템플릿의 원형입니다. 새 모듈을 작성할 때 NIA 쪽 `*Module.kt`를 먼저 살펴보세요.

---

## 1. 한 줄 요약

| 상황 | 써야 할 것 | 모듈 형태 |
|---|---|---|
| 직접 `new`/빌더로 **객체를 만들어야** 한다 | `@Provides` | `object XxxModule` |
| **인터페이스 ↔ 구현체** 바인딩만 하면 된다 | `@Binds` | `interface XxxModule` |
| 생성자에 `@Inject`를 달 수 없다 (외부 라이브러리, 빌더 필요) | `@Provides` | `object XxxModule` |
| 내가 만든 클래스이고 생성자 `@Inject constructor`로 충분 | `@Binds` | `interface XxxModule` |

**결정 순서**:

```
1. 해당 타입을 내가 소유하는가?
   └ No → @Provides
   └ Yes ↓
2. 생성자 @Inject만으로 만들 수 있는가?
   └ No  → @Provides (빌더/팩토리 필요)
   └ Yes ↓
3. 인터페이스에 구현체를 바인딩하는 것이 목적인가?
   └ Yes → @Binds        (가장 가볍고 빠름)
   └ No  → @Provides 도 가능 (단순 DI는 생성자 주입만으로 끝나므로 모듈 불필요)
```

---

## 2. `@Provides` — "내가 직접 만들어서 넣어줄게"

### 언제 쓰나

- **외부 라이브러리 객체** (Retrofit, OkHttpClient, Room `Database`, `DataStore` 등) — 생성자에 `@Inject`를 달 수 없다.
- **빌더/팩토리가 필요한** 경우 (`Retrofit.Builder().baseUrl(...).build()`).
- **런타임 값**을 주입해야 할 때 (`BuildConfig.API_KEY`, `@ApplicationContext`).
- **조건부 구현**이 필요할 때 (디버그 빌드에선 A, 릴리즈 빌드에선 B).

### 형태

모듈은 **`object`** (또는 `class`). 메서드 본문에서 객체를 생성해서 반환한다.

```kotlin
// core/network/src/main/kotlin/.../di/NetworkModule.kt
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder()
            .addInterceptor(HttpLoggingInterceptor())
            .build()

    @Provides
    @Singleton
    fun provideRetrofit(okHttp: OkHttpClient): Retrofit =
        Retrofit.Builder()
            .baseUrl("https://example.com/")
            .client(okHttp)
            .addConverterFactory(GsonConverterFactory.create())
            .build()

    @Provides
    @Singleton
    fun providePostApi(retrofit: Retrofit): PostApi =
        retrofit.create(PostApi::class.java)
}
```

실제 프로젝트 예시:

- `core/network/.../di/NetworkModule.kt` — Retrofit / OkHttp / API
- `core/database/.../di/DatabaseModule.kt` — Room `AppDatabase`, Dao
- `core/datastore/.../di/DataStoreModule.kt` — `DataStore<Preferences>`

### 체크리스트

- [ ] 모듈은 `object`로 정의했는가? (불필요한 인스턴스화 방지)
- [ ] 반환 타입을 **인터페이스**로 노출할 수 있으면 그렇게 한다 (`Retrofit` vs `RetrofitImpl` 같은 구별은 없어 Retrofit은 그대로지만, 우리 도메인 타입은 가능).
- [ ] 매번 새로 만들어야 하는 객체인가, 싱글톤인가? → 싱글톤이면 `@Singleton` 추가 (3절 참고).

---

## 3. `@Binds` — "구현체가 이미 있으니 이 인터페이스로 연결만 해줘"

### 언제 쓰나

- 내가 소유한 **인터페이스 ↔ 구현체 쌍**을 DI에 등록할 때.
- 구현체가 `@Inject constructor`로 충분히 만들어질 때 (Hilt가 의존성을 자동으로 채워준다).

### 형태

모듈은 **`interface`**, 메서드는 **추상 함수**. 파라미터로 받은 구현체를 반환 타입으로 바인딩한다.

```kotlin
// core/data/src/main/kotlin/.../di/DataModule.kt
@Module
@InstallIn(SingletonComponent::class)
interface DataModule {

    @Singleton
    @Binds
    fun bindsPostRepository(
        impl: DefaultPostRepository
    ): PostRepository
}
```

구현체는 반드시 `@Inject constructor`를 가진다:

```kotlin
class DefaultPostRepository @Inject constructor(
    private val api: PostApi,
    private val dao: LikedPostDao,
) : PostRepository { /* ... */ }
```

이제 다른 곳에서:

```kotlin
@HiltViewModel
class PostListViewModel @Inject constructor(
    private val repository: PostRepository  // ← 인터페이스만 의존
) : ViewModel()
```

### 왜 `@Provides` 대신 `@Binds`를 쓰나

- **성능**: `@Binds`는 Hilt가 컴파일 타임에 **직접 치환 코드**를 생성한다. `@Provides`는 래핑된 팩토리 메서드를 만든다 → 약간의 오버헤드.
- **보일러플레이트 감소**: 구현체 파라미터 → 인터페이스 반환. 한 줄.
- **의도의 명확성**: "이건 단지 바인딩 매핑이다" 가 코드로 보인다.

### 체크리스트

- [ ] 모듈이 `interface`인가? (`@Binds`는 `abstract fun`이므로 `object`/`class`에선 안 됨)
- [ ] 구현체가 `@Inject constructor`를 가졌는가?
- [ ] 파라미터 타입 = 구현체, 반환 타입 = 인터페이스인가? (반대로 적으면 컴파일 에러)
- [ ] `@Singleton`이 필요하면 `@Binds`에도 붙인다.

---

## 4. `@Singleton` — "앱 전체에서 한 번만 만들어줘"

### 기본 원칙

- `SingletonComponent`에 설치된 바인딩 + `@Singleton`이 붙으면 **앱 프로세스 생애 동안 단 하나의 인스턴스**가 유지된다.
- 붙이지 않으면 **요청할 때마다 새 인스턴스**가 생성된다.

### `@Singleton`을 붙이는 기준

붙인다:

- **생성 비용이 큰** 객체 — `OkHttpClient`, `Retrofit`, `Room.databaseBuilder(...)`, `DataStore`.
- **내부 상태(캐시/커넥션 풀)**를 공유해야 하는 객체 — 같은 `OkHttpClient`가 커넥션을 재사용해야 성능이 나온다.
- **Repository** — 상태 캐시나 Flow 공유가 중요하다.

붙이지 않는다:

- **가벼운 값 객체** / 매번 새로 만들어도 되는 것.
- 본인이 이미 내부적으로 싱글톤을 가진 **팩토리의 결과** (예: `retrofit.create(PostApi::class.java)`는 Retrofit 내부 캐시가 있긴 하지만, 명시적으로 `@Singleton`을 주는 것이 관례).

### 스코프 계층

| Component | 대응 `@Scope` | 생명주기 |
|---|---|---|
| `SingletonComponent` | `@Singleton` | Application |
| `ActivityRetainedComponent` | `@ActivityRetainedScoped` | 구성 변경에도 유지되는 Activity |
| `ViewModelComponent` | `@ViewModelScoped` | ViewModel 1개 |
| `ActivityComponent` | `@ActivityScoped` | Activity |
| `FragmentComponent` | `@FragmentScoped` | Fragment |

**원칙**: 필요한 가장 좁은 스코프를 고른다. 잘 모르겠으면 `@Singleton`이 기본.

---

## 5. 실전 흐름 예시 — `Comment` 기능을 새로 추가한다면

```kotlin
// 1) core/network — 외부 라이브러리 → @Provides
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides @Singleton
    fun provideCommentApi(retrofit: Retrofit): CommentApi =
        retrofit.create(CommentApi::class.java)
}
```

```kotlin
// 2) core/data — 인터페이스 + 구현체 → @Binds
interface CommentRepository { /* ... */ }

class DefaultCommentRepository @Inject constructor(
    private val api: CommentApi,
) : CommentRepository { /* ... */ }

@Module
@InstallIn(SingletonComponent::class)
interface DataModule {
    @Binds @Singleton
    fun bindsCommentRepository(
        impl: DefaultCommentRepository
    ): CommentRepository
}
```

```kotlin
// 3) feature/.../impl — 단순 생성자 주입이면 모듈 자체가 불필요
@HiltViewModel
class CommentViewModel @Inject constructor(
    private val repository: CommentRepository,
) : ViewModel()
```

---

## 6. 자주 하는 실수

### `@Binds` 모듈을 `object`로 선언

```kotlin
// ✗ 컴파일 에러: @Binds는 추상 함수여야 함
@Module
object DataModule {
    @Binds fun bindsRepo(impl: DefaultRepo): Repo
}
```

→ `interface DataModule`로 바꾼다.

### `@Provides`와 `@Binds`를 한 모듈에 섞기

```kotlin
// ✗ @Binds는 abstract — object에는 못 넣고, interface에는 @Provides 추상 함수가 안 됨
interface MixedModule {
    @Binds fun bindsRepo(impl: DefaultRepo): Repo
    @Provides fun provideThing(): Thing = Thing()  // 이건 companion으로 빼야 함
}
```

→ 섞어야 하면 `@Provides`만 있는 `object` 모듈을 별도로 만들거나, `interface` 내부 `companion object`에 `@Provides`를 둔다.

### `@Singleton` 누락

- `DataStore<Preferences>`를 `@Singleton` 없이 provide → **호출할 때마다 새 DataStore가 만들어지고, 디스크 I/O가 경쟁**.
- Room `AppDatabase`를 `@Singleton` 없이 provide → **여러 커넥션이 열리고 마이그레이션 충돌** 가능.
- 규칙: **`Database`, `DataStore`, `OkHttpClient`, `Retrofit`, `Repository`**는 기본적으로 `@Singleton`.

### 반환 타입을 구현체로 적기

```kotlin
// ✗ 구현체를 노출하면 다른 곳에서도 구현체를 의존하게 된다
@Binds fun bindsRepo(impl: DefaultPostRepository): DefaultPostRepository
```

→ 반환 타입은 **인터페이스**여야 한다.

### 순환 의존

`A`가 `B`를 주입받고 `B`가 `A`를 주입받으면 Hilt는 빌드 타임에 에러를 낸다.

→ 구조를 재설계하거나, 한쪽을 `Provider<A>` / `Lazy<A>`로 바꿔 지연 주입.

### `object` 모듈에 상태를 두기

```kotlin
// ✗ object는 프로세스 생애 동안 살아남으므로 사실상 전역 상태
@Module @InstallIn(SingletonComponent::class)
object BadModule {
    private var cache: Foo? = null   // 테스트 간 누수!
    @Provides fun provideFoo(): Foo = cache ?: Foo().also { cache = it }
}
```

→ 캐싱이 필요하면 `@Singleton` 바인딩에 맡긴다.

---

## 7. 체크리스트 요약

새 DI 바인딩을 추가할 때마다:

- [ ] 이 타입은 외부 라이브러리인가? → `@Provides` + `object` 모듈.
- [ ] 내 인터페이스 ↔ 구현체 바인딩인가? → `@Binds` + `interface` 모듈.
- [ ] 생성 비용이 크거나 상태가 공유돼야 하는가? → `@Singleton`.
- [ ] 반환 타입이 구현체가 아닌 **인터페이스**인가?
- [ ] 모듈이 올바른 컴포넌트에 `@InstallIn` 되었는가? (대부분 `SingletonComponent`)
- [ ] 테스트에서 교체할 수 있도록 **Fake 구현체**를 `core/testing` 또는 `app/androidTest/testdi`에 준비했는가?

---

## 8. 참고

- 실제 모듈 예시:
  - `core/network/.../di/NetworkModule.kt` — `@Provides` + `object` (외부 라이브러리)
  - `core/database/.../di/DatabaseModule.kt` — `@Provides` + `class` (Room 빌더)
  - `core/datastore/.../di/DataStoreModule.kt` — `@Provides` + `object` (`DataStore` 팩토리)
  - `core/data/.../di/DataModule.kt` — `@Binds` + `interface` (Repository 바인딩)
- NIA 레퍼런스: `/Users/choi/Documents/GitHub/nowinandroid/core/*/src/main/kotlin/**/di/`
- 공식 문서: https://dagger.dev/hilt/
