#!/usr/bin/env tsx
/**
 * install-zshrc.ts
 * ~/.zshrc 에 `at` 명령어를 등록합니다.
 *
 * 사용법:
 *   yarn install-zshrc
 *
 * 등록 후 원하는 디렉토리에서:
 *   at
 * 을 입력하면 프로젝트 폴더명, 패키지명, 데이터모델명을
 * 대화형으로 물어본 뒤 현재 디렉토리에 템플릿을 복제/커스터마이즈 합니다.
 */
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const MARK_START = '# >>> at >>>';
const MARK_END = '# <<< at <<<';

const AT_BLOCK = `
${MARK_START}
# Scaffold a new Android project from somnal-dev/architecture-templates.
# Usage: run \`at\` in the directory where you want the new project.
at() {
  local repo_url="https://github.com/somnal-dev/architecture-templates.git"
  local project_dir projectname package datamodel

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

  echo
  echo "Cloning template into ./$project_dir ..."
  git clone --depth 1 "$repo_url" "$project_dir" || return 1

  (
    cd "$project_dir" || exit 1

    # Drop template history so the new project starts clean.
    rm -rf .git

    echo
    echo "Installing dependencies..."
    yarn install || exit 1

    echo
    echo "Running setup..."
    yarn setup "$package" "$datamodel" "$projectname" || exit 1

    yarn clean || true
  ) || {
    echo "Setup failed. Leaving $project_dir for inspection." >&2
    return 1
  }

  echo
  echo "Done. cd $project_dir 로 이동하세요."
}
${MARK_END}
`;

function main() {
  const zshrcPath = process.env.ZSHRC ?? path.join(os.homedir(), '.zshrc');

  if (!fs.existsSync(zshrcPath)) {
    console.log(`Creating ${zshrcPath}`);
    fs.writeFileSync(zshrcPath, '');
  }

  let content = fs.readFileSync(zshrcPath, 'utf-8');

  if (content.includes(MARK_START)) {
    console.log('기존 at 블록을 제거하고 재설치합니다.');
    const lines = content.split('\n');
    const result: string[] = [];
    let skip = false;
    for (const line of lines) {
      if (line.includes(MARK_START)) { skip = true; continue; }
      if (line.includes(MARK_END))   { skip = false; continue; }
      if (!skip) result.push(line);
    }
    content = result.join('\n');
  }

  fs.writeFileSync(zshrcPath, content + AT_BLOCK);
  console.log('등록 완료.');
  console.log('아래 중 하나를 선택하세요:');
  console.log('  1) 새 터미널을 열기');
  console.log(`  2) source ${zshrcPath} 실행`);
}

main();
