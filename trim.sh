#!/usr/bin/env bash

# 프로젝트 내부의 모든 빈 디렉토리(폴더)를 찾아 삭제합니다.
# Git에서 추적하지 않는(빈 폴더) 잔여 찌꺼기 폴더를 정리하는 데 유용합니다.

echo "빈 폴더 정리를 시작합니다..."

# -empty: 비어있는 항목
# -type d: 디렉토리(폴더)만 대상
# -delete: 찾은 항목 삭제
# 2>/dev/null: 권한 없음 등의 에러 메시지 숨김
find . -type d -empty -delete 2>/dev/null

echo "정리가 완료되었습니다!"
