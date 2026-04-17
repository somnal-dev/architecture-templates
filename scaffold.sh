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
ask_yn "  2. core/network    — \${API_NAME} + DTO"          && DO_NETWORK=true
ask_yn "  3. core/data       — \${REPO_NAME}"         && DO_DATA=true
ask_yn "  4. feature/${NAME_KEBAB}/api  — NavKey + Navigator 확장" && DO_FEATURE_API=true
ask_yn "  5. feature/${NAME_KEBAB}/impl — ViewModel + Screen + Entry" && DO_FEATURE_IMPL=true

echo ""

# 아무것도 선택 안 했으면 종료
if ! $DO_MODEL && ! $DO_NETWORK && ! $DO_DATA && ! $DO_FEATURE_API && ! $DO_FEATURE_IMPL; then
  echo "아무 레이어도 선택하지 않았습니다. 종료합니다."
  exit 0
fi

# ─── NavKey 및 네비게이션 설정 ────────────────────────────────
NAV_ARG_NAME=""
NAV_ARG_TYPE=""
NAV_KEY_TYPE="data object"
NAV_FUNC_NAME="navigateTo${NAME_UPPER}"

if $DO_FEATURE_API; then
  echo ""
  read -p "  나침반(navigateTo) 함수 이름을 입력하세요 (기본: $NAV_FUNC_NAME): " NAV_FUNC_INPUT
  NAV_FUNC_NAME="${NAV_FUNC_INPUT:-$NAV_FUNC_NAME}"

  read -p "  NavKey에 전달할 인자가 있나요? (예: postId:Int, 없으면 Enter): " NAV_ARG_INPUT
  if [[ -n "$NAV_ARG_INPUT" ]]; then
    NAV_ARG_NAME="$(echo "$NAV_ARG_INPUT" | cut -d: -f1 | xargs)"
    NAV_ARG_TYPE="$(echo "$NAV_ARG_INPUT" | cut -d: -f2 | xargs)"
    NAV_KEY_TYPE="data class"
  fi
fi

