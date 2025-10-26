# Jira 스타일 프로젝트 관리 플랫폼의 CI/CD 구축기

> 마이크로서비스 아키텍처부터 Docker Hub, GitHub Actions까지 - 완전한 자동화 파이프라인 구축 경험

## 📌 프로젝트 개요

**weAlist**는 팀 프로젝트 학습을 위해 구축한 Jira 스타일의 프로젝트 관리 플랫폼입니다.

### 기술 스택

**Backend:**
- User Service: Spring Boot + PostgreSQL
- Kanban Service: FastAPI + PostgreSQL
- Redis (캐싱/세션)

**Infrastructure:**
- Docker & Docker Compose
- GitHub Actions
- Docker Hub
- AWS EC2 (예정)

**아키텍처:**
- 마이크로서비스 아키텍처
- JWT 기반 인증
- Database per Service 패턴

---

## 🎯 목표: 중앙 집중식 배포 시스템 구축

### 문제 상황

팀 프로젝트에서 각자 fork한 레포지토리에서 개발하고 있었습니다:
- User Service 레포 (Spring Boot)
- Kanban Service 레포 (FastAPI)
- Frontend 레포 (React)

**과제:**
1. 각 서비스가 독립적으로 배포되어야 함
2. 통합 테스트 필요
3. EC2에 안전하게 배포
4. CI/CD 자동화

---

## 🏗️ 설계: 배포 플로우

### 최종 아키텍처

```
┌─────────────────┐         ┌─────────────────┐
│  User Service   │         │ Kanban Service  │
│   (Fork Repo)   │         │   (Fork Repo)   │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │ Push to main             │ Push to main
         │                           │
         ▼                           ▼
    ┌────────────┐             ┌────────────┐
    │ GitHub     │             │ GitHub     │
    │ Actions    │             │ Actions    │
    └─────┬──────┘             └─────┬──────┘
          │                          │
          │ Build & Push            │ Build & Push
          │                          │
          ▼                          ▼
    ┌──────────────────────────────────┐
    │       Docker Hub                 │
    │  - ressbe/wealist-user:latest   │
    │  - ressbe/wealist-board:latest  │
    └────────────┬─────────────────────┘
                 │
                 │ Pull & Deploy
                 │
                 ▼
    ┌─────────────────────────────┐
    │   wealist-deploy            │
    │   (중앙 배포 레포)           │
    ├─────────────────────────────┤
    │ 1. Integration Test         │
    │ 2. Database Migration       │
    │ 3. Deploy to EC2            │
    └─────────────────────────────┘
```

---

## 🔧 구현 단계

### 1단계: 각 서비스에 Dockerfile 작성

#### Kanban Service (FastAPI)

**과제:** 프로덕션 이미지 최적화

**Before (문제):**
```dockerfile
COPY . .  # 테스트 파일, 문서 모두 포함
CMD ["uvicorn", "app.main:app", "--reload"]  # 개발 모드
```

**After (최적화):**
```dockerfile
# Multi-stage build
FROM python:3.11-alpine AS builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-alpine
COPY --from=builder /root/.local /root/.local
COPY . .  # .dockerignore로 불필요한 파일 제외
CMD ["uvicorn", "app.main:app", "--workers", "4"]  # 프로덕션 모드
```

**.dockerignore 추가:**
```
tests/
pytest.ini
*.md
scripts/
.env
```

**결과:**
- 이미지 크기: 200MB → 150MB (25% 감소)
- 테스트 라이브러리 제외 (pytest, httpx 등)
- 멀티워커 모드로 성능 향상

#### User Service (Spring Boot)

```dockerfile
FROM gradle:8.5-jdk17 AS builder
COPY build.gradle settings.gradle ./
RUN gradle dependencies --no-daemon
COPY src ./src
RUN gradle bootJar --no-daemon

FROM eclipse-temurin:17-jre-alpine
COPY --from=builder /home/gradle/src/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-jar", "app.jar"]
```

**핵심:**
- Multi-stage build로 빌드 도구 제외
- JRE만 사용 (JDK 불필요)
- 컨테이너 최적화 JVM 옵션

---

### 2단계: GitHub Actions Workflow 작성

#### 각 서비스 레포 (User/Board)

**.github/workflows/docker-build-push.yml:**

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main

