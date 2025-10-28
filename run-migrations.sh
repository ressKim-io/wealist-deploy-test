#!/bin/bash

# 마이그레이션 실행 스크립트
set -e

echo "🔄 데이터베이스 마이그레이션 시작..."

# Kanban Service 마이그레이션 실행
echo "📦 Kanban Service 마이그레이션 실행 중..."
docker compose run --rm kanban-service alembic upgrade head

# User Service는 현재 JPA_DDL_AUTO 또는 수동 SQL 스크립트를 사용합니다.
# 클라우드 네이티브 환경에서는 Flyway나 Liquibase와 같은 전용 마이그레이션 도구 사용을 권장합니다.
# (예: User Service에 Flyway 통합 후 여기에 Flyway 마이그레이션 명령 추가)

echo "✅ 마이그레이션 완료!"
