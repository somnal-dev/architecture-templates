#!/usr/bin/env tsx
/**
 * yarn finish - 템플릿 기능 제거하고 순수 안드로이드 프로젝트로 변환
 */

import { execSync } from 'child_process'
import { existsSync, rmSync, readFileSync, writeFileSync } from 'fs'
import { join } from 'path'

interface FileToRemove {
  path: string
  reason: string
}

const ROOT = process.cwd()

// 제거할 파일들 정의
const FILES_TO_REMOVE: FileToRemove[] = [
  // Node.js/TypeScript 관련
  { path: 'package.json', reason: 'npm/yarn 패키지 관리 파일' },
  { path: 'yarn.lock', reason: '의존성 잠금 파일' },
  { path: 'pnpm-lock.yaml', reason: 'pnpm 의존성 파일' },
  { path: 'tsconfig.json', reason: 'TypeScript 설정 파일' },
  { path: '.env', reason: '환경 변수 파일' },
  { path: '.pnp.cjs', reason: 'Yarn PnP 설정' },
  { path: '.pnp.loader.mjs', reason: 'Yarn PnP 로더' },
  { path: '.yarn', reason: 'Yarn �시 디렉토리' },
  { path: '.yarnrc.yml', reason: 'Yarn 설정 파일' },
  { path: '.yarn/cache', reason: 'Yarn �시' },
  { path: '.yarn/unplugged', reason: 'Yarn 언플러그드 패키지' },
  { path: '.yarn/install-state.gz', reason: 'Yarn 설치 상태' },

  // 스크립트 폴더 전체
  { path: 'scripts', reason: '템플릿 생성 스크립트들' },

  // 빌드 로직 (템플릿용) - 남기기: build-logic은 각 모듈의 build.gradle.kts에서 사용 중
  // { path: 'build-logic', reason: '템플릿 전용 빌드 로직' },

  // 템플릿 문서들
  { path: 'CLAUDE.md', reason: 'Claude Code 템플릿 가이드' },
  { path: 'CONTRIBUTING.md', reason: '기여 가이드' },
  { path: 'local.properties', reason: '로컬 개발 환경 설정' },
]

// 제거할 파일들 정의 (패턴)
const PATTERNS_TO_REMOVE: FileToRemove[] = [
  { path: '.DS_Store', reason: 'macOS 시스템 파일' },
]

// README 업데이트 내용
const NEW_README_CONTENT = `# Android Application

이 프로젝트는 안드로이드 애플리케이션입니다.

## 프로젝트 구조

\`\`\`
multimodule-template/
├── app/                    # 메인 앱 모듈
├── core/
│   ├── data/              # 데이터 계층 (Repository)
│   ├── database/          # Room 데이터베이스
│   ├── model/             # 도메인 모델
│   ├── navigation/         # Jetpack Navigation
│   ├── network/           # 네트워크 레이어 (Retrofit)
│   ├── testing/          # 테스트 유틸리티
│   └── ui/               # UI 컴포넌트
├── gradle/               # Gradle 설정
├── build.gradle.kts       # 프로젝트 루트 빌드 파일
├── settings.gradle.kts    # 프로젝트 설정
└── gradle.properties      # Gradle 속성
\`\`\`

## 빌드 및 실행

\`\`\`bash
# Debug 빌드
./gradlew assembleDebug

# Release 빌드
./gradlew assembleRelease

# 앱 설치
./gradlew installDebug

# 테스트 실행
./gradlew test
\`\`\`

## 아키텍처

이 프로젝트는 Now in Android 아키텍처를 기반으로 합니다.

- Clean Architecture
- Single Source of Truth
- Unidirectional Data Flow
- Coroutines & Flow
- Jetpack Compose
- Hilt for DI

## 라이선스

Copyright ${new Date().getFullYear()} The Android Open Source Project

Licensed under the Apache License, Version 2.0
`

// 제거할 Gradle 설정 (템플릿용)
const GRADLE_PROPERTIES_TO_REMOVE = [
  'rootProject.name',
]

function removeFile(filePath: string): void {
  const fullPath = join(ROOT, filePath)

  if (!existsSync(fullPath)) {
    console.log(`⏭️  건너뜀기: ${filePath} (존재하지 않음)`)
    return
  }

  try {
    rmSync(fullPath, { recursive: true, force: true })
    console.log(`✅ 삭제됨: ${filePath}`)
  } catch (error) {
    console.error(`❌ 삭제 실패: ${filePath}`, error)
  }
}

function updateSettingsGradle(): void {
  const settingsPath = join(ROOT, 'settings.gradle.kts')

  if (!existsSync(settingsPath)) {
    console.log('⏭️  settings.gradle.kts 존재하지 않음')
    return
  }

  const content = readFileSync(settingsPath, 'utf-8')

  // rootProject.name 업데이트 (includeBuild("build-logic")은 유지)
  const updatedContent = content.replace(
    /rootProject\.name\s*=\s*"[^"]+"/g,
    'rootProject.name = "app"'
  )

  writeFileSync(settingsPath, updatedContent, 'utf-8')
  console.log('✅ settings.gradle.kts 업데이트됨')
}

function updateReadme(): void {
  const readmePath = join(ROOT, 'README.md')
  writeFileSync(readmePath, NEW_README_CONTENT, 'utf-8')
  console.log('✅ README.md 업데이트됨')
}

function cleanGradle(): void {
  try {
    console.log('🧹 Gradle �시 정리 중...')
    execSync('./gradlew clean', { stdio: 'inherit' })
    console.log('✅ Gradle �시 정리됨')
  } catch (error) {
    console.error('⚠️  Gradle 정리 중 오류 발생 (계속 진행)')
  }
}

function main(): void {
  console.log('🚀 안드로이드 프로젝트로 변환 시작...\n')

  // 파일 제거
  console.log('📁 파일 및 디렉토리 제거:')
  FILES_TO_REMOVE.forEach(({ path }) => removeFile(path))

  // .DS_Store 파일들 제거
  PATTERNS_TO_REMOVE.forEach(({ path }) => removeFile(path))

  console.log('\n⚙️  설정 파일 업데이트:')

  // settings.gradle.kts 업데이트
  updateSettingsGradle()

  // README.md 업데이트
  updateReadme()

  // Gradle �시 정리
  console.log('\n🧹 빌드 아티팩트 정리:')
  cleanGradle()

  console.log('\n✨ 완료!')
  console.log('\n이제 이 프로젝트는 순수 안드로이드 앱 프로젝트입니다.')
  console.log('다음 명령어로 빌드할 수 있습니다:')
  console.log('  ./gradlew assembleDebug')
}

main()
