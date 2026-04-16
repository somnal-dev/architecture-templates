# `core:datastore` 개발 가이드

이 문서는 **Preferences DataStore** 기반의 가볍고 타입 안전한 키-값 저장이 필요할 때 `core:datastore` 모듈을 어떻게 확장하는지 단계별로 설명합니다. 예시로 기존 `UserPreferences` 옆에 **"알림 활성화 여부(notificationsEnabled)"**를 추가하는 과정을 가정합니다.

> 참고 레퍼런스: `/Users/choi/Documents/GitHub/nowinandroid/core/datastore/` — NIA는 Proto DataStore를 쓰지만, 이 템플릿은 단순성을 위해 **Preferences DataStore**를 씁니다. 스키마가 복잡해지면 NIA 방식(Proto)으로 전환하세요.

---

## 1. 모듈 개요

| 항목 | 설명 |
|---|---|
| 위치 | `core/datastore/` |
| 역할 | 소량의 사용자 환경설정을 비동기·트랜잭션 안전하게 저장 |
| 빌드 플러그인 | `template.android.library`, `template.hilt` |
| 저장 파일 | `<앱 data>/datastore/user_preferences.preferences_pb` |
| 상위 의존 | `core/data` (Repository가 DataSource를 주입받아 사용) |

**기존 예제:** `UserPreferencesDataSource` — `darkThemeEnabled: Boolean`, `lastOpenedPostId: Int?`를 저장.

---

## 2. 언제 `core:datastore`를 쓰나

- [ ] 값이 **소수의 설정/토글/최근 사용값** 수준이다 (10~20개 키 이하).
- [ ] 값이 작고 구조화 요구가 없다 (리스트 저장, 복잡한 쿼리 X).
- [ ] 앱 시작 시 **한 번 읽어 StateFlow로 관찰**하는 패턴이 자연스럽다.
- 그렇지 않다면 → **`core:database`** 를 사용한다.
- SharedPreferences는 **쓰지 않는다** (동기 I/O, 에러 전파 어려움).

---

## 3. 새 Preference 추가 체크리스트

### 3-1. `UserPreferences` 데이터 클래스 확장

위치: `core/datastore/src/main/kotlin/android/template/core/datastore/UserPreferences.kt`

```kotlin
data class UserPreferences(
    val darkThemeEnabled: Boolean = false,
    val lastOpenedPostId: Int? = null,
    val notificationsEnabled: Boolean = true,   // ← 추가
)
```

체크리스트

- [ ] 모든 필드에 **기본값**을 준다 (첫 실행 시 키가 없을 때 반환할 값).
- [ ] `data class`로 유지, `val`만 사용.
- [ ] Boolean/Int/Long/Float/String/Set<String> 만 가능 (Preferences DataStore 제약).

### 3-2. `UserPreferencesDataSource`에 키 + read/write 추가

위치: `core/datastore/src/main/kotlin/android/template/core/datastore/UserPreferencesDataSource.kt`

```kotlin
val userPreferences: Flow<UserPreferences> = dataStore.data.map { prefs ->
    UserPreferences(
        darkThemeEnabled = prefs[KEY_DARK_THEME] ?: false,
        lastOpenedPostId = prefs[KEY_LAST_OPENED_POST_ID],
        notificationsEnabled = prefs[KEY_NOTIFICATIONS_ENABLED] ?: true, // ← 추가
    )
}

suspend fun setNotificationsEnabled(enabled: Boolean) {
    dataStore.edit { it[KEY_NOTIFICATIONS_ENABLED] = enabled }
}

private companion object {
    val KEY_DARK_THEME = booleanPreferencesKey("dark_theme_enabled")
    val KEY_LAST_OPENED_POST_ID = intPreferencesKey("last_opened_post_id")
    val KEY_NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled") // ← 추가
}
```

체크리스트

- [ ] 키 이름은 `snake_case` **문자열**로 지정 (앱 업데이트 후에도 유지되므로 신중히).
- [ ] 키는 `companion object`에 모아둔다 (한 파일에서 검색 가능).
- [ ] read는 `map { }`에서, write는 별도 `suspend fun` + `dataStore.edit { }`.
- [ ] 기존 키 이름은 **변경하지 않는다**. 변경하려면 아래 3-4(마이그레이션) 참고.

### 3-3. Repository에서 사용

