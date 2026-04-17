#!/usr/bin/env bash
#
# scaffold.sh — 새 feature + core 레이어 코드를 한 번에 생성하는 스크립트
#
# 사용법:
#   ./scaffold.sh              # 대화형 — 이름과 레이어를 물어봄
#   ./scaffold.sh comment      # feature 이름만 미리 지정
#
set -e

if [[ "$(uname)" == "Darwin" ]]; then
  SED_INPLACE=(-i '')
else
  SED_INPLACE=(-i)
fi

# ─── 프로젝트 루트 감지 ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f settings.gradle.kts ]]; then
  echo "❌ settings.gradle.kts를 찾을 수 없습니다. 프로젝트 루트에서 실행하세요." >&2
  exit 1
fi

# ─── 패키지 접두사 감지 ────────────────────────────────────────
# core/model의 namespace에서 패키지 접두사를 추출 (customizer.sh로 바꿨을 수도 있으므로)
BASE_PKG=$(grep 'namespace' core/model/build.gradle.kts | sed 's/.*"\(.*\)\.core\.model".*/\1/')
if [[ -z "$BASE_PKG" ]]; then
  BASE_PKG="android.template"
fi
BASE_DIR="${BASE_PKG//.//}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Feature Scaffold Generator"
echo "  패키지: $BASE_PKG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─── Feature 이름 입력 ─────────────────────────────────────────
NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  read -p "Feature 이름을 입력하세요 (예: comment, user-profile): " NAME
fi
if [[ -z "$NAME" ]]; then
  echo "❌ Feature 이름은 필수입니다." >&2
  exit 1
fi

# 이름 변환
NAME_LOWER="$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"       # comment, user_profile
NAME_UPPER="$(echo "$NAME_LOWER" | awk -F'_' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1' OFS='')"  # Comment, UserProfile
NAME_CAMEL="$(echo "$NAME_UPPER" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')"  # comment, userProfile
NAME_KEBAB="$(echo "$NAME" | tr '[:upper:]' '[:lower:]')"                     # comment, user-profile
NAME_PKG="$(echo "$NAME_LOWER" | tr -d '_')"                                  # comment, userprofile

echo ""
echo "  이름 변환 확인:"
echo "    PascalCase : $NAME_UPPER"
echo "    camelCase  : $NAME_CAMEL"
echo "    패키지     : $NAME_PKG"
echo ""

# ─── 레이어 선택 ───────────────────────────────────────────────
ask_yn() {
  local prompt="$1" default="${2:-y}"
  local yn
  if [[ "$default" == "y" ]]; then
    read -p "$prompt [Y/n]: " yn
    yn="${yn:-y}"
  else
    read -p "$prompt [y/N]: " yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy] ]]
}

DO_MODEL=false
DO_NETWORK=false
DO_DATA=false
DO_FEATURE_API=false
DO_FEATURE_IMPL=false

echo "━━━ 생성할 레이어를 선택하세요 ━━━"
echo ""
ask_yn "  1. core/model      — ${NAME_UPPER} 도메인 모델"       && DO_MODEL=true
ask_yn "  2. core/network    — ${NAME_UPPER}Api + DTO"          && DO_NETWORK=true
ask_yn "  3. core/data       — ${NAME_UPPER}Repository"         && DO_DATA=true
ask_yn "  4. feature/${NAME_KEBAB}/api  — NavKey + Navigator 확장" && DO_FEATURE_API=true
ask_yn "  5. feature/${NAME_KEBAB}/impl — ViewModel + Screen + Entry" && DO_FEATURE_IMPL=true

echo ""

# 아무것도 선택 안 했으면 종료
if ! $DO_MODEL && ! $DO_NETWORK && ! $DO_DATA && ! $DO_FEATURE_API && ! $DO_FEATURE_IMPL; then
  echo "아무 레이어도 선택하지 않았습니다. 종료합니다."
  exit 0
fi

# ─── NavKey 인자 입력 (api 모듈 생성 시) ───────────────────────
NAV_ARG_NAME=""
NAV_ARG_TYPE=""
NAV_KEY_TYPE="data object"
if $DO_FEATURE_API; then
  echo ""
  read -p "  NavKey에 전달할 인자가 있나요? (예: postId:Int, 없으면 Enter): " NAV_ARG_INPUT
  if [[ -n "$NAV_ARG_INPUT" ]]; then
    NAV_ARG_NAME="$(echo "$NAV_ARG_INPUT" | cut -d: -f1 | xargs)"
    NAV_ARG_TYPE="$(echo "$NAV_ARG_INPUT" | cut -d: -f2 | xargs)"
    NAV_KEY_TYPE="data class"
  fi
