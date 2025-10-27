# CI/CD 파이프라인 설정 가이드

이 문서는 weAlist 프로젝트의 자동화된 CI/CD 파이프라인 설정 방법을 안내합니다.

---

## 📊 전체 워크플로우

```
개발자 코드 Push
    ↓
User/Board Service: Docker 빌드 & Hub 푸시
    ↓
Deploy Repository: 통합 테스트 자동 실행
    ↓
Discord: 알림 전송 (성공/실패)
    ↓
GitHub Actions: 수동으로 EC2 배포 승인
    ↓
EC2: 자동 배포 실행
```

---

## 🔧 1단계: Discord Webhook 설정

### Discord 채널 생성
1. Discord 서버에서 새 채널 생성 (예: `#cicd-알림`)
2. 채널 설정 → 연동 → Webhook → 새 Webhook
3. Webhook 이름: `weAlist CI/CD Bot`
4. Webhook URL 복사 (예: `https://discord.com/api/webhooks/123456789/abcdefg...`)

**⚠️ 중요**: Webhook URL을 안전하게 보관하세요. GitHub Secrets에 저장됩니다.

---

## 🔐 2단계: GitHub Personal Access Token 생성

### 목적
User/Board Service에서 Deploy Repository의 워크플로우를 트리거하기 위해 필요합니다.

### 생성 방법
1. GitHub → Settings (개인 설정) → Developer settings
2. Personal access tokens → Tokens (classic)
3. "Generate new token (classic)" 클릭
4. 설정:
   - **Note**: `weAlist Deploy Trigger`
   - **Expiration**: `90 days` (또는 원하는 기간)
   - **Scopes**:
     - ✅ `repo` (전체 체크박스 선택)
     - ✅ `workflow`
5. "Generate token" 클릭
6. **생성된 토큰을 복사** (다시 볼 수 없으니 주의!)

---

## 🔑 3단계: GitHub Secrets 설정

### weAlist-User-fork 저장소

**경로**: `Settings → Secrets and variables → Actions → New repository secret`

| Secret 이름 | 값 | 설명 |
|------------|---|------|
| `DEPLOY_TRIGGER_TOKEN` | [Personal Access Token] | Deploy 워크플로우 트리거용 |
| `DOCKER_HUB_TOKEN` | [Docker Hub Token] | Docker Hub 푸시용 (이미 있음) |

### weAlist-Board-fork 저장소

**경로**: `Settings → Secrets and variables → Actions → New repository secret`

| Secret 이름 | 값 | 설명 |
|------------|---|------|
| `DEPLOY_TRIGGER_TOKEN` | [Personal Access Token] | Deploy 워크플로우 트리거용 (User와 동일) |
| `DOCKER_HUB_TOKEN` | [Docker Hub Token] | Docker Hub 푸시용 (이미 있음) |

### wealist-deploy-test 저장소

**경로**: `Settings → Secrets and variables → Actions → New repository secret`

| Secret 이름 | 값 | 설명 |
|------------|---|------|
| `DISCORD_WEBHOOK_URL` | [Discord Webhook URL] | Discord 알림 전송용 |
| `EC2_SSH_KEY` | [EC2 Private Key] | EC2 SSH 접속용 |
| `EC2_HOST` | [EC2 IP 주소] | EC2 서버 주소 |
| `EC2_USER` | `ubuntu` (또는 EC2 사용자) | EC2 SSH 사용자명 |

#### EC2 배포용 환경 변수 Secrets (운영 환경)

| Secret 이름 | 예시 값 | 설명 |
|------------|--------|------|
| `APP_NAME` | `weAlist` | 애플리케이션 이름 |
| `POSTGRES_SUPERUSER` | `postgres` | PostgreSQL 관리자 |
| `POSTGRES_SUPERUSER_PASSWORD` | `[강력한 비밀번호]` | PostgreSQL 관리자 비밀번호 |
| `USER_DB_NAME` | `wealist_user_db` | User Service DB 이름 |
| `USER_DB_USER` | `user_service` | User Service DB 유저 |
| `USER_DB_PASSWORD` | `[강력한 비밀번호]` | User Service DB 비밀번호 |
| `KANBAN_DB_NAME` | `wealist_kanban_db` | Kanban Service DB 이름 |
| `KANBAN_DB_USER` | `kanban_service` | Kanban Service DB 유저 |
| `KANBAN_DB_PASSWORD` | `[강력한 비밀번호]` | Kanban Service DB 비밀번호 |
| `REDIS_PASSWORD` | `[강력한 비밀번호]` | Redis 비밀번호 |
| `JWT_SECRET` | `[랜덤 문자열 64자 이상]` | JWT 서명 키 |
| `JWT_EXPIRATION_MS` | `86400000` | JWT 만료 시간 (24시간) |
| `JWT_ACCESS_MS` | `1800000` | Access Token 만료 (30분) |
| `JPA_DDL_AUTO` | `validate` | 운영 환경: validate |
| `JPA_SHOW_SQL` | `false` | 운영 환경: false |
| `JPA_FORMAT_SQL` | `false` | 운영 환경: false |
| `CORS_ORIGINS` | `https://your-domain.com` | 허용할 CORS Origin |

