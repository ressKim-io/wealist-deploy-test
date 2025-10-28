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

# 환경 변수 로드
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env 파일이 없습니다. .env.example을 복사하여 .env를 생성하세요.${NC}"
    exit 1
fi

# .env 파일 로드
export $(grep -v '^#' .env | xargs)

# 이미지 태그 환경 변수 설정 (기본값: latest)
export USER_IMAGE_TAG=${USER_IMAGE_TAG:-latest}
export KANBAN_IMAGE_TAG=${KANBAN_IMAGE_TAG:-latest}

# Docker 이미지 Pull
echo -e "${YELLOW}📦 최신 Docker 이미지를 가져오는 중...${NC}"
docker compose pull

# 기존 컨테이너 정지 및 제거
echo -e "${YELLOW}🛑 기존 컨테이너 정지 중...${NC}"
docker compose down

# DB만 먼저 시작
echo -e "${YELLOW}🗄️  데이터베이스 시작 중...${NC}"
docker compose up -d postgres redis

# DB 준비 대기 (더 길게)
echo -e "${YELLOW}⏳ 데이터베이스 준비 대기 중 (15초)...${NC}"
sleep 15

# PostgreSQL 연결 확인
echo -e "${YELLOW}🔍 PostgreSQL 연결 확인 중...${NC}"
while ! docker exec wealist-postgres pg_isready -U postgres > /dev/null 2>&1; do
    echo "PostgreSQL 대기 중..."
    sleep 2
done
echo -e "${GREEN}✅ PostgreSQL 준비 완료${NC}"

# Kanban Service 마이그레이션 실행
echo -e "${YELLOW}🔄 Kanban Service 마이그레이션 실행 중...${NC}"
docker compose run --rm kanban-service alembic upgrade head || {
    echo -e "${YELLOW}⚠️  마이그레이션 실패 또는 이미 최신 상태입니다.${NC}"
}

# 서비스 시작
echo -e "${YELLOW}🚀 서비스 시작 중...${NC}"
docker compose up -d

# 서비스 시작 후 상태 확인
echo -e "${YELLOW}📊 컨테이너 상태 확인...${NC}"
docker compose ps
echo -e "${YELLOW}📝 최근 로그 확인...${NC}"
docker compose logs --tail 5 user-service
docker compose logs --tail 5 kanban-service

# Health check 함수
check_service_health() {
    local service_name=$1
    local url=$2
    local max_retry=${3:-15}
    local retry=0

    echo "${service_name} 상태 확인 중..."
    while [ $retry -lt $max_retry ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ ${service_name} 정상 동작${NC}"
            return 0
        fi
        retry=$((retry+1))
        echo "${service_name} 재시도 중... ($retry/$max_retry)"
        sleep 3
    done

    echo -e "${RED}❌ ${service_name} 응답 없음 - 로그 확인${NC}"
    return 1
}

# Health check 수행
echo -e "${YELLOW}🏥 Health check 수행 중...${NC}"

# User Service health check (경로 수정)
if ! check_service_health "User Service" "http://localhost:8081/health" 15; then
    docker logs wealist-user-service --tail 20
    exit 1 # User Service health check 실패 시 배포 중단
fi

# Kanban Service health check
if ! check_service_health "Kanban Service" "http://localhost:8000/health" 10; then
    docker logs wealist-kanban-service --tail 20
    exit 1 # Kanban Service health check 실패 시 배포 중단
fi

# PostgreSQL health check
if docker exec wealist-postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL 정상 동작${NC}"
else
    echo -e "${RED}❌ PostgreSQL 응답 없음${NC}"
    docker logs wealist-postgres --tail 10
fi

# Redis health check (환경변수 직접 사용)
if docker exec wealist-redis redis-cli -a "${REDIS_PASSWORD}" ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis 정상 동작${NC}"
else
    echo -e "${RED}❌ Redis 응답 없음${NC}"
    docker logs wealist-redis --tail 10
fi

echo ""
echo -e "${GREEN}🎉 배포 완료!${NC}"
echo ""
echo "📊 서비스 상태 확인:"
docker compose ps

echo ""
echo "🌐 서비스 접속 URL:"
echo "  User Service: http://localhost:8081/swagger-ui.html"
echo "  Kanban Service: http://localhost:8000/docs"
echo ""
echo "📝 로그 확인:"
echo "  docker compose logs -f user-service"
echo "  docker compose logs -f kanban-service"
