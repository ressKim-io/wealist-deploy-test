# CI/CD 설정 체크리스트

**작업 날짜**: 2025-10-27
**상태**: 코드 구현 완료 ✅, 설정 대기 중

---

## ✅ 완료된 작업

- [x] User Service 워크플로우에 Deploy 트리거 추가
- [x] Board Service 워크플로우에 Deploy 트리거 추가
- [x] Deploy 워크플로우에 Discord 알림 job 추가
- [x] CI/CD 설정 가이드 문서 작성

---

## 📋 다음에 할 작업 (순서대로)

### 1단계: Discord Webhook 생성
- [ ] Discord에서 `#cicd-알림` 채널 생성 (또는 기존 채널 사용)
- [ ] 채널 설정 → 연동 → Webhook → 새 Webhook
- [ ] 이름: `weAlist CI/CD Bot`
- [ ] Webhook URL 복사 및 저장

### 2단계: GitHub Personal Access Token 생성
- [ ] GitHub → Settings → Developer settings → Personal access tokens
- [ ] "Generate new token (classic)" 클릭
- [ ] Note: `weAlist Deploy Trigger`
- [ ] Scopes: ✅ `repo` (전체), ✅ `workflow`
- [ ] 토큰 복사 및 저장

### 3단계: GitHub Secrets 설정

#### weAlist-User-fork 저장소
- [ ] Settings → Secrets and variables → Actions
- [ ] `DEPLOY_TRIGGER_TOKEN` 추가 (Personal Access Token 입력)

#### weAlist-Board-fork 저장소
- [ ] Settings → Secrets and variables → Actions
- [ ] `DEPLOY_TRIGGER_TOKEN` 추가 (동일한 Personal Access Token 입력)

#### wealist-deploy-test 저장소
- [ ] `DISCORD_WEBHOOK_URL` 추가
- [ ] `EC2_SSH_KEY` 추가 (PEM 파일 전체 내용)
- [ ] `EC2_HOST` 추가 (EC2 IP 주소)
- [ ] `EC2_USER` 추가 (기본값: ubuntu)
- [ ] 환경 변수 Secrets 추가:
  - [ ] `APP_NAME`
  - [ ] `POSTGRES_SUPERUSER_PASSWORD`
  - [ ] `USER_DB_PASSWORD`
  - [ ] `KANBAN_DB_PASSWORD`
  - [ ] `REDIS_PASSWORD`
  - [ ] `JWT_SECRET`
  - [ ] 기타 (CICD_SETUP_GUIDE.md 참고)

### 4단계: 테스트
- [ ] User Service에서 테스트 커밋 & 푸시
  ```bash
  cd weAlist-User
  echo "# Test CI/CD" >> README.md
  git add . && git commit -m "test: CI/CD pipeline"
  git push origin main
  ```
- [ ] GitHub Actions 실행 확인 (User Service)
- [ ] Docker Hub에 이미지 푸시 확인
- [ ] GitHub Actions 실행 확인 (Deploy 저장소)
- [ ] 통합 테스트 성공 확인
- [ ] Discord 알림 수신 확인
- [ ] GitHub Actions에서 수동 배포 실행
  - [ ] Actions → Integration Test and Deploy → Run workflow
  - [ ] ✅ `deploy_to_ec2` 체크
  - [ ] Run workflow 클릭
- [ ] EC2 배포 완료 확인
- [ ] 서비스 접속 테스트
  - [ ] User Service: `http://[EC2_HOST]:8081/health`
  - [ ] Kanban Service: `http://[EC2_HOST]:8000/health`

### 5단계: Board Service 테스트
- [ ] Board Service에서 테스트 커밋 & 푸시
- [ ] 전체 플로우 재확인

---

## 📄 참고 문서

- **상세 설정 가이드**: `CICD_SETUP_GUIDE.md`
- **User Service 워크플로우**: `../weAlist-User/.github/workflows/docker-build-push.yml`
- **Board Service 워크플로우**: `../weAlist-Board/.github/workflows/docker-build-push.yml`
- **Deploy 워크플로우**: `.github/workflows/integration-test.yml`

---

## 🔍 트러블슈팅

문제 발생 시 `CICD_SETUP_GUIDE.md`의 트러블슈팅 섹션을 참고하세요.

---

**다음 작업 시작 전에 이 파일을 먼저 확인하세요!** ✨
