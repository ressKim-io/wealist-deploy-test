#!/bin/bash

# EC2 원격 배포 스크립트
# 사용법: ./deploy-to-ec2.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 설정 (필요에 따라 수정)
EC2_USER="${EC2_USER:-ubuntu}"
EC2_HOST="${EC2_HOST}"
EC2_KEY="${EC2_KEY:-~/.ssh/wealist-key.pem}"
DEPLOY_DIR="${DEPLOY_DIR:-/home/ubuntu/wealist-deploy}"

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

echo -e "${GREEN}🚀 EC2 원격 배포 시작...${NC}"
echo "  대상: $EC2_USER@$EC2_HOST"
echo "  디렉토리: $DEPLOY_DIR"
echo ""

# .env 파일 확인
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env 파일이 없습니다.${NC}"
    exit 1
fi

# EC2에 배포 디렉토리 생성
echo -e "${YELLOW}📁 EC2에 배포 디렉토리 생성 중...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" "mkdir -p $DEPLOY_DIR"

# 파일 전송
echo -e "${YELLOW}📤 파일 전송 중...${NC}"
scp -i "$EC2_KEY" \
    docker-compose.yaml \
    .env \
    init-db.sh \
    deploy.sh \
    "$EC2_USER@$EC2_HOST:$DEPLOY_DIR/"

# 실행 권한 부여 및 배포
echo -e "${YELLOW}🔧 배포 스크립트 실행 중...${NC}"
ssh -i "$EC2_KEY" "$EC2_USER@$EC2_HOST" << EOF
    cd $DEPLOY_DIR
    chmod +x deploy.sh init-db.sh
    ./deploy.sh
EOF

echo ""
echo -e "${GREEN}🎉 EC2 배포 완료!${NC}"
echo ""
echo "🔗 서비스 접속:"
echo "  User Service: http://$EC2_HOST:8081"
echo "  Kanban Service: http://$EC2_HOST:8000"
echo ""
echo "📝 원격 로그 확인:"
echo "  ssh -i $EC2_KEY $EC2_USER@$EC2_HOST 'cd $DEPLOY_DIR && docker compose logs -f'"
