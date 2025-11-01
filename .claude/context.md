# weAlist Project Context

**Last Updated**: 2025-10-30

## 프로젝트 개요

weAlist는 Jira 스타일 프로젝트 관리 플랫폼으로, **모노레포**로 통합된 마이크로서비스 아키텍처입니다.

### 서비스 구성
1. **User Service** (`user/`) - Spring Boot/Java - 사용자 인증 및 관리
2. **Board Service** (`board/`) - FastAPI/Python - 프로젝트 및 태스크 관리 (Kanban)
3. **Frontend** (`frontend/`) - React/TypeScript - 프론트엔드 애플리케이션

---

## 현재 상태 (2025-10-30)

### ✅ 모노레포 통합 완료
- 이전에 분리되어 있던 User Service, Board Service, Frontend를 하나의 저장소로 통합
- 통합 `docker-compose.yaml`로 모든 서비스 관리
- 공유 PostgreSQL (다중 데이터베이스) 및 Redis (DB 분리) 사용

---

## 최근 변경사항 (2025-10-29 ~ 2025-10-30)

### 🔄 모노레포 통합 (2025-10-29)
- **Backend 합치기**: User Service와 Board Service를 하나의 저장소로 통합
  - `user/` - User Service (Spring Boot)
  - `board/` - Board Service (FastAPI)
- **Frontend 추가**: React/TypeScript 프론트엔드 통합
  - `frontend/` - React 애플리케이션
- **Docker Compose 통합**: 단일 `docker-compose.yaml`로 모든 서비스 오케스트레이션
- **공유 인프라**:
  - PostgreSQL 단일 인스턴스 (다중 DB: wealist_user_db, wealist_kanban_db)
  - Redis 단일 인스턴스 (DB 분리: DB 0 - User, DB 1 - Board)

**커밋 히스토리**:
```
e444836 - 순환참조 문제 해결
1498164 - Fix API documentation URLs for Swagger and Health Check
67242b3 - front 재업로드
2fb7278 - front 추가
b97dd02 - 프론트 gitignore
7b8cf86 - backend 합치기
132e1f0 - gitignore
```

---

## 데이터베이스 스키마

### User Service

#### users
- `user_id` (UUID, PK)
- `email` (String, Unique)
- `password_hash` (String)
- `name` (String)
- `is_active` (Boolean)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)
- `deleted_at` (Timestamp, nullable)

#### groups
- `group_id` (UUID, PK)
- `name` (String)
- `company_name` (String)
- `is_deleted` (Boolean)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)
- `deleted_at` (Timestamp, nullable)

#### teams
- `team_id` (UUID, PK)
- `team_name` (String)
- `description` (String)
- `group_id` (UUID) - 그룹 참조
- `leader_id` (UUID) - 팀장 참조
- `is_deleted` (Boolean)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)

#### user_info
- `user_id` (UUID, PK)
- `group_id` (UUID)
- `role` (String)
- `is_deleted` (Boolean)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)

### Board Service

(별도 데이터베이스 - No FK 정책)

#### workspaces, projects, tickets, tasks, notifications, comments, attachments
- 모든 테이블은 UUID PK 사용
- `created_by`, `updated_by`, `created_at`, `updated_at` 감사 필드
- `is_deleted` Soft Delete 플래그 (일부 엔티티)
- Application-level CASCADE (FK 없음)

---

## 아키텍처 원칙

### 마이크로서비스 격리 (모노레포)
- **No Direct Service-to-Service Calls**: 서비스 간 HTTP 호출 없음
- **JWT 기반 인증 공유**: User Service가 발급한 JWT를 Board Service에서 검증
- **독립 데이터베이스**: 각 서비스가 자체 PostgreSQL DB 사용 (공유 인스턴스, 분리된 DB)
- **No Foreign Keys**: 샤딩 준비를 위해 FK 사용 안 함
- **Application-level Referential Integrity**: 애플리케이션 레벨에서 데이터 일관성 관리

### 모노레포 구조
- **단일 Git 저장소**: 모든 서비스가 하나의 저장소에서 관리
  - `user/` - User Service
  - `board/` - Board Service
  - `frontend/` - Frontend
- **통합 관리**: Docker Compose, 환경 변수, 문서가 루트 레벨에서 통합 관리
- **독립적 배포**: 모노레포이지만 각 서비스는 독립적으로 배포 가능

