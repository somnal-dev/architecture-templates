# 개발 문서

이 디렉토리는 프로젝트 개발 시 참고할 가이드를 모아둔 곳입니다.

| 문서 | 설명 |
|---|---|
| [feature-development-guide.md](./feature-development-guide.md) | 새 기능(화면/도메인) 추가 시 단계별 절차. 모듈 구조, 네이밍, 자주 하는 실수 포함. |
| [database-development-guide.md](./database-development-guide.md) | `core:database` — Room Entity/Dao 추가, 마이그레이션, 스키마 커밋 규칙. |
| [datastore-development-guide.md](./datastore-development-guide.md) | `core:datastore` — Preferences DataStore 키 추가, Repository 연동, 마이그레이션. |
| [test-writing-guide.md](./test-writing-guide.md) | JVM 단위 테스트, Compose UI 테스트, E2E 테스트 작성법과 실행 명령어. |

처음 시작할 때는 `feature-development-guide.md` → `database-development-guide.md` / `datastore-development-guide.md` → `test-writing-guide.md` 순서로 읽는 것을 권장합니다.
