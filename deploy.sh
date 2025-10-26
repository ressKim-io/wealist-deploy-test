#!/bin/bash

# weAlist EC2 배포 스크립트
# 사용법: ./deploy.sh

set -e

echo "🚀 weAlist 배포 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 환경 변수 확인
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env 파일이 없습니다. .env.example을 복사하여 .env를 생성하세요.${NC}"
    exit 1
fi

# Docker 이미지 Pull
echo -e "${YELLOW}📦 최신 Docker 이미지를 가져오는 중...${NC}"
docker compose pull

# 기존 컨테이너 정지 및 제거
echo -e "${YELLOW}🛑 기존 컨테이너 정지 중...${NC}"
docker compose down

# DB만 먼저 시작
echo -e "${YELLOW}🗄️  데이터베이스 시작 중...${NC}"
docker compose up -d postgres redis

# DB 준비 대기
echo -e "${YELLOW}⏳ 데이터베이스 준비 대기 중 (10초)...${NC}"
sleep 10

# Kanban Service 마이그레이션 실행
echo -e "${YELLOW}🔄 Kanban Service 마이그레이션 실행 중...${NC}"
docker compose run --rm kanban-service alembic upgrade head || {
    echo -e "${YELLOW}⚠️  마이그레이션 실패 또는 이미 최신 상태입니다.${NC}"
}

# 서비스 시작
echo -e "${YELLOW}🚀 서비스 시작 중...${NC}"
docker compose up -d

# 컨테이너 준비 대기
echo -e "${YELLOW}⏳ 서비스 준비 대기 중 (30초)...${NC}"
sleep 30

# Health check
echo -e "${YELLOW}🏥 Health check 수행 중...${NC}"

# User Service health check
if curl -f http://localhost:8081/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ User Service 정상 동작${NC}"
else
    echo -e "${RED}❌ User Service 응답 없음${NC}"
fi

# Kanban Service health check
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Kanban Service 정상 동작${NC}"
else
    echo -e "${RED}❌ Kanban Service 응답 없음${NC}"
fi

# PostgreSQL health check
if docker exec wealist-postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL 정상 동작${NC}"
else
    echo -e "${RED}❌ PostgreSQL 응답 없음${NC}"
fi

# Redis health check
if docker exec wealist-redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis 정상 동작${NC}"
else
    echo -e "${RED}❌ Redis 응답 없음${NC}"
fi

echo ""
echo -e "${GREEN}🎉 배포 완료!${NC}"
echo ""
echo "📊 서비스 상태 확인:"
docker compose ps

echo ""
echo "📝 로그 확인:"
echo "  docker compose logs -f user-service"
echo "  docker compose logs -f kanban-service"