### 공통 설정
- **JWT_SECRET**: 모든 서비스가 동일한 시크릿 공유
- **Docker Network**: `wealist-net` 브리지 네트워크 사용
- **UUID Primary Keys**: 분산 시스템 호환성
- **Soft Delete**: 물리적 삭제 대신 플래그 사용

---

## 포트 할당

| 서비스 | 포트 | 설명 |
|--------|------|------|
| User Service | 8080 | Spring Boot API |
| Board Service | 8000 | FastAPI |
| Frontend | 3000 | React Dev Server (not in docker-compose) |
| PostgreSQL | 5432 | 공유 인스턴스 (wealist_user_db, wealist_kanban_db) |
| Redis | 6379 | 공유 인스턴스 (DB 0: User, DB 1: Board) |

---

## 환경 변수

주요 환경 변수는 `.env` 파일에서 관리:

```env
# User Service
USER_SERVICE_PORT=8081
USER_DB_HOST=user-db
USER_DB_PORT=5432 # 컨테이너 내부
USER_REDIS_HOST=user-redis
USER_REDIS_PORT=6379 # 컨테이너 내부

# Kanban Service
KANBAN_SERVICE_PORT=8000
KANBAN_DB_HOST=kanban-db
KANBAN_REDIS_HOST=kanban-redis

# 공통
JWT_SECRET=default-super-secret-key-change-it-later
JWT_EXPIRATION_MS=86400000
JWT_ACCESS_MS=1800000
```

---

## API 문서

### User Service
- **Swagger UI**: http://localhost:8080/swagger-ui.html (현재 설정 중)
- **Health Check**: http://localhost:8080/health
- **상세 문서**: `user/API_DOCUMENTATION.md`

### 주요 엔드포인트
- `POST /api/auth/signup` - 회원가입
- `POST /api/auth/login` - 로그인
- `POST /api/auth/logout` - 로그아웃
- `POST /api/auth/refresh` - 토큰 갱신
- `GET /api/auth/me` - 내 정보 조회
- `GET /api/users` - 사용자 목록
- `GET /api/groups` - 그룹 목록
- `GET /api/teams` - 팀 목록

### Board Service
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health
- **상세 문서**: `board/services/kanban/API_DOCUMENTATION.md`
- **테스트 가이드**: `board/services/kanban/API_TEST_GUIDE.md`

### 주요 엔드포인트
- `POST /api/workspaces/` - 워크스페이스 생성
- `GET /api/workspaces/` - 워크스페이스 목록
- `POST /api/projects/` - 프로젝트 생성
- `GET /api/projects/` - 프로젝트 목록 (필터: workspace_id, status, priority)
- `POST /api/tickets/` - 티켓 생성
- `GET /api/tickets/` - 티켓 목록 (필터: project_id, status, priority)
- `POST /api/tasks/` - 태스크 생성
- `GET /api/tasks/` - 태스크 목록 (필터: ticket_id, status)
- `PATCH /api/tasks/{id}/complete` - 태스크 완료 처리
- `GET /api/notifications/` - 알림 목록
- `GET /api/notifications/unread-count` - 읽지 않은 알림 개수
- `POST /api/projects/{project_id}/ticket-types/` - 티켓 타입 생성

---

## 개발 워크플로우

### 모노레포 작업 흐름
**중요**: 모든 서비스가 하나의 Git 저장소에서 관리됩니다.

#### 기능 개발 시
```bash
git branch -a                    # 브랜치 확인
git checkout -b feature/...      # 새 기능 개발 (예: feature/user-auth, feature/board-api)
# user/, board/, frontend/ 중 필요한 디렉토리에서 작업
git add .
git commit -m "feat: ..."
git push origin feature/...
```

#### 서비스별 작업 예시
```bash
# User Service 수정
cd user && ./gradlew build

# Board Service 수정
cd board/services/kanban && pytest

# Frontend 수정
cd frontend && npm test
```

### 브랜치 전략
- `main` - 운영 환경 배포 브랜치
- `develop` - 개발 통합 브랜치 (있는 경우)
- `feature/*` - 기능 개발 브랜치

### 커밋 규칙
```
feat: 새로운 기능
fix: 버그 수정
docs: 문서 변경
refactor: 리팩토링
test: 테스트 추가
chore: 빌드/설정 변경
```

---

## 다음 작업 예정

