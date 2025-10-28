#!/bin/bash

# EC2 원격 배포 스크립트 (실무 표준)
# 사용법: ./deploy-to-ec2.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 실무 표준 설정 (EC2 사용자명 수정)
EC2_USER="${EC2_USER:-ec2-user}"  # ← 여기 수정!
EC2_HOST="${EC2_HOST}"
EC2_KEY="${EC2_KEY:-~/.ssh/wealist-key.pem}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/wealist}"  # 실무 표준 경로

# 환경 변수 확인
if [ -z "$EC2_HOST" ]; then
    echo -e "${RED}❌ EC2_HOST 환경 변수가 설정되지 않았습니다.${NC}"
    echo "사용법: EC2_HOST=your-ec2-ip ./deploy-to-ec2.sh"
    exit 1
fi

if [ ! -f "$EC2_KEY" ]; then
    echo -e "${RED}❌ SSH 키 파일을 찾을 수 없습니다: $EC2_KEY${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 EC2 원격 배포 시작 (실무 표준)...${NC}"
echo "  대상: $EC2_USER@$EC2_HOST"
echo "  배포 디렉토리: $DEPLOY_DIR"
echo ""

# .env 파일 확인
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env 파일이 없습니다.${NC}"
    exit 1
fi

# SSH 연결 테스트
echo -e "${YELLOW}📡 SSH 연결 테스트...${NC}"
ssh -i "$EC2_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "echo 'SSH 연결 성공'" || {
    echo -e "${RED}❌ SSH 연결 실패${NC}"
    exit 1
}

# 배포 디렉토리 존재 및 권한 확인
echo -e "${YELLOW}📁 배포 디렉토리 확인 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << EOF
    if [ ! -d "$DEPLOY_DIR" ]; then
        echo "❌ 배포 디렉토리가 존재하지 않습니다: $DEPLOY_DIR"
        echo "다음 명령어를 EC2에서 실행하세요:"
        echo "  sudo mkdir -p $DEPLOY_DIR"
        echo "  sudo chown $EC2_USER:$EC2_USER $DEPLOY_DIR"
        exit 1
    fi

    if [ ! -w "$DEPLOY_DIR" ]; then
        echo "❌ 배포 디렉토리에 쓰기 권한이 없습니다: $DEPLOY_DIR"
        echo "다음 명령어를 EC2에서 실행하세요:"
        echo "  sudo chown $EC2_USER:$EC2_USER $DEPLOY_DIR"
        exit 1
    fi

    echo "✅ 배포 디렉토리 준비 완료: $DEPLOY_DIR"
EOF

# 파일 전송
echo -e "${YELLOW}📤 파일 전송 중...${NC}"
scp -i "$EC2_KEY" -o StrictHostKeyChecking=no \
    docker-compose.yaml \
    .env \
    init-db.sh \
    deploy.sh \
    "$EC2_USER@$EC2_HOST:$DEPLOY_DIR/"

echo -e "${GREEN}✅ 파일 전송 완료${NC}"

# 실행 권한 부여 및 배포
echo -e "${YELLOW}🔧 배포 스크립트 실행 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << EOF
    cd $DEPLOY_DIR

    # 실행 권한 부여
    chmod +x deploy.sh init-db.sh

    echo "🚀 weAlist 배포 시작..."
    echo "📍 현재 위치: \$(pwd)"

    # 배포 실행
    ./deploy.sh

    echo ""
    echo "📊 최종 배포 상태:"
    docker compose ps

    echo ""
    echo "🔍 Health Check 수행:"

    # 서비스 준비 대기
    sleep 10

    # User Service Health Check
    if curl -f -s http://localhost:8081/health > /dev/null 2>&1; then
        echo "✅ User Service 정상 동작 (포트 8081)"
    else
        echo "❌ User Service 응답 없음"
        echo "User Service 로그:"
        docker logs wealist-user-service --tail 10
    fi

    # Kanban Service Health Check
    if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Kanban Service 정상 동작 (포트 8000)"
    else
        echo "❌ Kanban Service 응답 없음"
        echo "Kanban Service 로그:"
        docker logs wealist-kanban-service --tail 10
    fi

    # 포트 바인딩 확인
    echo ""
    echo "🔌 포트 바인딩 상태:"
    netstat -tlnp | grep -E ":800[01]" || echo "포트 8000, 8081이 바인딩되지 않았습니다."

    echo ""
    echo "📁 배포 파일 목록:"
    ls -la $DEPLOY_DIR
EOF

echo ""
echo -e "${GREEN}🎉 실무 표준 EC2 배포 완료!${NC}"
echo ""
echo "🔗 서비스 접속:"
echo "  User Service: http://$EC2_HOST:8081"
echo "  Kanban Service: http://$EC2_HOST:8000"
echo "  User Service API Docs: http://$EC2_HOST:8081/swagger-ui.html"
echo "  Kanban Service API Docs: http://$EC2_HOST:8000/docs"
echo ""
echo "📝 운영 명령어:"
echo "  로그 확인: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && docker compose logs -f'"
echo "  서비스 재시작: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && docker compose restart'"
echo "  서비스 중지: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && docker compose down'"
echo ""
echo "🔧 원격 접속:"
echo "  ssh -i $EC2_KEY $EC2_USER@$EC2_HOST"
echo "  cd $DEPLOY_DIR"