fi

CREATED=()

# ─── 1. core/model ─────────────────────────────────────────────
if $DO_MODEL; then
  DIR="core/model/src/main/kotlin/${BASE_DIR}/core/model"
  mkdir -p "$DIR"
  FILE="$DIR/${NAME_UPPER}.kt"

  if [[ -f "$FILE" ]]; then
    echo "⚠️  $FILE 이미 존재합니다. 건너뜁니다."
  else
    cat > "$FILE" <<KOTLIN
package ${BASE_PKG}.core.model

data class ${NAME_UPPER}(
    val id: Int,
    // TODO: 도메인 필드를 추가하세요
)
KOTLIN
    CREATED+=("$FILE")
  fi
fi

# ─── 2. core/network ───────────────────────────────────────────
if $DO_NETWORK; then
  NET_DIR="core/network/src/main/kotlin/${BASE_DIR}/core/network/api"
  mkdir -p "$NET_DIR"

  # DTO
  DTO_FILE="$NET_DIR/${NAME_UPPER}Network.kt"
  if [[ -f "$DTO_FILE" ]]; then
    echo "⚠️  $DTO_FILE 이미 존재합니다. 건너뜁니다."
  else
    cat > "$DTO_FILE" <<KOTLIN
package ${BASE_PKG}.core.network.api

import ${BASE_PKG}.core.model.${NAME_UPPER}

data class ${NAME_UPPER}sResponse(
    val ${NAME_CAMEL}s: List<${NAME_UPPER}Network>,
    val total: Int,
    val skip: Int,
    val limit: Int,
)

data class ${NAME_UPPER}Network(
    val id: Int,
    // TODO: 서버 응답 필드를 추가하세요
)

fun ${NAME_UPPER}Network.toDomain(): ${NAME_UPPER} = ${NAME_UPPER}(
    id = id,
    // TODO: 필드 매핑
)
KOTLIN
    CREATED+=("$DTO_FILE")
  fi

  # API interface
  API_FILE="$NET_DIR/${NAME_UPPER}Api.kt"
  if [[ -f "$API_FILE" ]]; then
    echo "⚠️  $API_FILE 이미 존재합니다. 건너뜁니다."
  else
    cat > "$API_FILE" <<KOTLIN
package ${BASE_PKG}.core.network.api

import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

interface ${NAME_UPPER}Api {
    @GET("${NAME_CAMEL}s")
    suspend fun get${NAME_UPPER}s(
        @Query("limit") limit: Int = 30,
        @Query("skip") skip: Int = 0,
    ): ${NAME_UPPER}sResponse

    @GET("${NAME_CAMEL}s/{id}")
    suspend fun get${NAME_UPPER}(@Path("id") id: Int): ${NAME_UPPER}Network
}
KOTLIN
    CREATED+=("$API_FILE")
  fi

  # NetworkModule에 provider 추가 안내
  echo ""
  echo "📌 NetworkModule.kt에 아래 provider를 추가하세요:"
  echo ""
  echo "    @Provides"
  echo "    @Singleton"
  echo "    fun provide${NAME_UPPER}Api(retrofit: Retrofit): ${NAME_UPPER}Api {"
  echo "        return retrofit.create(${NAME_UPPER}Api::class.java)"
  echo "    }"
  echo ""
fi

# ─── 3. core/data ──────────────────────────────────────────────
if $DO_DATA; then
  DATA_DIR="core/data/src/main/kotlin/${BASE_DIR}/core/data"
  mkdir -p "$DATA_DIR"

  REPO_FILE="$DATA_DIR/${NAME_UPPER}Repository.kt"
  if [[ -f "$REPO_FILE" ]]; then
    echo "⚠️  $REPO_FILE 이미 존재합니다. 건너뜁니다."
  else
    # network 의존 여부에 따라 import 달라짐
    if $DO_NETWORK; then
      cat > "$REPO_FILE" <<KOTLIN
package ${BASE_PKG}.core.data

import ${BASE_PKG}.core.model.${NAME_UPPER}
import ${BASE_PKG}.core.network.api.${NAME_UPPER}Api
import ${BASE_PKG}.core.network.api.toDomain
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

