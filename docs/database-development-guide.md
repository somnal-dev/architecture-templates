# `core:database` 개발 가이드

이 문서는 **Room 기반 로컬 영속화**가 필요할 때 `core:database` 모듈을 어떻게 확장하는지 단계별로 설명합니다. 예시로 "좋아요한 게시글(LikedPost)" 옆에 **"검색 기록(SearchHistory)"** 기능을 추가하는 과정을 가정합니다.

> 참고 레퍼런스: `/Users/choi/Documents/GitHub/nowinandroid/core/database/` — Google Now in Android의 database 모듈이 이 템플릿의 원형입니다. 새 Entity/Dao를 설계할 때 NIA 쪽을 먼저 살펴보고 패턴을 따라가세요.

---

## 1. 모듈 개요

| 항목 | 설명 |
|---|---|
| 위치 | `core/database/` |
| 역할 | 로컬 SQLite 영속화 — Room `Entity`, `Dao`, `Database` 정의 |
| 빌드 플러그인 | `template.android.library`, `template.hilt`, `template.android.room` |
| 스키마 출력 | `core/database/schemas/` (KSP가 자동 생성, **반드시 커밋**) |
| 상위 의존 | `core/data` (Repository가 Dao를 주입받아 사용) |

**기존 예제:** `LikedPost.kt` + `LikedPostDao` — `postId`를 키로 좋아요 여부를 영속화.

---

## 2. 언제 `core:database`를 건드리나

- [ ] 앱 재시작 후에도 남아야 하는 **구조화된 데이터**가 있다 (리스트, 관계형 데이터, 쿼리 필요).
- [ ] 키-값 한두 개 수준이면 `core:database`가 아니라 **`core:datastore`**를 사용한다 (테마 설정, 마지막 본 ID 등).
- [ ] 서버 응답을 캐싱해 오프라인에서도 보여주고 싶다 → Entity로 저장.

---

## 3. 새 Entity 추가 체크리스트

### 3-1. Entity + Dao 작성

위치: `core/database/src/main/kotlin/android/template/core/database/SearchHistory.kt`

```kotlin
package android.template.core.database

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Entity
data class SearchHistory(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val query: String,
    val searchedAt: Long,
)

@Dao
interface SearchHistoryDao {
    @Query("SELECT * FROM searchhistory ORDER BY searchedAt DESC LIMIT :limit")
    fun recent(limit: Int = 20): Flow<List<SearchHistory>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: SearchHistory)

    @Query("DELETE FROM searchhistory")
    suspend fun clear()
}
```

체크리스트

- [ ] Entity는 `data class`로 정의하고 `val`만 사용한다 (불변).
- [ ] `@PrimaryKey`는 반드시 지정. 복합키가 필요하면 `@Entity(primaryKeys = [...])`.
- [ ] 모든 Dao 메서드는 `suspend` 또는 `Flow`로 반환 (절대 블로킹 X).
- [ ] 쿼리 결과가 없으면 `null`이 아닌 **빈 리스트 / 빈 Flow**로 수렴하게 설계.
- [ ] 파일명은 Entity명과 맞춘다 (`SearchHistory.kt`). Dao는 같은 파일에 두거나 `SearchHistoryDao.kt`로 분리.

### 3-2. `AppDatabase`에 Entity 등록

위치: `core/database/src/main/kotlin/android/template/core/database/AppDatabase.kt`

```kotlin
@Database(
    entities = [LikedPost::class, SearchHistory::class],
    version = 2,                       // ← 버전 올림
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun likedPostDao(): LikedPostDao
    abstract fun searchHistoryDao(): SearchHistoryDao
}
```

체크리스트

- [ ] `entities` 배열에 새 Entity 추가.
- [ ] `version`을 **반드시** 하나 올린다 (1 → 2).
- [ ] 새 Dao 접근 메서드를 추상 함수로 선언.
- [ ] 스키마 변경 후 빌드하면 `core/database/schemas/.../2.json`이 생성된다 → **커밋 필수**.