`core/datastore`는 `core/data`에서 이미 주입받을 수 있도록 설계되어 있습니다 (`DataStoreModule`이 `SingletonComponent`에 설치됨). 그래서 바로 Repository에 주입하면 됩니다.

위치: `core/data/src/main/kotlin/android/template/core/data/UserSettingsRepository.kt`

```kotlin
package android.template.core.data

import android.template.core.datastore.UserPreferences
import android.template.core.datastore.UserPreferencesDataSource
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

interface UserSettingsRepository {
    val settings: Flow<UserPreferences>
    suspend fun setNotificationsEnabled(enabled: Boolean)
}

class DefaultUserSettingsRepository @Inject constructor(
    private val dataSource: UserPreferencesDataSource,
) : UserSettingsRepository {
    override val settings = dataSource.userPreferences
    override suspend fun setNotificationsEnabled(enabled: Boolean) =
        dataSource.setNotificationsEnabled(enabled)
}
```

그리고 `core/data`의 `build.gradle.kts`에 `core:datastore`가 의존성에 있어야 합니다:

```kotlin
// core/data/build.gradle.kts
dependencies {
    implementation(projects.core.datastore)   // ← 처음 쓸 때 추가
    // ...
}
```

체크리스트

- [ ] ViewModel에서 `UserPreferencesDataSource`를 **직접 주입받지 않는다.** 반드시 Repository를 거친다.
- [ ] `core:data/DataModule.kt`에 `@Binds` 추가.
- [ ] `setNotificationsEnabled`는 `suspend` — UI에서는 `viewModelScope.launch { }`로 호출.

### 3-4. 키 이름 변경 / 타입 변경 (마이그레이션)

기존 키 이름을 바꾸거나 타입을 바꾸면 **기존 사용자의 값이 사라진다**. 유지하려면 마이그레이션을 추가한다.

```kotlin
// DataStoreModule.kt
PreferenceDataStoreFactory.create(
    produceFile = { context.preferencesDataStoreFile(USER_PREFERENCES_NAME) },
    migrations = listOf(
        object : DataMigration<Preferences> {
            override suspend fun shouldMigrate(current: Preferences) =
                current.contains(oldKey) && !current.contains(newKey)

            override suspend fun migrate(current: Preferences): Preferences {
                val mutable = current.toMutablePreferences()
                mutable[newKey] = current[oldKey]!!
                mutable.remove(oldKey)
                return mutable.toPreferences()
            }

            override suspend fun cleanUp() {}
        },
    ),
)
```

체크리스트

- [ ] 키 리네임/타입 변경은 사실상 새 키 + 마이그레이션이라고 생각한다.
- [ ] 불확실하면 **새 키를 새로 만들고 기본값을 주는** 쪽이 훨씬 안전하다.

---

## 4. 빌드 & 검증

```bash
./gradlew :core:datastore:assembleDebug
./gradlew :core:data:assembleDebug
./gradlew :app:assembleDebug
```

체크리스트

- [ ] 앱을 실행하고 설정 토글 → 프로세스 종료 → 재실행 시 값이 유지되는지 확인.
- [ ] 설치된 앱의 preferences 파일은 `/data/data/<package>/files/datastore/user_preferences.preferences_pb`에 저장됨.
- [ ] 테스트에서는 `tmpFolder`를 쓰거나 `DataStoreFactory.create { ... }`로 in-memory 경로를 구성해 격리.

---

## 5. 자주 하는 실수

- `runBlocking { dataStore.data.first() }`를 UI에서 호출 → ANR 위험. 반드시 Flow 구독으로 관찰.
- 기본값을 주지 않고 `prefs[KEY]!!` 사용 → 첫 실행 NPE.
- 너무 많은 키 (50+) → 스키마가 복잡해지는 신호. Proto DataStore 또는 Room으로 전환 검토.
- `UserPreferencesDataSource`를 `@ViewModelScoped`로 만들기 → 싱글톤이 아니면 디스크 I/O가 중복됨. **반드시 `@Singleton`**.

---

## 6. 참고

- 예제: `core/datastore/src/main/kotlin/android/template/core/datastore/UserPreferencesDataSource.kt`
- NIA 레퍼런스 (Proto DataStore 기반): `/Users/choi/Documents/GitHub/nowinandroid/core/datastore/`
- 공식 문서: https://developer.android.com/topic/libraries/architecture/datastore