interface ${NAME_UPPER}Repository {
    val ${NAME_CAMEL}s: Flow<List<${NAME_UPPER}>>
}

class Default${NAME_UPPER}Repository @Inject constructor(
    private val ${NAME_CAMEL}Api: ${NAME_UPPER}Api,
) : ${NAME_UPPER}Repository {

    override val ${NAME_CAMEL}s: Flow<List<${NAME_UPPER}>>
        get() = flow {
            val response = ${NAME_CAMEL}Api.get${NAME_UPPER}s()
            emit(response.${NAME_CAMEL}s.map { it.toDomain() })
        }
}
KOTLIN
    else
      cat > "$REPO_FILE" <<KOTLIN
package ${BASE_PKG}.core.data

import ${BASE_PKG}.core.model.${NAME_UPPER}
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import javax.inject.Inject

interface ${NAME_UPPER}Repository {
    val ${NAME_CAMEL}s: Flow<List<${NAME_UPPER}>>
}

class Default${NAME_UPPER}Repository @Inject constructor(
    // TODO: 데이터 소스 주입
) : ${NAME_UPPER}Repository {

    override val ${NAME_CAMEL}s: Flow<List<${NAME_UPPER}>>
        get() = flow {
            // TODO: 데이터 로드
            emit(emptyList())
        }
}
KOTLIN
    fi
    CREATED+=("$REPO_FILE")
  fi

  # DataModule 바인딩 안내
  echo ""
  echo "📌 DataModule.kt에 아래 바인딩을 추가하세요:"
  echo ""
  echo "    @Singleton"
  echo "    @Binds"
  echo "    fun binds${NAME_UPPER}Repository("
  echo "        ${NAME_CAMEL}Repository: Default${NAME_UPPER}Repository"
  echo "    ): ${NAME_UPPER}Repository"
  echo ""
fi

# ─── 4. feature/xxx/api ───────────────────────────────────────
if $DO_FEATURE_API; then
  API_MOD_DIR="feature/${NAME_KEBAB}/api"
  API_SRC_DIR="${API_MOD_DIR}/src/main/kotlin/${BASE_DIR}/feature/${NAME_PKG}/navigation"
  mkdir -p "$API_SRC_DIR"

  # build.gradle.kts
  BUILD_FILE="${API_MOD_DIR}/build.gradle.kts"
  if [[ ! -f "$BUILD_FILE" ]]; then
    cat > "$BUILD_FILE" <<KOTLIN
plugins {
    alias(libs.plugins.template.android.feature.navigation)
}

android {
    namespace = "${BASE_PKG}.feature.${NAME_PKG}.api"

    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
    api(projects.core.navigation)
}
KOTLIN
    CREATED+=("$BUILD_FILE")
  fi

  # NavKey + Navigator extension
  NAVKEY_FILE="${API_SRC_DIR}/${NAME_UPPER}NavKey.kt"
  if [[ ! -f "$NAVKEY_FILE" ]]; then
    if [[ -n "$NAV_ARG_NAME" ]]; then
      # data class with argument
      cat > "$NAVKEY_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.navigation

import ${BASE_PKG}.core.navigation.Navigator
import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
${NAV_KEY_TYPE} ${NAME_UPPER}NavKey(val ${NAV_ARG_NAME}: ${NAV_ARG_TYPE}) : NavKey

fun Navigator.navigateTo${NAME_UPPER}(${NAV_ARG_NAME}: ${NAV_ARG_TYPE}) {
    navigate(${NAME_UPPER}NavKey(${NAV_ARG_NAME}))
}
KOTLIN
    else
      # data object (no arguments)
      cat > "$NAVKEY_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.navigation

import ${BASE_PKG}.core.navigation.Navigator
import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object ${NAME_UPPER}NavKey : NavKey

fun Navigator.navigateTo${NAME_UPPER}() {
    navigate(${NAME_UPPER}NavKey)
}
KOTLIN
    fi
    CREATED+=("$NAVKEY_FILE")
  fi

  # settings.gradle.kts에 등록
  if ! grep -q "feature:${NAME_KEBAB}:api" settings.gradle.kts; then
    # feature 블록 마지막 줄 뒤에 삽입
    LAST_FEATURE_LINE=$(grep -n 'include(":feature:' settings.gradle.kts | tail -1 | cut -d: -f1)
    if [[ -n "$LAST_FEATURE_LINE" ]]; then
      sed "${SED_INPLACE[@]}" "${LAST_FEATURE_LINE}a\\