# ─── API 설정 (network 모듈 생성 시) ──────────────────────────
API_FUNCS=()
API_NAME="${NAME_UPPER}Api"
if $DO_NETWORK; then
  echo ""
  echo "━━━ API 설정 ━━━"
  read -p "  API 인터페이스 이름을 입력하세요 (기본: $API_NAME): " API_NAME_INPUT
  API_NAME="${API_NAME_INPUT:-$API_NAME}"

  echo ""
  echo "  API 함수를 추가하세요. (빈 줄 입력 시 종료)"
  while true; do
    read -p "  함수명 (예: get${NAME_UPPER}): " F_NAME
    [[ -z "$F_NAME" ]] && break
    read -p "  HTTP 메소드 (예: GET, POST): " F_METHOD
    read -p "  경로 (예: ${NAME_CAMEL}s/{id}): " F_PATH
    read -p "  파라미터 (예: id:Int, 없으면 빈칸): " F_PARAMS
    read -p "  반환타입 (예: ${NAME_UPPER}Network): " F_RETURN
    
    API_FUNCS+=("${F_METHOD} ${F_PATH} ${F_NAME}(${F_PARAMS}) -> ${F_RETURN}")
    echo "  → 추가됨: ${F_METHOD} ${F_PATH} ${F_NAME}(${F_PARAMS}) -> ${F_RETURN}"
    echo ""
  done

  if [[ ${#API_FUNCS[@]} -eq 0 ]]; then
    echo "  기본 API 함수를 생성합니다."
    API_FUNCS+=("GET ${NAME_CAMEL}s get${NAME_UPPER}s(limit:Int=30,skip:Int=0) -> ${NAME_UPPER}sResponse")
    API_FUNCS+=("GET ${NAME_CAMEL}s/{id} get${NAME_UPPER}(id:Int) -> ${NAME_UPPER}Network")
  fi
fi

# ─── Repository 설정 (data 모듈 생성 시) ──────────────────────
REPO_FUNCS=()
REPO_NAME="${NAME_UPPER}Repository"
if $DO_DATA; then
  echo ""
  echo "━━━ Repository 설정 ━━━"
  read -p "  Repository 인터페이스 이름을 입력하세요 (기본: $REPO_NAME): " REPO_NAME_INPUT
  REPO_NAME="${REPO_NAME_INPUT:-$REPO_NAME}"

  echo ""
  echo "  Repository 함수를 추가하세요. (빈 줄 입력 시 종료)"
  while true; do
    read -p "  함수명 (예: get${NAME_UPPER}): " F_NAME
    [[ -z "$F_NAME" ]] && break
    read -p "  파라미터 (예: id:Int, 없으면 빈칸): " F_PARAMS
    read -p "  반환타입 (예: Flow<List<${NAME_UPPER}>>, suspend ${NAME_UPPER} 등): " F_RETURN
    
    REPO_FUNCS+=("${F_NAME}(${F_PARAMS}) -> ${F_RETURN}")
    echo "  → 추가됨: ${F_NAME}(${F_PARAMS}) -> ${F_RETURN}"
    echo ""
  done

  if [[ ${#REPO_FUNCS[@]} -eq 0 ]]; then
    echo "  기본 Repository 함수를 생성합니다."
    REPO_FUNCS+=("${NAME_CAMEL}s() -> Flow<List<${NAME_UPPER}>>")
  fi
fi

# 이름 변환 및 보정 (사용자 입력 후)
REPO_NAME_CAMEL="$(echo "${REPO_NAME}" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')"
API_NAME_CAMEL="$(echo "${API_NAME}" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')"

# ─── 헬퍼 함수 정의 ───────────────────────────────────────────
_parse_repo_func() {
  local func_def="$1"
  local func_part="$(echo "$func_def" | awk -F' -> ' '{print $1}')"
  local return_part="$(echo "$func_def" | awk -F' -> ' '{print $2}')"

  local func_name="$(echo "$func_part" | sed 's/(.*//')"
  local params_str="$(echo "$func_part" | sed 's/[^(]*(\(.*\))/\1/')"
  [[ "$params_str" == "$func_part" ]] && params_str=""

  local is_suspend=false
  local return_type="$return_part"
  if [[ "$return_part" == suspend* ]]; then
    is_suspend=true
    return_type="$(echo "$return_part" | sed 's/^suspend //')"
  fi

  echo "${func_name}|${params_str}|${return_type}|${is_suspend}"
}

_gen_repo_interface_func() {
  local parsed="$(_parse_repo_func "$1")"
  IFS='|' read -r func_name params_str return_type is_suspend <<< "$parsed"

  if [[ -z "$params_str" ]]; then
    if [[ "$return_type" == Flow* ]]; then
      echo "    fun ${func_name}(): ${return_type}"
    elif [[ "$is_suspend" == "true" ]]; then
      echo "    suspend fun ${func_name}(): ${return_type}"
    else
      echo "    fun ${func_name}(): ${return_type}"
    fi
  else
    local kotlin_params=""
    IFS=',' read -ra PARAMS <<< "$params_str"
    for param in "${PARAMS[@]}"; do
      param="$(echo "$param" | xargs)"
      local p_name="$(echo "$param" | cut -d: -f1 | xargs)"
      local p_type="$(echo "$param" | cut -d: -f2 | xargs)"
      [[ -n "$kotlin_params" ]] && kotlin_params="${kotlin_params}, "
      kotlin_params="${kotlin_params}${p_name}: ${p_type}"
    done
    if [[ "$is_suspend" == "true" ]]; then
      echo "    suspend fun ${func_name}(${kotlin_params}): ${return_type}"
    else
      echo "    fun ${func_name}(${kotlin_params}): ${return_type}"
    fi
  fi
}

_gen_repo_impl_func() {
  local parsed="$(_parse_repo_func "$1")"
  IFS='|' read -r func_name params_str return_type is_suspend <<< "$parsed"

  local kotlin_params=""
  if [[ -n "$params_str" ]]; then
    IFS=',' read -ra PARAMS <<< "$params_str"
    for param in "${PARAMS[@]}"; do
      param="$(echo "$param" | xargs)"
      local p_name="$(echo "$param" | cut -d: -f1 | xargs)"
      local p_type="$(echo "$param" | cut -d: -f2 | xargs)"
      [[ -n "$kotlin_params" ]] && kotlin_params="${kotlin_params}, "
      kotlin_params="${kotlin_params}${p_name}: ${p_type}"
    done
  fi

  if [[ "$return_type" == Flow* ]]; then
    if [[ -n "$kotlin_params" ]]; then
      echo "    override fun ${func_name}(${kotlin_params}): ${return_type} = flow {"
    else
      echo "    override fun ${func_name}(): ${return_type} = flow {"
    fi
    echo "        // TODO: 데이터 로드"
    echo "        emit(emptyList())"
    echo "    }"
  elif [[ "$is_suspend" == "true" ]]; then
    if [[ -n "$kotlin_params" ]]; then
      echo "    override suspend fun ${func_name}(${kotlin_params}): ${return_type} {"
    else
      echo "    override suspend fun ${func_name}(): ${return_type} {"
    fi
    echo "        // TODO: 구현"
    echo "    }"
  else
    if [[ -n "$kotlin_params" ]]; then
      echo "    override fun ${func_name}(${kotlin_params}): ${return_type} {"
    else
      echo "    override fun ${func_name}(): ${return_type} {"
    fi
    echo "        // TODO: 구현"
    echo "    }"
  fi
}

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
  API_FILE="$NET_DIR/${API_NAME}.kt"
  if [[ -f "$API_FILE" ]]; then
    echo "⚠️  $API_FILE 이미 존재합니다. 건너뜁니다."
  else
    # API 함수 파싱 및 생성
    _gen_api_imports() {
      local needs_path=false needs_query=false needs_body=false needs_post=false needs_put=false needs_delete=false
      for func_def in "${API_FUNCS[@]}"; do
        local http_method="$(echo "$func_def" | awk '{print toupper($1)}')"
        local path="$(echo "$func_def" | awk '{print $2}')"
        local func_part="$(echo "$func_def" | awk '{print $3}')"
        [[ "$path" == *"{"* ]] && needs_path=true
        # Query/Body 파라미터 분석
        local params_str="$(echo "$func_part" | sed 's/.*(\(.*\))/\1/')"
        if [[ -n "$params_str" && "$params_str" != "$func_part" ]]; then
          case "$http_method" in
            POST|PUT|PATCH)
              [[ "$path" == *"{"* ]] && needs_path=true
              needs_body=true ;;
            *)
              [[ "$params_str" != *"{"* ]] && needs_query=true ;;
          esac
        fi
        case "$http_method" in
          POST)   needs_post=true ;;
          PUT)    needs_put=true ;;
          DELETE) needs_delete=true ;;
        esac
      done
      echo "import retrofit2.http.GET"
      $needs_post && echo "import retrofit2.http.POST"
      $needs_put && echo "import retrofit2.http.PUT"
      $needs_delete && echo "import retrofit2.http.DELETE"
      $needs_body && echo "import retrofit2.http.Body"
      $needs_path && echo "import retrofit2.http.Path"
      $needs_query && echo "import retrofit2.http.Query"
    }

    _gen_api_func() {
      local func_def="$1"
      local http_method="$(echo "$func_def" | awk '{print toupper($1)}')"
      local path="$(echo "$func_def" | awk '{print $2}')"
      local func_part="$(echo "$func_def" | awk '{print $3}')"
      local return_type="$(echo "$func_def" | awk -F' -> ' '{print $2}')"

      local func_name="$(echo "$func_part" | sed 's/(.*//')"
      local params_str="$(echo "$func_part" | sed 's/[^(]*(\(.*\))/\1/')"

      echo "    @${http_method}(\"${path}\")"
      echo -n "    suspend fun ${func_name}("

      if [[ -n "$params_str" && "$params_str" != "$func_part" ]]; then
        echo ""
        IFS=',' read -ra PARAMS <<< "$params_str"
        local param_count=${#PARAMS[@]}
        local idx=0
        for param in "${PARAMS[@]}"; do
          idx=$((idx + 1))
          param="$(echo "$param" | xargs)"
          local p_name="$(echo "$param" | cut -d: -f1 | xargs)"
          local p_type_default="$(echo "$param" | cut -d: -f2 | xargs)"
          local p_type="$(echo "$p_type_default" | cut -d= -f1 | xargs)"
          local p_default=""
          if [[ "$p_type_default" == *"="* ]]; then
            p_default=" = $(echo "$p_type_default" | cut -d= -f2 | xargs)"
          fi

          # Path 파라미터인지 확인
          if [[ "$path" == *"{${p_name}}"* ]]; then
            local trailing=","
            [[ $idx -eq $param_count ]] && trailing=""
            echo "        @Path(\"${p_name}\") ${p_name}: ${p_type}${p_default}${trailing}"
          elif [[ "$http_method" == "POST" || "$http_method" == "PUT" || "$http_method" == "PATCH" ]] && [[ "$path" != *"{${p_name}}"* && "$p_name" == "body" || "$p_type" == *"Request"* ]]; then
            local trailing=","
            [[ $idx -eq $param_count ]] && trailing=""
            echo "        @Body ${p_name}: ${p_type}${p_default}${trailing}"
          else
            local trailing=","
            [[ $idx -eq $param_count ]] && trailing=""
            echo "        @Query(\"${p_name}\") ${p_name}: ${p_type}${p_default}${trailing}"
          fi
        done
        echo "    ): ${return_type}"
      else
        echo "): ${return_type}"
      fi
    }

    {
      echo "package ${BASE_PKG}.core.network.api"
      echo ""
      _gen_api_imports
      echo ""
      echo "interface ${API_NAME} {"
      FUNC_IDX=0
      for func_def in "${API_FUNCS[@]}"; do
        if [[ $FUNC_IDX -gt 0 ]]; then echo ""; fi
        _gen_api_func "$func_def"
        FUNC_IDX=$((FUNC_IDX + 1))
      done
      echo "}"
    } > "$API_FILE"
    CREATED+=("$API_FILE")
  fi

  # NetworkModule에 provider 추가 안내
  echo ""
  echo "📌 NetworkModule.kt에 아래 provider를 추가하세요:"
  echo ""
  echo "    @Provides"
  echo "    @Singleton"
  echo "    fun provide${API_NAME}(retrofit: Retrofit): ${API_NAME} {"
  echo "        return retrofit.create(${API_NAME}::class.java)"
  echo "    }"
  echo ""
fi

# ─── 3. core/data ──────────────────────────────────────────────
if $DO_DATA; then
  DATA_DIR="core/data/src/main/kotlin/${BASE_DIR}/core/data"
  mkdir -p "$DATA_DIR"

  REPO_FILE="$DATA_DIR/${REPO_NAME}.kt"
  if [[ -f "$REPO_FILE" ]]; then
    echo "⚠️  $REPO_FILE 이미 존재합니다. 건너뜁니다."
  else
    # import 결정
    NEEDS_FLOW=false
    for repo_func in "${REPO_FUNCS[@]}"; do
      [[ "$repo_func" == *"Flow"* ]] && NEEDS_FLOW=true
    done

    {
      echo "package ${BASE_PKG}.core.data"
      echo ""
      echo "import ${BASE_PKG}.core.model.${NAME_UPPER}"
      if $DO_NETWORK; then
        echo "import ${BASE_PKG}.core.network.api.${API_NAME}"
        echo "import ${BASE_PKG}.core.network.api.toDomain"
      fi
      if $NEEDS_FLOW; then
        echo "import kotlinx.coroutines.flow.Flow"
        echo "import kotlinx.coroutines.flow.flow"
      fi
      echo "import javax.inject.Inject"
      echo ""
      echo "interface ${REPO_NAME} {"
      FUNC_IDX=0
      for repo_func in "${REPO_FUNCS[@]}"; do
        [[ $FUNC_IDX -gt 0 ]] && echo ""
        _gen_repo_interface_func "$repo_func"
        FUNC_IDX=$((FUNC_IDX + 1))
      done
      echo "}"
      echo ""
      if $DO_NETWORK; then
        echo "class Default${REPO_NAME} @Inject constructor("
        echo "    private val ${API_NAME_CAMEL}: ${API_NAME},"
        echo ") : ${REPO_NAME} {"
      else
        echo "class Default${REPO_NAME} @Inject constructor("
        echo "    // TODO: 데이터 소스 주입"
        echo ") : ${REPO_NAME} {"
      fi
      echo ""
      func_idx=0
      for repo_func in "${REPO_FUNCS[@]}"; do
        [[ $func_idx -gt 0 ]] && echo ""
        _gen_repo_impl_func "$repo_func"
        func_idx=$((func_idx + 1))
      done
      echo "}"
    } > "$REPO_FILE"
    CREATED+=("$REPO_FILE")
  fi

  # DataModule 바인딩 안내
  echo ""
  echo "📌 DataModule.kt에 아래 바인딩을 추가하세요:"
  echo ""
  echo "    @Singleton"
  echo "    @Binds"
  echo "    fun binds${REPO_NAME}("
  echo "        ${REPO_NAME_CAMEL}: Default${REPO_NAME}"
  echo "    ): ${REPO_NAME}"
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

fun Navigator.${NAV_FUNC_NAME}(${NAV_ARG_NAME}: ${NAV_ARG_TYPE}) {
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

fun Navigator.${NAV_FUNC_NAME}() {
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
    # 첫 번째 Flow 타입 repo 함수를 ViewModel에 연결
    FIRST_FLOW_FUNC=""
    if $DO_DATA; then
      for repo_func in "${REPO_FUNCS[@]}"; do
        if [[ "$repo_func" == *"Flow"* ]]; then
          PARSED="$(_parse_repo_func "$repo_func")"
          IFS='|' read -r fn_name fn_params fn_return fn_suspend <<< "$PARSED"
          if [[ -z "$fn_params" ]]; then
            FIRST_FLOW_FUNC="$fn_name"
          fi
          break
        fi
      done
    fi

    if $DO_DATA && [[ -n "$FIRST_FLOW_FUNC" ]]; then
      cat > "$VM_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.ui

import ${BASE_PKG}.core.data.${REPO_NAME}
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
    private val ${REPO_NAME_CAMEL}: ${REPO_NAME},
) : ViewModel() {

    val uiState: StateFlow<${NAME_UPPER}UiState> = ${REPO_NAME_CAMEL}
        .${FIRST_FLOW_FUNC}()
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
      if $DO_DATA; then
        cat > "$VM_FILE" <<KOTLIN
package ${BASE_PKG}.feature.${NAME_PKG}.ui

import ${BASE_PKG}.core.data.${REPO_NAME}
import ${BASE_PKG}.core.model.${NAME_UPPER}
import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@HiltViewModel
class ${NAME_UPPER}ViewModel @Inject constructor(
    private val ${REPO_NAME_CAMEL}: ${REPO_NAME},
) : ViewModel() {

    private val _uiState = MutableStateFlow<${NAME_UPPER}UiState>(${NAME_UPPER}UiState.Loading)
    val uiState: StateFlow<${NAME_UPPER}UiState> = _uiState.asStateFlow()

    // TODO: repository 함수를 호출하여 데이터 로드
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
KOTLIN
      fi
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

# ─── App 모듈 통합 ─────────────────────────────────────────────
if $DO_FEATURE_API || $DO_FEATURE_IMPL; then
  APP_BUILD="app/build.gradle.kts"
  if [[ -f "$APP_BUILD" ]]; then
    echo "📌 $APP_BUILD 에 의존성을 추가합니다..."
    
    # dependencies { 블록 찾기 (projects.core.navigation 뒤에 삽입)
    if $DO_FEATURE_API && ! grep -q "projects.feature.${NAME_KEBAB}.api" "$APP_BUILD"; then
       sed "${SED_INPLACE[@]}" "/projects.core.navigation/a\\
    implementation(projects.feature.${NAME_KEBAB}.api)" "$APP_BUILD"
    fi
    if $DO_FEATURE_IMPL && ! grep -q "projects.feature.${NAME_KEBAB}.impl" "$APP_BUILD"; then
       sed "${SED_INPLACE[@]}" "/projects.core.navigation/a\\
    implementation(projects.feature.${NAME_KEBAB}.impl)" "$APP_BUILD"
    fi
  fi

  NAV_FILE="app/src/main/kotlin/${BASE_DIR}/ui/Navigation.kt"
  if [[ -f "$NAV_FILE" ]]; then
    echo "📌 $NAV_FILE 에 Navigation Entry를 등록합니다..."
    
    # Import 추가. (PostEntry import 뒤에 삽입)
    if ! grep -q ".feature.${NAME_PKG}.navigation.${NAME_UPPER}Entry" "$NAV_FILE"; then
       sed "${SED_INPLACE[@]}" "/import.*feature.post.navigation.PostEntry/a\\
import ${BASE_PKG}.feature.${NAME_PKG}.navigation.${NAME_UPPER}Entry" "$NAV_FILE"
    fi
    
    # entryProvider { 블록 안에 추가
    if ! grep -q "${NAME_UPPER}Entry(navigator = navigator)" "$NAV_FILE"; then
       sed "${SED_INPLACE[@]}" "/entryProvider {/a\\
            ${NAME_UPPER}Entry(navigator = navigator)" "$NAV_FILE"
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
  echo "  1. NetworkModule.kt에 provide${API_NAME}() 추가"
fi
if $DO_DATA; then
  echo "  2. DataModule.kt에 binds${REPO_NAME}() 추가"
fi
if $DO_FEATURE_IMPL; then
  echo "  (의존성 및 Navigation Entry 등록은 자동으로 시도되었습니다.)"
  echo "  3. app/build.gradle.kts 확인"
  echo "  4. app Navigation.kt 확인"
fi

echo ""
echo "  📖 자세한 절차: docs/feature-development-guide.md"
echo ""