env:
  DOCKER_IMAGE: ressbe/wealist-user

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ressbe
          password: ${{ secrets.DOCKER_HUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ${{ env.DOCKER_IMAGE }}:latest
            ${{ env.DOCKER_IMAGE }}:${{ github.sha }}
          cache-from: type=registry,ref=${{ env.DOCKER_IMAGE }}:buildcache
          cache-to: type=registry,ref=${{ env.DOCKER_IMAGE }}:buildcache,mode=max
```

**핵심:**
- Docker Buildx로 빌드 성능 향상
- Registry cache로 빌드 속도 3-5배 향상
- 다중 태그: latest, commit hash, 버전

---

### 3단계: 통합 배포 구성 (wealist-deploy)

#### 인프라 최적화: PostgreSQL & Redis 통합

**Before (초기 설계):**
```
- User PostgreSQL
- Kanban PostgreSQL
- User Redis
- Kanban Redis
총 4개 컨테이너
```

**After (최적화, 스타트업 기준):**
```yaml
postgres:
  image: postgres:17-alpine
  # init-db.sh로 2개 DB 자동 생성:
  # - wealist_user_db
  # - wealist_kanban_db

redis:
  image: redis:7.2-alpine
  # DB 번호로 논리 분리:
  # - DB 0: User Service
  # - DB 1: Kanban Service
```

**결과:**
- 컨테이너: 4개 → 2개
- 메모리 사용량 감소
- 관리 복잡도 감소
- 논리적 격리 유지

#### docker-compose.yaml

```yaml
services:
  user-service:
    image: ressbe/wealist-user:latest
    environment:
      - DB_HOST=postgres
      - DB_NAME=${USER_DB_NAME}
      - REDIS_HOST=redis
      - REDIS_DB=0
    depends_on:
      postgres:
        condition: service_healthy

  kanban-service:
    image: ressbe/wealist-board:latest
    environment:
      - DATABASE_URL=postgresql://...@postgres/${KANBAN_DB_NAME}
      - REDIS_URL=redis://:password@redis:6379/1
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:17-alpine
    volumes:
      - ./init-db.sh:/docker-entrypoint-initdb.d/init-db.sh
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]

  redis:
    image: redis:7.2-alpine
    command: redis-server --databases 16
```

---

### 4단계: 배포 자동화 스크립트

**deploy.sh:**

```bash
#!/bin/bash
set -e

# 최신 이미지 Pull
docker compose pull

# 기존 컨테이너 정지
docker compose down

# DB 먼저 시작
docker compose up -d postgres redis
sleep 10

# Kanban Service 마이그레이션 (Alembic)
docker compose run --rm kanban-service alembic upgrade head

# 모든 서비스 시작
docker compose up -d

# Health check
curl -f http://localhost:8081/health  # User Service
curl -f http://localhost:8000/health  # Kanban Service
```

**핵심:**
- 단계별 실행 (DB → 마이그레이션 → 서비스)
- 자동 health check
- 에러 시 즉시 중단 (set -e)

---

## 🎓 배운 점 & 해결한 문제들

### 1. Git Remote 관리

**문제:**
- 팀 공유 레포(origin)에 실수로 CI/CD 파일 push 방지 필요
- 개인 fork에만 GitHub Actions 설정

**해결:**
```bash
# origin(팀 레포) → upstream으로 변경
git remote rename origin upstream

# fork(개인 레포) → origin으로 변경
git remote rename fork origin

# 이제 git push하면 개인 fork로만 감!
```

---

### 2. 첫 배포 시 스키마 생성 문제

**문제:**
- JPA_DDL_AUTO=validate (프로덕션 권장)
- 하지만 첫 배포 시 테이블이 없어서 실패

**해결:**

**FIRST_DEPLOY.md 작성:**
```markdown
1. 첫 배포: JPA_DDL_AUTO=update로 테이블 생성
2. 검증: 테이블 정상 생성 확인
3. 변경: JPA_DDL_AUTO=validate로 변경
4. 재시작: 서비스 재시작으로 확인
```

**Kanban Service:**
```bash
# Alembic으로 자동 마이그레이션
docker compose run --rm kanban-service alembic upgrade head
```

---

### 3. GitHub Actions YAML 문법 오류

**문제:**
```yaml
run: echo "Tags: latest, ${{ var1 }}, ${{ var2 }}"
# ❌ YAML 파서가 콜론(:) 때문에 혼란
```

**해결:**
```yaml
run: |
  echo "Tags: latest, ${{ var1 }}, ${{ var2 }}"
# ✅ 멀티라인 문자열로 처리
```

---

### 4. 환경별 설정 분리

**문제:**
- 로컬 개발: `--reload` 필요
- 프로덕션: 불필요 (성능 저하)

**해결:**

**requirements 분리:**
```
requirements.txt          # 프로덕션
requirements-dev.txt      # 개발 (pytest 등)
```

**Docker Compose 분리:**
```
docker-compose.yaml       # 프로덕션
docker-compose.dev.yaml   # 개발 (--reload, volume mount)
```

---

## 📊 성과

### 빌드 시간

**Before (캐시 없음):**
- User Service: ~8분
- Kanban Service: ~5분

**After (Registry cache):**
- User Service: ~2분 (75% 개선)
- Kanban Service: ~1분 (80% 개선)

### 이미지 크기

**Kanban Service:**
- Before: ~200MB
- After: ~150MB (25% 감소)

**User Service:**
- Multi-stage build: ~250MB
- JRE only (JDK 제외)

### 배포 시간

**수동 배포:**
- 각 서비스 개별 빌드/배포: ~30분
- 통합 테스트 수동: ~10분

**자동 배포 (예정):**
- 코드 push → 배포 준비: ~5분
- 통합 테스트: ~2분
- 승인 후 배포: ~3분

---

## 🚀 다음 단계

### 1. Discord 알림 + 수동 승인 배포 (진행 예정)

```
코드 Push
  → GitHub Actions
  → Docker Hub
  → 통합 테스트
  → Discord 알림
  → 수동 승인
  → EC2 배포
```

### 2. 모니터링 & 로깅

- Prometheus + Grafana
- ELK Stack 또는 Loki
- Sentry (에러 추적)

### 3. 고급 배포 전략

- Blue-Green Deployment
- Canary Deployment
- 자동 롤백

### 4. Kubernetes 전환 (최종 목표)

- Docker Compose → K8s
- Helm Charts
- ArgoCD (GitOps)

---

## 💡 핵심 교훈

### 1. 실무 중심 학습

**좋았던 점:**
- Docker Hub, GitHub Actions: 실무 표준 도구
- Multi-stage build: 프로덕션 필수 기술
- .dockerignore: 보안 & 성능

**배운 점:**
- 이론보다 직접 부딪히며 배우는 게 빠름
- 에러 로그 읽는 능력이 핵심

### 2. 팀 협업 고려

**Git 전략:**
- Fork 활용으로 실수 방지
- Remote 관리로 안전성 확보

**문서화:**
- README, FIRST_DEPLOY, NEXT_STEPS
- 팀원이 따라할 수 있도록 상세히 작성

### 3. 점진적 개선

**단계별 접근:**
1. 수동 배포 → 자동 빌드
2. 자동 빌드 → 자동 테스트
3. 자동 테스트 → 자동 배포 (진행 중)

**한 번에 모든 걸 자동화하려 하지 말 것!**

---

## 🔗 참고 자료

**Docker:**
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [.dockerignore](https://docs.docker.com/engine/reference/builder/#dockerignore-file)

**GitHub Actions:**
- [Docker build-push-action](https://github.com/docker/build-push-action)
- [Repository dispatch](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)

**Best Practices:**
- [12 Factor App](https://12factor.net/)
- [Container Best Practices](https://cloud.google.com/architecture/best-practices-for-building-containers)

---

## 🎬 마무리

마이크로서비스 아키텍처부터 CI/CD 구축까지, 처음에는 막연했지만 하나씩 해결하며 실무 경험을 쌓을 수 있었습니다.

**다음 글 예고:**
- Discord 알림 연동 & 자동 배포
- Kubernetes 전환기
- 모니터링 시스템 구축

---

**GitHub:**
- [wealist-deploy](https://github.com/ressKim-io/wealist-deploy-test)
- [weAlist-User](https://github.com/ressKim-io/weAlist-User-fork)
- [weAlist-Board](https://github.com/ressKim-io/weAlist-Board-fork)

**작성일:** 2025-10-26
**작성자:** @ressKim-io

---

*이 글이 도움이 되셨다면 ⭐️ Star를 눌러주세요!*