include(\":feature:${NAME_KEBAB}:api\")" settings.gradle.kts
    else
      echo "include(\":feature:${NAME_KEBAB}:api\")" >> settings.gradle.kts
    fi
  fi
fi

# ─── 5. feature/xxx/impl ──────────────────────────────────────
if $DO_FEATURE_IMPL; then
  IMPL_MOD_DIR="feature/${NAME_KEBAB}/impl"
  UI_DIR="${IMPL_MOD_DIR}/src/main/kotlin/${BASE_DIR}/feature/${NAME_PKG}/ui"
  NAV_DIR="${IMPL_MOD_DIR}/src/main/kotlin/${BASE_DIR}/feature/${NAME_PKG}/navigation"
  TEST_DIR="${IMPL_MOD_DIR}/src/test/kotlin/${BASE_DIR}/feature/${NAME_PKG}/ui"
  mkdir -p "$UI_DIR" "$NAV_DIR" "$TEST_DIR"

  # build.gradle.kts
  IMPL_BUILD="${IMPL_MOD_DIR}/build.gradle.kts"
  if [[ ! -f "$IMPL_BUILD" ]]; then
    EXTRA_DEPS=""
    if $DO_DATA; then
      EXTRA_DEPS="    implementation(projects.core.data)
"
    fi
    cat > "$IMPL_BUILD" <<KOTLIN
plugins {
    alias(libs.plugins.template.android.feature)
}

android {
    namespace = "${BASE_PKG}.feature.${NAME_PKG}"

    defaultConfig {
        testInstrumentationRunner = "${BASE_PKG}.core.testing.HiltTestRunner"
        consumerProguardFiles("consumer-rules.pro")
    }
}

dependencies {
${EXTRA_DEPS}    implementation(projects.core.ui)
    implementation(projects.core.navigation)
    implementation(projects.feature.${NAME_CAMEL}.api)

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
KOTLIN
    CREATED+=("$IMPL_BUILD")
  fi

  # UiState + ViewModel
  VM_FILE="$UI_DIR/${NAME_UPPER}ViewModel.kt"
  if [[ ! -f "$VM_FILE" ]]; then
    if $DO_DATA; then
      cat > "$VM_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.ui

import ${BASE_PKG}.core.data.${NAME_UPPER}Repository
import ${BASE_PKG}.core.model.${NAME_UPPER}
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
class ${NAME_UPPER}ViewModel @Inject constructor(
    private val ${NAME_CAMEL}Repository: ${NAME_UPPER}Repository,
) : ViewModel() {

    val uiState: StateFlow<${NAME_UPPER}UiState> = ${NAME_CAMEL}Repository
        .${NAME_CAMEL}s
        .map<List<${NAME_UPPER}>, ${NAME_UPPER}UiState> { ${NAME_UPPER}UiState.Success(it) }
        .catch { emit(${NAME_UPPER}UiState.Error(it)) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ${NAME_UPPER}UiState.Loading)
}

sealed interface ${NAME_UPPER}UiState {
    data object Loading : ${NAME_UPPER}UiState
    data class Error(val throwable: Throwable) : ${NAME_UPPER}UiState
    data class Success(val data: List<${NAME_UPPER}>) : ${NAME_UPPER}UiState
}
KOTLIN
    else
      cat > "$VM_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.ui

import ${BASE_PKG}.core.model.${NAME_UPPER}
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class ${NAME_UPPER}ViewModel @Inject constructor() : ViewModel() {

    private val _uiState = MutableStateFlow<${NAME_UPPER}UiState>(${NAME_UPPER}UiState.Loading)
    val uiState: StateFlow<${NAME_UPPER}UiState> = _uiState.asStateFlow()

    // TODO: 데이터 로드 로직 구현
}

sealed interface ${NAME_UPPER}UiState {
    data object Loading : ${NAME_UPPER}UiState
    data class Error(val throwable: Throwable) : ${NAME_UPPER}UiState
    data class Success(val data: List<${NAME_UPPER}>) : ${NAME_UPPER}UiState
}
KOTLIN
    fi
    CREATED+=("$VM_FILE")
  fi

  # Screen
  SCREEN_FILE="$UI_DIR/${NAME_UPPER}Screen.kt"
  if [[ ! -f "$SCREEN_FILE" ]]; then
    cat > "$SCREEN_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.ui

import ${BASE_PKG}.core.model.${NAME_UPPER}
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
fun ${NAME_UPPER}Screen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: ${NAME_UPPER}ViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    ${NAME_UPPER}Content(state = uiState, modifier = modifier)
}

@Composable
private fun ${NAME_UPPER}Content(
    state: ${NAME_UPPER}UiState,
    modifier: Modifier = Modifier,
) {
    when (state) {
        is ${NAME_UPPER}UiState.Loading -> {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is ${NAME_UPPER}UiState.Error -> {
            Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(text = "Error: \${state.throwable.message}")
            }
        }
        is ${NAME_UPPER}UiState.Success -> {
            LazyColumn(
                modifier = modifier,
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(16.dp),
            ) {
                items(state.data, key = { it.id }) { item ->
                    ${NAME_UPPER}Item(item)
                }
            }
        }
    }
}

@Composable
private fun ${NAME_UPPER}Item(
    ${NAME_CAMEL}: ${NAME_UPPER},
    modifier: Modifier = Modifier,
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = "Item #\${${NAME_CAMEL}.id}",
                style = MaterialTheme.typography.titleSmall,
            )
            // TODO: 필드에 맞게 UI 구현
        }
    }
}
KOTLIN
    CREATED+=("$SCREEN_FILE")
  fi

  # Entry
  ENTRY_FILE="$NAV_DIR/${NAME_UPPER}Navigation.kt"
  if [[ ! -f "$ENTRY_FILE" ]] && $DO_FEATURE_API; then
    cat > "$ENTRY_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.navigation