### 3-3. 마이그레이션 작성 (기존 Entity를 변경했을 때만)

새 Entity만 **추가**했다면 Room이 자동으로 테이블을 만들어 준다. 기존 Entity를 변경했으면 반드시 Migration을 제공해야 한다.

```kotlin
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("CREATE TABLE IF NOT EXISTS SearchHistory (...)")
    }
}
```

그리고 `DatabaseModule`에서 빌더에 연결:

```kotlin
Room.databaseBuilder(appContext, AppDatabase::class.java, "PostApp")
    .addMigrations(MIGRATION_1_2)
    .build()
```

체크리스트

- [ ] 프로덕션 DB에 영향이 가는 변경이면 **반드시** Migration 작성.
- [ ] Migration 작성이 어려우면 최소한 `.fallbackToDestructiveMigration()`을 쓰되 **프로덕션 이전 단계에서만** 허용.

### 3-4. Hilt 모듈에 Dao provider 추가

위치: `core/database/src/main/kotlin/android/template/core/database/di/DatabaseModule.kt`

```kotlin
@Provides
fun provideSearchHistoryDao(appDatabase: AppDatabase): SearchHistoryDao {
    return appDatabase.searchHistoryDao()
}
```

체크리스트

- [ ] Dao provider는 `@Singleton`이 아니어도 된다 (Dao는 Database에서 가져오기만 하고 내부 캐싱됨).
- [ ] `AppDatabase` provider는 이미 `@Singleton`으로 선언되어 있다.

### 3-5. Repository에서 사용

위치: `core/data/src/main/kotlin/android/template/core/data/SearchHistoryRepository.kt`

```kotlin
package android.template.core.data

import android.template.core.database.SearchHistory
import android.template.core.database.SearchHistoryDao
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject

interface SearchHistoryRepository {
    val recent: Flow<List<SearchHistory>>
    suspend fun record(query: String)
    suspend fun clear()
}

class DefaultSearchHistoryRepository @Inject constructor(
    private val dao: SearchHistoryDao,
) : SearchHistoryRepository {
    override val recent = dao.recent()
    override suspend fun record(query: String) =
        dao.insert(SearchHistory(query = query, searchedAt = System.currentTimeMillis()))
    override suspend fun clear() = dao.clear()
}
```

체크리스트

- [ ] Entity를 UI에 **직접 노출하지 않는다.** Repository에서 `core/model`의 도메인 클래스로 변환하는 것이 이상적 (작은 예시에서는 생략 가능).
- [ ] `core:data/DataModule.kt`에 `@Binds` 추가.

---

## 4. 빌드 & 검증

```bash
./gradlew :core:database:assembleDebug
./gradlew :core:data:assembleDebug
./gradlew :app:assembleDebug
```

체크리스트

- [ ] 빌드 성공 후 `core/database/schemas/android.template.core.database.AppDatabase/2.json`이 생성됐는지 확인.
- [ ] 생성된 JSON 스키마 파일을 **git에 커밋**한다 (마이그레이션 검증에 사용됨).
- [ ] `@Query` 문법 오류는 **빌드 타임**에 잡힌다. 런타임 크래시가 나면 쿼리 SQL을 재확인.

---

## 5. 자주 하는 실수

- 버전을 올리지 않고 스키마 변경 → 런타임에 `IllegalStateException: Migration required` 크래시.
- Dao에서 `suspend` 누락 → 메인 스레드 블로킹.
- Entity를 UI 레이어가 직접 import → `core:database`가 UI에 누수. Repository 경계에서 멈춰야 한다.
- 스키마 JSON 커밋 누락 → 동료가 마이그레이션 테스트를 재현할 수 없음.

---

## 6. 참고

- 예제 Entity: `core/database/src/main/kotlin/android/template/core/database/LikedPost.kt`
- NIA 레퍼런스: `/Users/choi/Documents/GitHub/nowinandroid/core/database/`
- 공식 문서: https://developer.android.com/training/data-storage/room
