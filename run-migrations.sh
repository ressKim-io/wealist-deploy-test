#!/bin/bash

# 마이그레이션 실행 스크립트
set -e

echo "🔄 데이터베이스 마이그레이션 시작..."

# Kanban Service 마이그레이션 실행
echo "📦 Kanban Service 마이그레이션 실행 중..."
docker compose run --rm kanban-service alembic upgrade head

# User Service는 첫 실행 시 수동으로 스키마 생성 필요
echo "⚠️  User Service 스키마는 수동으로 생성해야 합니다."
echo "   1. JPA_DDL_AUTO=update로 한 번 실행하거나"
echo "   2. SQL 스크립트를 직접 실행하세요"

echo "✅ 마이그레이션 완료!"