import ${BASE_PKG}.core.navigation.Navigator
import ${BASE_PKG}.feature.${NAME_PKG}.ui.${NAME_UPPER}Screen
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey

@Composable
fun EntryProviderScope<NavKey>.${NAME_UPPER}Entry(navigator: Navigator) {
    entry<${NAME_UPPER}NavKey> {
        ${NAME_UPPER}Screen(
            onBack = navigator::back,
            modifier = Modifier.padding(16.dp),
        )
    }
}
KOTLIN
    CREATED+=("$ENTRY_FILE")
  fi

  # settings.gradle.kts에 등록
  if ! grep -q "feature:${NAME_KEBAB}:impl" settings.gradle.kts; then
    # api가 이미 등록되어 있으면 그 바로 뒤에, 아니면 feature 블록 마지막 뒤에
    if grep -q "feature:${NAME_KEBAB}:api" settings.gradle.kts; then
      API_LINE=$(grep -n "feature:${NAME_KEBAB}:api" settings.gradle.kts | tail -1 | cut -d: -f1)
      sed "${SED_INPLACE[@]}" "${API_LINE}a\\
include(\":feature:${NAME_KEBAB}:impl\")" settings.gradle.kts
    else
      LAST_FEATURE_LINE=$(grep -n 'include(":feature:' settings.gradle.kts | tail -1 | cut -d: -f1)
      if [[ -n "$LAST_FEATURE_LINE" ]]; then
        sed "${SED_INPLACE[@]}" "${LAST_FEATURE_LINE}a\\
include(\":feature:${NAME_KEBAB}:impl\")" settings.gradle.kts
      else
        echo "include(\":feature:${NAME_KEBAB}:impl\")" >> settings.gradle.kts
      fi
    fi
  fi
fi

# ─── 결과 요약 ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 생성 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ ${#CREATED[@]} -gt 0 ]]; then
  echo "  생성된 파일:"
  for f in "${CREATED[@]}"; do
    echo "    + $f"
  done
else
  echo "  새로 생성된 파일 없음 (모두 이미 존재)"
fi

echo ""
echo "━━━ 남은 수동 작업 ━━━"
echo ""

if $DO_NETWORK; then
  echo "  1. NetworkModule.kt에 provide${NAME_UPPER}Api() 추가"
fi
if $DO_DATA; then
  echo "  2. DataModule.kt에 binds${NAME_UPPER}Repository() 추가"
fi
if $DO_FEATURE_IMPL; then
  echo "  3. app/build.gradle.kts에 의존성 추가:"
  echo "       implementation(projects.feature.${NAME_CAMEL}.impl)"
  if $DO_FEATURE_API; then
    echo "       implementation(projects.feature.${NAME_CAMEL}.api)"
  fi
  echo "  4. app Navigation.kt의 entryProvider에 ${NAME_UPPER}Entry(navigator) 추가"
fi

echo ""
echo "  📖 자세한 절차: docs/feature-development-guide.md"
echo ""
