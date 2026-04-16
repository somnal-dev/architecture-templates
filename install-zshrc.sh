#!/usr/bin/env zsh
#
# install-zshrc.sh
# ~/.zshrc 에 `at` 명령어를 등록합니다.
#
# 사용법 (현재 쉘에 바로 적용하려면 반드시 source 로 실행):
#   source ./install-zshrc.sh
#
# 그냥 실행(`./install-zshrc.sh`)해도 ~/.zshrc 에 등록은 되지만, 현재 쉘에는
# 적용되지 않아 새 터미널을 열어야 합니다.
#
# 등록 후 원하는 디렉토리에서:
#   at
# 을 입력하면 프로젝트 폴더명, 패키지명, 데이터모델명, 앱클래스명을
# 대화형으로 물어본 뒤 현재 디렉토리에 템플릿을 복제/커스터마이즈 합니다.

set -e

# Detect whether this file is being sourced or executed.
if [[ -n "${ZSH_EVAL_CONTEXT:-}" && "$ZSH_EVAL_CONTEXT" == *:file* ]]; then
  __AT_SOURCED=1
else
  __AT_SOURCED=0
fi

ZSHRC="${ZSHRC:-$HOME/.zshrc}"
MARK_START="# >>> at >>>"
MARK_END="# <<< at <<<"

if [[ ! -f "$ZSHRC" ]]; then
  echo "Creating $ZSHRC"
  touch "$ZSHRC"
fi

if grep -q "$MARK_START" "$ZSHRC"; then
  echo "기존 at 블록을 제거하고 재설치합니다."
  # Delete the block between markers (inclusive). macOS/BSD sed 호환.
  tmp="$(mktemp)"
  awk -v s="$MARK_START" -v e="$MARK_END" '
    $0 ~ s {skip=1; next}
    $0 ~ e {skip=0; next}
    !skip {print}
  ' "$ZSHRC" > "$tmp"
  mv "$tmp" "$ZSHRC"
fi

cat >> "$ZSHRC" <<'EOF'

# >>> at >>>
# Scaffold a new Android project from somnal-dev/architecture-templates.
# Usage: run `at` in the directory where you want the new project.
at() {
  local repo_url="https://github.com/somnal-dev/architecture-templates.git"
  local project_dir projectname package datamodel appname

  echo "=== Android Architecture Template ==="

  # 1) Project folder name
  read "project_dir?Project folder name (created in current dir): "
  if [[ -z "$project_dir" ]]; then
    echo "Project folder name is required." >&2
    return 1
  fi
  if [[ -e "$project_dir" ]]; then
    echo "'$project_dir' already exists in $(pwd). Aborting." >&2
    return 1
  fi

  # 2) Gradle rootProject.name (settings.gradle.kts)
  read "projectname?Gradle project name [$project_dir]: "
  if [[ -z "$projectname" ]]; then
    projectname="$project_dir"
  fi

  # 3) Package name
  read "package?Package name (e.g. com.example.app): "
  if [[ -z "$package" ]]; then
    echo "Package name is required." >&2
    return 1
  fi

  # 4) Data model name
  read "datamodel?Data model name (e.g. Item): "
  if [[ -z "$datamodel" ]]; then
    echo "Data model name is required." >&2
    return 1
  fi

  # 5) Application class name (optional)
  read "appname?Application class name [MyApplication]: "
  if [[ -z "$appname" ]]; then
    appname="MyApplication"
  fi

  echo
  echo "Cloning template into ./$project_dir ..."
  git clone --depth 1 "$repo_url" "$project_dir" || return 1

  (
    cd "$project_dir" || exit 1

    # Drop template history so the new project starts clean.
    rm -rf .git

    if [[ ! -x ./customizer.sh ]]; then
      chmod +x ./customizer.sh
    fi

    echo
    echo "Running customizer..."
    ./customizer.sh "$package" "$datamodel" "$appname" "$projectname" || exit 1

    if [[ -x ./trim.sh ]]; then
      ./trim.sh || true
    fi
  ) || {
    echo "Setup failed. Leaving $project_dir for inspection." >&2
    return 1
  }

  echo
  echo "Done. cd $project_dir 로 이동하세요."
}
# <<< at <<<
EOF

echo "등록 완료."

if [[ "$__AT_SOURCED" == "1" ]]; then
  echo "현재 쉘에 반영 중..."
  # shellcheck disable=SC1090
  source "$ZSHRC"
  echo "적용됨. 이제 원하는 디렉토리에서 'at' 을 실행하세요."
else
  echo "현재 쉘에는 반영되지 않았습니다. 아래 중 하나를 선택하세요:"
  echo "  1) 새 터미널을 열기"
  echo "  2) source $ZSHRC 실행"
  echo "  3) 다음엔 'source ./install-zshrc.sh' 형식으로 설치하면 자동 반영됩니다."
fi

unset __AT_SOURCED
