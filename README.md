# weAlist Deploy

weAlist 프로젝트의 중앙 집중식 배포 저장소입니다.

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [사전 요구사항](#사전-요구사항)
- [빠른 시작](#빠른-시작)
- [배포 가이드](#배포-가이드)
- [GitHub Actions 설정](#github-actions-설정)
- [트러블슈팅](#트러블슈팅)

## 개요

weAlist는 Jira 스타일의 프로젝트 관리 플랫폼으로, 마이크로서비스 아키텍처로 구성되어 있습니다.

### 서비스 구성

- **weAlist-User** (Spring Boot/Java) - 사용자 인증 및 관리
- **weAlist-Board** (FastAPI/Python) - 프로젝트 및 작업 관리
- **PostgreSQL** - 통합 데이터베이스 (DB 분리)
- **Redis** - 공유 캐시 (논리 DB 분리)

## 아키텍처

### 배포 플로우

```
┌─────────────────┐         ┌─────────────────┐
│  weAlist-User   │         │ weAlist-Board   │
│   Repository    │         │   Repository    │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ Git Push (main)          │ Git Push (main)
         │                           │
         ▼                           ▼
    ┌────────────┐             ┌────────────┐
    │ GitHub     │             │ GitHub     │
    │ Actions    │             │ Actions    │
    └─────┬──────┘             └─────┬──────┘
          │                          │
          │ Build & Push Image      │ Build & Push Image
          │                          │
          ▼                          ▼
    ┌──────────────────────────────────┐
    │       Docker Hub                 │
    │  ressbe/wealist-user:latest     │
    │  ressbe/wealist-board:latest    │
    └────────────┬─────────────────────┘
                 │
                 │ Pull Images
                 │
                 ▼
    ┌─────────────────────────────┐
    │   wealist-deploy            │
    │   (이 저장소)                │
    ├─────────────────────────────┤
    │ - Integration Test          │
    │ - Deploy to EC2             │
    └──────────────┬──────────────┘
                   │
                   │ Deploy
                   │
                   ▼
              ┌──────────┐
              │   EC2    │
              └──────────┘
```

### 인프라 구성

```
┌─────────────────────────────────────────────┐
│              EC2 Instance                   │
│                                             │
│  ┌──────────────┐      ┌─────────────────┐│
│  │ User Service │      │ Kanban Service  ││
│  │   :8081      │      │     :8000       ││
│  └──────┬───────┘      └────────┬────────┘│
│         │                       │         │
│         └───────────┬───────────┘         │
│                     │                     │
│  ┌──────────────────┴─────────────────┐  │
│  │    PostgreSQL :5432                │  │
│  │  ├─ wealist_user_db                │  │
│  │  └─ wealist_kanban_db              │  │
│  └────────────────────────────────────┘  │
│                                           │
│  ┌────────────────────────────────────┐  │
│  │    Redis :6379                     │  │
│  │  ├─ DB 0 (User Service)            │  │
│  │  └─ DB 1 (Kanban Service)          │  │
│  └────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## 사전 요구사항

### 로컬 개발/테스트

- Docker 20.10+
- Docker Compose 2.0+
- curl (health check용)

### EC2 배포

- AWS EC2 인스턴스 (Ubuntu 20.04+ 권장)
- SSH 접근 가능
- EC2에 Docker 및 Docker Compose 설치됨
- Security Group: 포트 8000, 8081, 22 오픈

## 빠른 시작

> **⚠️ 첫 배포인가요?** [FIRST_DEPLOY.md](./FIRST_DEPLOY.md)를 먼저 읽어보세요!

### 1. 환경 설정

```bash
# .env 파일 생성
cp .env.example .env

# .env 파일 수정 (비밀번호 등 변경)
vi .env

# 첫 배포라면 JPA_DDL_AUTO=update로 설정 (FIRST_DEPLOY.md 참조)
```

### 2. 로컬에서 실행

```bash
# 최신 이미지 Pull 및 실행
docker compose pull
docker compose up -d

# 로그 확인
docker compose logs -f

# Health check
curl http://localhost:8081/health  # User Service
curl http://localhost:8000/health  # Kanban Service
```

### 3. 배포 스크립트로 실행

```bash
# 로컬 배포
./deploy.sh

# EC2 원격 배포
EC2_HOST=your-ec2-ip EC2_KEY=~/.ssh/your-key.pem ./deploy-to-ec2.sh
```

## 배포 가이드

### 로컬 배포

```bash
./deploy.sh
```

이 스크립트는 다음을 수행합니다:
1. ✅ 최신 Docker 이미지 Pull
2. ✅ 기존 컨테이너 정지 및 제거
3. ✅ 데이터베이스 시작 (PostgreSQL, Redis)
4. ✅ **Kanban Service 마이그레이션 실행** (Alembic)
5. ✅ 서비스 시작
6. ✅ Health Check 수행
7. ✅ 서비스 상태 출력

> **첫 배포 시**: User Service 스키마 생성을 위해 [FIRST_DEPLOY.md](./FIRST_DEPLOY.md) 참조

### EC2 배포

#### 준비사항

1. **EC2 인스턴스 설정**
   ```bash
   # EC2에 SSH 접속
   ssh -i your-key.pem ubuntu@your-ec2-ip

   # Docker 설치
   sudo apt update
   sudo apt install -y docker.io docker-compose
   sudo usermod -aG docker $USER
   # 재로그인 필요
   ```

2. **환경 변수 설정**
   ```bash
   export EC2_HOST=your-ec2-ip
   export EC2_USER=ubuntu
   export EC2_KEY=~/.ssh/your-key.pem
   ```

3. **배포 실행**
   ```bash
   ./deploy-to-ec2.sh
   ```

### 수동 배포 (EC2)

```bash
# 파일 전송
scp -i your-key.pem docker-compose.yaml .env init-db.sh deploy.sh ubuntu@your-ec2-ip:~/wealist-deploy/

# SSH 접속
ssh -i your-key.pem ubuntu@your-ec2-ip

# 배포 디렉토리 이동
cd ~/wealist-deploy

# 실행 권한 부여
chmod +x deploy.sh init-db.sh

# 배포
./deploy.sh
```

## GitHub Actions 설정

### 각 서비스 저장소 설정 (User, Board)

#### 1. Docker Hub Secrets 추가

GitHub 저장소 → Settings → Secrets and variables → Actions

```
Name: DOCKER_HUB_TOKEN
Value: <Docker Hub Access Token>
```

**Docker Hub Access Token 생성:**
1. Docker Hub 로그인
2. Account Settings → Security → New Access Token
3. 생성된 토큰 복사

#### 2. Workflow 자동 실행

main 브랜치에 push하면 자동으로:
1. ✅ Docker 이미지 빌드
2. ✅ Docker Hub에 Push (latest, version, commit hash 태그)

### wealist-deploy 저장소 설정

#### 1. Secrets 추가

```
# EC2 정보
EC2_HOST: your-ec2-ip
EC2_USER: ubuntu
EC2_SSH_KEY: <Private SSH Key 내용>

# 환경 변수 (실제 운영 값)
APP_NAME: weAlist
POSTGRES_SUPERUSER: postgres
POSTGRES_SUPERUSER_PASSWORD: <strong-password>
USER_DB_NAME: wealist_user_db
USER_DB_USER: user_service
USER_DB_PASSWORD: <strong-password>
KANBAN_DB_NAME: wealist_kanban_db
KANBAN_DB_USER: kanban_service
KANBAN_DB_PASSWORD: <strong-password>
REDIS_PASSWORD: <strong-password>
JWT_SECRET: <strong-random-string>
JWT_EXPIRATION_MS: 86400000
JWT_ACCESS_MS: 1800000
JPA_DDL_AUTO: validate
JPA_SHOW_SQL: false
JPA_FORMAT_SQL: false
CORS_ORIGINS: http://your-domain.com
```

#### 2. Workflow 실행

**수동 실행:**
1. Actions 탭 이동
2. "Integration Test and Deploy" 선택
3. "Run workflow" 클릭
4. "EC2에 배포할까요?" 체크
5. Run

**자동 실행 (선택):**
- User 또는 Board 서비스에서 webhook 설정 시 자동 실행

## 트러블슈팅

### 컨테이너가 시작되지 않을 때

```bash
# 로그 확인
docker compose logs

# 특정 서비스 로그
docker compose logs user-service
docker compose logs kanban-service
docker compose logs postgres
docker compose logs redis

# 컨테이너 상태 확인
docker compose ps
```

### PostgreSQL 연결 실패

```bash
# PostgreSQL 컨테이너 상태 확인
docker exec wealist-postgres pg_isready -U postgres

# 데이터베이스 목록 확인
docker exec -it wealist-postgres psql -U postgres -c '\l'

# 초기화 스크립트 재실행 (데이터 손실 주의!)
docker compose down -v
docker compose up -d
```

### Redis 연결 실패

```bash
# Redis 연결 테스트
docker exec wealist-redis redis-cli -a your_redis_password ping

# DB 목록 확인
docker exec wealist-redis redis-cli -a your_redis_password INFO keyspace
```

### Health Check 실패

```bash
# User Service
curl -v http://localhost:8081/health

# Kanban Service
curl -v http://localhost:8000/health

# 서비스 재시작
docker compose restart user-service
docker compose restart kanban-service
```

### 이미지 Pull 실패

```bash
# Docker Hub 로그인 확인
docker login

# 수동으로 이미지 Pull
docker pull ressbe/wealist-user:latest
docker pull ressbe/wealist-board:latest
```

## 유용한 명령어

```bash
# 전체 로그 확인 (실시간)
docker compose logs -f

# 특정 서비스만 재시작
docker compose restart user-service

# 모든 컨테이너 정지
docker compose down

# 볼륨까지 삭제 (데이터 초기화)
docker compose down -v

# 디스크 정리
docker system prune -a

# 실행 중인 컨테이너 확인
docker compose ps

# PostgreSQL 접속
docker exec -it wealist-postgres psql -U postgres

# Redis 접속
docker exec -it wealist-redis redis-cli -a your_redis_password
```

## 버전 정보

- PostgreSQL: 17-alpine
- Redis: 7.2-alpine
- Docker Compose: 3.8
- GitHub Actions: v6

## 라이센스

MIT

## 문의

이슈가 있으면 GitHub Issues에 등록해주세요.
