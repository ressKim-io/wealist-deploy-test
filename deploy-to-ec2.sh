#!/bin/bash

# EC2 원격 배포 스크립트 (Docker 자동 설치 포함)
# 사용법: ./deploy-to-ec2.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 실무 표준 설정
EC2_USER="${EC2_USER:-ec2-user}"
EC2_HOST="${EC2_HOST}"
EC2_KEY="${EC2_KEY:-~/.ssh/wealist-key.pem}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/wealist}"

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

echo -e "${GREEN}🚀 EC2 원격 배포 시작 (Docker 자동 설치)...${NC}"
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

# Docker 설치 및 환경 설정
echo -e "${YELLOW}🐳 Docker 환경 설정 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << 'EOF'
    # Docker 설치 확인
    if ! command -v docker &> /dev/null; then
        echo "🔧 Docker 설치 중..."

        # Amazon Linux 2023/2 기준 Docker 설치
        sudo yum update -y
        sudo yum install -y docker

        # Docker 서비스 시작 및 자동 시작 설정
        sudo systemctl start docker
        sudo systemctl enable docker

        # 현재 사용자를 docker 그룹에 추가
        sudo usermod -a -G docker $USER

        echo "✅ Docker 설치 완료"
    else
        echo "✅ Docker 이미 설치됨"
    fi

    # Docker Compose 설치 확인
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "🔧 Docker Compose 설치 중..."

        # Docker Compose V2 플러그인 설치 (최신 방식)
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        echo "✅ Docker Compose 설치 완료"
    else
        echo "✅ Docker Compose 이미 설치됨"
    fi

    # Docker 서비스 상태 확인
    if ! sudo systemctl is-active --quiet docker; then
        echo "🔄 Docker 서비스 시작 중..."
        sudo systemctl start docker
    fi

    # Docker 권한 확인 (그룹 재로그인 없이 sudo 사용)
    echo "🔍 Docker 상태 확인:"
    sudo docker --version
    sudo docker compose version || docker-compose --version
EOF

# 배포 디렉토리 생성 및 권한 설정
echo -e "${YELLOW}📁 배포 디렉토리 설정 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << EOF
    # 배포 디렉토리 생성
    sudo mkdir -p $DEPLOY_DIR
    sudo chown $EC2_USER:$EC2_USER $DEPLOY_DIR
    sudo chmod 755 $DEPLOY_DIR

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

# deploy.sh 수정 (sudo 추가)
echo -e "${YELLOW}🔧 배포 스크립트 수정 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << 'EOF'
    cd /opt/wealist

    # deploy.sh에서 docker 명령어를 sudo docker로 수정
    sed -i 's/docker compose/sudo docker compose/g' deploy.sh
    sed -i 's/docker exec/sudo docker exec/g' deploy.sh
    sed -i 's/docker logs/sudo docker logs/g' deploy.sh

    # 실행 권한 부여
    chmod +x deploy.sh init-db.sh

    echo "✅ 배포 스크립트 수정 완료"
EOF

# 배포 실행
echo -e "${YELLOW}🚀 배포 실행 중...${NC}"
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" << 'EOF'
    cd /opt/wealist

    echo "🚀 weAlist 배포 시작..."
    echo "📍 현재 위치: $(pwd)"

    # 배포 실행
    ./deploy.sh

    echo ""
    echo "📊 최종 배포 상태:"
    sudo docker compose ps

    echo ""
    echo "🔍 Health Check 수행:"

    # 서비스 준비 대기
    sleep 15

    # User Service Health Check
    if curl -f -s http://localhost:8081/health > /dev/null 2>&1; then
        echo "✅ User Service 정상 동작 (포트 8081)"
    else
        echo "❌ User Service 응답 없음"
        echo "User Service 로그:"
        sudo docker logs wealist-user-service --tail 10
    fi

    # Kanban Service Health Check
    if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Kanban Service 정상 동작 (포트 8000)"
    else
        echo "❌ Kanban Service 응답 없음"
        echo "Kanban Service 로그:"
        sudo docker logs wealist-kanban-service --tail 10
    fi

    # 포트 바인딩 확인
    echo ""
    echo "🔌 포트 바인딩 상태:"
    netstat -tlnp | grep -E ":800[01]" || echo "포트 8000, 8081이 바인딩되지 않았습니다."

    echo ""
    echo "🐳 Docker 컨테이너 상태:"
    sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF

echo ""
echo -e "${GREEN}🎉 Docker 환경 구축 및 배포 완료!${NC}"
echo ""
echo "🔗 서비스 접속:"
echo "  User Service: http://$EC2_HOST:8081"
echo "  Kanban Service: http://$EC2_HOST:8000"
echo "  User Service API Docs: http://$EC2_HOST:8081/swagger-ui.html"
echo "  Kanban Service API Docs: http://$EC2_HOST:8000/docs"
echo ""
echo "📝 운영 명령어:"
echo "  로그 확인: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && sudo docker compose logs -f'"
echo "  서비스 재시작: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && sudo docker compose restart'"
echo "  서비스 중지: ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && sudo docker compose down'"
echo ""
echo "🔧 원격 접속:"
echo "  ssh -i $EC2_KEY $EC2_USER@$EC2_HOST"
echo "  cd $DEPLOY_DIR"