### 🚨 최우선 작업: CI/CD 파이프라인 설정 완료 (코드 구현 완료 ✅)

**날짜**: 2025-10-27
**상태**: 코드 구현 완료, Secrets 설정 필요

#### ✅ 완료된 작업
- [x] User Service 워크플로우에 Deploy 트리거 추가
- [x] Board Service 워크플로우에 Deploy 트리거 추가
- [x] Deploy 워크플로우에 Discord 알림 job 추가
- [x] CI/CD 설정 가이드 문서 작성 (`weAlist-deploy/CICD_SETUP_GUIDE.md`)

#### 📋 다음 실행 시 할 작업

**1. Discord Webhook 생성**
```
Discord 채널 → 설정 ⚙️ → 연동 → Webhook → 새 Webhook
이름: weAlist CI/CD Bot
Webhook URL 복사
```

**2. GitHub Personal Access Token 생성**
```
GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
Note: weAlist Deploy Trigger
Scopes: ✅ repo (전체), ✅ workflow
토큰 복사
```

**3. GitHub Secrets 설정**

**weAlist-User-fork:**
- `DEPLOY_TRIGGER_TOKEN` = [Personal Access Token]

**weAlist-Board-fork:**
- `DEPLOY_TRIGGER_TOKEN` = [Personal Access Token]

**wealist-deploy-test:**
- `DISCORD_WEBHOOK_URL` = [Discord Webhook URL]
- `EC2_SSH_KEY` = [EC2 Private Key 전체 내용]
- `EC2_HOST` = [EC2 IP 주소]
- `EC2_USER` = ubuntu
- 운영 환경 변수들 (DB 비밀번호, JWT_SECRET 등)

**4. 테스트 실행**
```bash
cd weAlist-User
echo "# Test CI/CD pipeline" >> README.md
git add . && git commit -m "test: CI/CD pipeline"
git push origin main
```

**5. 예상 플로우 확인**
1. User Service GitHub Actions 자동 실행
2. Docker Hub 푸시
3. Deploy 저장소 통합 테스트 자동 실행
4. Discord 알림 수신 (성공/실패)
5. GitHub Actions 웹에서 수동 배포 승인 (Run workflow → ✅ deploy_to_ec2)
6. EC2 자동 배포 실행

**📄 상세 가이드**: `weAlist-deploy/CICD_SETUP_GUIDE.md` 참고

**🔧 수정된 파일**:
- `weAlist-User/.github/workflows/docker-build-push.yml`
- `weAlist-Board/.github/workflows/docker-build-push.yml`
- `weAlist-deploy/.github/workflows/integration-test.yml`
- `weAlist-deploy/CICD_SETUP_GUIDE.md` (신규)

---

### User Service
- [ ] Redis 세션 저장소 구현
- [ ] Rate Limiting (Redis 기반)
- [ ] 캐싱 전략 구현
- [ ] 리프레시 토큰 블랙리스트 (Redis)

### Kanban Service
- [ ] WebSocket 실시간 알림
- [ ] 파일 업로드 기능

### Frontend
- [ ] User Service API 통합
- [ ] Kanban Service API 통합

---

## 트러블슈팅 가이드

### User Service가 시작되지 않을 때
1. PostgreSQL 연결 확인: `docker logs wealist-user-db`
2. Redis 연결 확인: `docker logs wealist-user-redis`
3. 환경 변수 확인: `.env` 파일 존재 여부
4. 포트 충돌 확인: `lsof -i :8081`

### 순환 참조 에러
- SecurityConfig에 `@Lazy` 추가 확인
- application.yml에 `spring.main.allow-circular-references: true` 설정

### Redis 연결 실패
- Docker 네트워크 내에서는 **내부 포트**(6379) 사용
- 호스트에서는 **외부 포트**(6380) 사용
- 비밀번호 설정 확인

---

## 참고 문서

- `CLAUDE.md` - Claude Code 사용 가이드
- `user/API_DOCUMENTATION.md` - User Service API 문서
- `user/README.md` - User Service 개발 가이드
- `board/services/kanban/API_DOCUMENTATION.md` - Board Service API 문서
- `board/services/kanban/API_TEST_GUIDE.md` - Board Service 테스트 가이드
- `board/README.md` - Board Service 개발 가이드
- `frontend/README.md` - Frontend 개발 가이드
- `.claude/branches.md` - Git 브랜치 관리 가이드