---

## ✅ 4단계: 설정 확인

### Secrets 확인 체크리스트

#### weAlist-User-fork
- [o] `DEPLOY_TRIGGER_TOKEN` 설정됨
- [o] `DOCKER_HUB_TOKEN` 설정됨

#### weAlist-Board-fork
- [o] `DEPLOY_TRIGGER_TOKEN` 설정됨
- [o] `DOCKER_HUB_TOKEN` 설정됨

#### wealist-deploy-test
- [o] `DISCORD_WEBHOOK_URL` 설정됨
- [o] `EC2_SSH_KEY` 설정됨
- [o] `EC2_HOST` 설정됨
- [o] `EC2_USER` 설정됨
- [o] 모든 환경 변수 Secrets 설정됨 (운영 환경용)

---

## 🧪 5단계: 테스트

### 테스트 절차

#### 1. User Service 테스트
```bash
cd weAlist-User
git checkout main
echo "# Test CI/CD pipeline" >> README.md
git add README.md
git commit -m "test: Trigger CI/CD pipeline"
git push origin main
```

#### 2. 예상 동작 확인
1. **User Service GitHub Actions**
   - "Build and Push Docker Image" 워크플로우 자동 실행
   - Docker Hub에 이미지 푸시
   - Deploy 워크플로우 트리거

2. **Deploy GitHub Actions**
   - "Integration Test and Deploy" 워크플로우 자동 실행
   - 통합 테스트 실행

3. **Discord 알림**
   - 성공 시: 초록색 메시지 + 배포 링크
   - 실패 시: 빨간색 메시지 + 로그 링크

4. **수동 배포 승인**
   - GitHub Actions → wealist-deploy-test 저장소
   - "Integration Test and Deploy" → "Run workflow"
   - ✅ `deploy_to_ec2` 체크박스 선택
   - "Run workflow" 클릭

5. **EC2 배포 확인**
   - 배포 완료 후 서비스 접속 확인
   - User Service: `http://[EC2_HOST]:8081/health`
   - Kanban Service: `http://[EC2_HOST]:8000/health`

---

## 🔍 트러블슈팅

### Discord 알림이 안 오는 경우
- [ ] `DISCORD_WEBHOOK_URL` Secret 확인
- [ ] Webhook URL 형식 확인 (`https://discord.com/api/webhooks/...`)
- [ ] Discord에서 Webhook이 삭제되지 않았는지 확인
- [ ] 워크플로우 로그에서 `notify-discord` job 확인

### Deploy 워크플로우가 트리거되지 않는 경우
- [ ] `DEPLOY_TRIGGER_TOKEN` Secret 확인
- [ ] Token 권한 확인 (`repo`, `workflow` 체크되었는지)
- [ ] Token 만료 확인
- [ ] User/Board 워크플로우 로그에서 "Trigger deployment workflow" 단계 확인

### 통합 테스트 실패
- [ ] Docker 이미지가 정상적으로 빌드되었는지 확인
- [ ] `.env` 파일 설정 확인
- [ ] 서비스 헬스체크 엔드포인트 확인 (`/health`)
- [ ] 로그 확인: GitHub Actions 로그 → "통합 테스트 실행" 단계

### EC2 배포 실패
- [ ] `EC2_SSH_KEY` 형식 확인 (PEM 파일 내용 전체)
- [ ] `EC2_HOST` 확인 (IP 주소 또는 도메인)
- [ ] EC2 보안 그룹에서 SSH (22번 포트) 허용 확인
- [ ] EC2에 Docker 및 Docker Compose 설치 확인

---

## 📚 참고 문서

- [GitHub Actions - Repository Dispatch](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)
- [Discord Webhooks Guide](https://discord.com/developers/docs/resources/webhook)
- [GitHub Actions - workflow_dispatch](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)

---

## 🎯 다음 단계 (옵션 B: 완전 자동화)

현재는 GitHub Actions 웹에서 수동으로 배포를 승인합니다.
향후 Discord 버튼으로 직접 승인하려면:

1. Discord Bot 생성
2. Webhook 처리 서버 구축 (AWS Lambda, Cloud Run, Express.js)
3. Discord Interactions API 연동
4. 승인/거절 버튼 클릭 시 GitHub Actions 트리거

---

**작성일**: 2025-10-27
**버전**: 1.0 (옵션 A - 수동 승인 방식)
