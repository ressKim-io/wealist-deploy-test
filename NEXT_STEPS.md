# 다음 단계: Discord 자동 알림 + 수동 승인 배포

## 📋 준비 사항 체크리스트

### 1. Discord 설정

- [ ] Discord 서버 생성 (또는 기존 서버 사용)
- [ ] 전용 채널 생성 (추천: `#cicd-알림` 또는 `#배포-알림`)
- [ ] Webhook 생성
  - Discord 채널 → 설정 ⚙️ → 연동 → Webhook → 새 Webhook
  - 이름: `weAlist CI/CD Bot`
  - Webhook URL 복사 (예: `https://discord.com/api/webhooks/123456789/abcdefg...`)
- [ ] 팀원 초대

---

### 2. GitHub Personal Access Token 생성

**목적:** User/Board 서비스가 wealist-deploy를 트리거하기 위해 필요

**생성 방법:**
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token (classic)" 클릭
3. 설정:
   - Note: `weAlist Deploy Trigger`
   - Expiration: `90 days` (또는 원하는 기간)
   - Scopes:
     - ✅ `repo` (전체 체크)
     - ✅ `workflow`
4. Generate token 클릭
5. 생성된 토큰 복사 (다시 볼 수 없으니 주의!)

---

### 3. GitHub Secrets 설정

#### wealist-deploy-test 저장소
```
Settings → Secrets and variables → Actions → New repository secret

추가할 Secrets:
1. DISCORD_WEBHOOK_URL
   Value: <Discord에서 복사한 Webhook URL>
```

#### weAlist-User-fork 저장소
```
Settings → Secrets and variables → Actions → New repository secret

추가할 Secret:
1. DEPLOY_TRIGGER_TOKEN
   Value: <GitHub Personal Access Token>
```

#### weAlist-Board-fork 저장소
```
Settings → Secrets and variables → Actions → New repository secret

추가할 Secret:
1. DEPLOY_TRIGGER_TOKEN
   Value: <동일한 GitHub Personal Access Token>
```

---

## 🔧 구현 파일 수정

### 1. User Service Workflow 업데이트

**파일:** `weAlist-User/.github/workflows/docker-build-push.yml`

**마지막에 추가:**
```yaml
      - name: Trigger deployment workflow
        if: success()
        run: |
          curl -X POST \
            -H "Authorization: token ${{ secrets.DEPLOY_TRIGGER_TOKEN }}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/ressKim-io/wealist-deploy-test/dispatches \
            -d '{"event_type":"new-image-pushed","client_payload":{"service":"user","version":"${{ steps.version.outputs.version }}","commit":"${{ github.sha }}","actor":"${{ github.actor }}"}}'
```

### 2. Board Service Workflow 업데이트

**파일:** `weAlist-Board/.github/workflows/docker-build-push.yml`

**마지막에 추가:**
```yaml
      - name: Trigger deployment workflow
        if: success()
        run: |
          curl -X POST \
            -H "Authorization: token ${{ secrets.DEPLOY_TRIGGER_TOKEN }}" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/ressKim-io/wealist-deploy-test/dispatches \
            -d '{"event_type":"new-image-pushed","client_payload":{"service":"board","version":"${{ steps.version.outputs.version }}","commit":"${{ github.sha }}","actor":"${{ github.actor }}"}}'
```

### 3. wealist-deploy Workflow 업데이트

**파일:** `wealist-deploy/.github/workflows/integration-test.yml`

**on 섹션에 추가:**
```yaml
on:
  # 기존 내용 유지
  workflow_dispatch:
    inputs:
      deploy_to_ec2:
        description: 'EC2에 배포할까요?'
        required: false
        type: boolean
        default: false

  # 새로 추가: User/Board에서 트리거
  repository_dispatch:
    types: [new-image-pushed]
```

**jobs 섹션 마지막에 추가:**
```yaml
  notify-discord:
    name: Discord 알림
    needs: integration-test
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Send Discord notification
        uses: sarisia/actions-status-discord@v1
        with:
          webhook: ${{ secrets.DISCORD_WEBHOOK_URL }}
          status: ${{ needs.integration-test.result }}
          title: "🚀 배포 준비 완료"
          description: |
            **서비스:** ${{ github.event.client_payload.service }}
            **버전:** ${{ github.event.client_payload.version }}
            **커밋:** ${{ github.event.client_payload.commit }}
            **푸시한 사람:** @${{ github.event.client_payload.actor }}

            ✅ 통합 테스트: 성공

            EC2 배포를 원하시면 GitHub Actions에서 수동으로 실행하세요:
            https://github.com/ressKim-io/wealist-deploy-test/actions
          color: 0x00ff00
```

---

## 🧪 테스트 절차

### 1. 설정 완료 확인
```bash
# Secrets 확인 (값은 보이지 않음)
# GitHub 웹에서: Settings → Secrets 확인
```

### 2. 테스트 Push
```bash
# User Service 테스트
cd weAlist-User
echo "# Test auto trigger" >> README.md
git add README.md
git commit -m "Test: Discord notification trigger"
git push
```

### 3. 결과 확인
1. GitHub Actions (User-fork) → "Build and Push" 성공 확인
2. GitHub Actions (wealist-deploy) → "Integration Test" 자동 실행 확인
3. Discord 채널 → 알림 메시지 확인
4. GitHub Actions (wealist-deploy) → 수동으로 "Deploy to EC2" 실행

---

## 📝 예상 플로우

```
1. 개발자가 User/Board 코드 수정
2. git push origin main
3. GitHub Actions 자동 실행
   ├─ Docker 이미지 빌드
   ├─ Docker Hub 업로드
   └─ wealist-deploy 트리거 (repository_dispatch)
4. wealist-deploy 자동 실행
   ├─ 최신 이미지 Pull
   ├─ 통합 테스트 실행
   └─ Discord 알림 전송
5. Discord에서 알림 확인
6. GitHub Actions에서 수동으로 "Deploy" 버튼 클릭
7. EC2 배포 실행
```

---

## 🔍 트러블슈팅

### Discord 알림이 안 오면?
- [ ] `DISCORD_WEBHOOK_URL` Secret 확인
- [ ] Webhook URL 형식 확인 (`https://discord.com/api/webhooks/...`)
- [ ] Discord 채널에서 Webhook이 삭제되지 않았는지 확인

### wealist-deploy가 트리거되지 않으면?
- [ ] `DEPLOY_TRIGGER_TOKEN` Secret 확인
- [ ] Token 권한 확인 (`repo`, `workflow`)
- [ ] Token 만료 확인

### 통합 테스트가 실패하면?
- [ ] `.env` 파일 확인
- [ ] Docker 이미지 Pull 성공 확인
- [ ] 로그 확인: `docker compose logs`

---

## 📚 참고 문서

- [GitHub Repository Dispatch](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)
- [Discord Webhooks Guide](https://discord.com/developers/docs/resources/webhook)
- [GitHub Actions - workflow_dispatch](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)

---

## ⏭️ 향후 개선 사항

- [ ] Slack 통합 (Discord 대신 또는 추가)
- [ ] 배포 승인 투표 시스템 (팀원 과반수 승인)
- [ ] 자동 롤백 기능
- [ ] 카나리 배포 (10% 트래픽 → 100%)
- [ ] 배포 스케줄링 (업무 시간만 배포)

---

**작성일:** 2025-10-26
**담당자:** @ressKim-io
