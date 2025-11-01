# Branch Management

**Last Updated**: 2025-10-30

---

## 브랜치 전략 (모노레포)

### 운영 브랜치
- **`main`** - 운영 환경 배포 브랜치 (Production)

### 기능 브랜치
- **`feature/*`** - 새로운 기능 개발
  - `feature/user-*` - User Service 관련
  - `feature/board-*` - Board Service 관련
  - `feature/frontend-*` - Frontend 관련
  - `feature/infra-*` - 인프라 및 공통 설정
- **`fix/*`** - 버그 수정
- **`refactor/*`** - 리팩토링

---

## 현재 브랜치 현황 (통합 저장소)

### Active Branches

#### `main` (운영)
- **Status**: ✅ 안정
- **Last Commit**: `e444836 - 순환참조 문제 해결`
- **Recent Changes**:
  - 모노레포 통합 완료 (backend 합치기, frontend 추가)
  - Docker Compose 통합
  - 순환참조 문제 해결
  - API documentation URL 수정

### Remote Branches

```
* main
  remotes/origin/composal
  remotes/origin/main
```

---

## 최근 병합 이력

### 2025-10-29 ~ 2025-10-30: 모노레포 통합
```
backend 합치기 + frontend 추가 + docker-compose 통합
- User Service와 Board Service를 하나의 저장소로 통합
- Frontend 추가
- 공유 PostgreSQL 및 Redis 설정
- API 문서 URL 수정
- 순환참조 문제 해결
```

**Recent Commits**:
```
e444836 순환참조 문제 해결
1498164 Fix API documentation URLs for Swagger and Health Check
67242b3 front 재업로드
2fb7278 front 추가
b97dd02 프론트 gitignore
7b8cf86 backend 합치기
132e1f0 gitignore
```

---

## Git 워크플로우

### 새 기능 개발 시작

1. **기존 브랜치 확인**
```bash
git branch -a
cat .claude/branches.md
```

2. **main에서 브랜치 생성**
```bash
git checkout main
git pull origin main
git checkout -b feature/new-feature-name
```

3. **개발 진행**
```bash
# 작업 수행
git add .
git commit -m "feat: Add new feature"
```

4. **원격 푸시**
```bash
git push -u origin feature/new-feature-name
```

### 브랜치 병합 (main으로)

1. **main 동기화**
```bash
git checkout main
git pull origin main
```

2. **기능 브랜치 병합**
```bash
git merge feature/branch-name
```

3. **원격 푸시**
```bash
git push origin main
```

4. **branches.md 업데이트**
```bash
# 이 파일을 업데이트하여 병합 완료 기록
```

---

## 브랜치 클린업 가이드

### 로컬 브랜치 삭제
```bash
git branch -d feature/branch-name
```

### 원격 브랜치 삭제
```bash
git push origin --delete feature/branch-name
```

### 병합된 브랜치 확인
```bash
git branch --merged main
```

---

## 클린업 대상 브랜치

### 가능한 클린업 후보

#### `origin/composal`
- **Status**: ✅ 확인 완료 (2025-10-30)
- **Description**: Docker Compose 통합 및 디렉토리 구조 단순화 브랜치
- **주요 변경사항**:
  - `board/services/kanban/` → `kanban-service/` (루트로 이동 및 평탄화)
  - `user/` → `user-service/` (이름 변경)
  - 각 서비스별 docker-compose.yaml 삭제 → 루트 docker-compose.yaml 통합
  - frontend/Dockerfile 추가
  - 단일 네트워크 (wealist-network) 및 환경 변수 통합
- **Commits**:
  - `402f972` - (최신)
  - `4a8fd92` - docker-compose 통합
- **Action**:
  - ⚠️ main 브랜치가 이미 모노레포 통합 완료 상태
  - composal은 다른 접근 방식 (디렉토리 구조 변경)
  - **보류**: JWT 작업 후 어떤 구조를 사용할지 결정 필요
- **Check Command**: `git log main..origin/composal --oneline`

---

## 브랜치 네이밍 규칙 (모노레포)

### 기능 개발
```
feature/descriptive-name
feature/user-redis-cache          # User Service 관련
feature/board-websocket           # Board Service 관련
feature/frontend-auth-flow        # Frontend 관련
feature/infra-docker-optimization # 인프라/공통
```

### 버그 수정
```
fix/descriptive-name
fix/user-login-error              # User Service 버그
fix/board-database-connection     # Board Service 버그
fix/frontend-routing              # Frontend 버그
```

### 리팩토링
```
refactor/descriptive-name
refactor/user-improve-performance
refactor/board-clean-code
```

### 이슈 번호 포함
```
feature/#123-add-feature
fix/#456-resolve-bug
```

---

## 커밋 메시지 규칙

### 형식
```
<type>: <subject>

<body>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 타입
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `docs`: 문서만 변경
- `style`: 코드 의미에 영향을 주지 않는 변경 (포맷팅 등)
- `refactor`: 버그 수정이나 기능 추가가 아닌 코드 변경
- `perf`: 성능 개선
- `test`: 테스트 추가 또는 수정
- `chore`: 빌드 프로세스 또는 보조 도구 변경

### 예시
```
feat: Add Redis integration to User Service

- Add spring-boot-starter-data-redis dependency
- Create RedisConfig with Lettuce connection factory
- Configure Redis connection in application.yml
- Fix circular dependency by adding @Lazy to SecurityConfig

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## 충돌 해결

### Pull 시 충돌 발생
```bash
# Merge 전략 사용
git pull --no-rebase origin main

# 충돌 파일 확인
git status

# 충돌 해결 후
git add .
git commit -m "Merge conflict resolution"
git push origin main
```

### 분기된 브랜치 (Divergent Branches)
```bash
# 옵션 1: Merge (권장)
git config pull.rebase false
git pull origin main

# 옵션 2: Rebase
git config pull.rebase true
git pull origin main

# 옵션 3: Fast-forward only
git config pull.ff only
git pull origin main
```

---

## 주의사항 (모노레포)

1. **main 브랜치 보호**: main에 직접 커밋하지 말고 feature 브랜치에서 작업
2. **브랜치 확인**: 새 브랜치 생성 전 기존 브랜치 확인 (중복 작업 방지)
3. **정기적 동기화**: 자주 main과 동기화하여 충돌 최소화
4. **branches.md 업데이트**: 병합/삭제 시 이 파일 업데이트
5. **Force Push 주의**: 공유 브랜치에 force push 금지
6. **서비스별 영향 범위**: 한 서비스 수정 시 다른 서비스에 미치는 영향 고려
7. **통합 테스트**: 여러 서비스에 걸친 변경 시 통합 테스트 필수

---

## 참고 명령어

### 브랜치 정보 조회
```bash
# 로컬 브랜치 목록
git branch

# 원격 브랜치 포함 전체 목록
git branch -a

# 마지막 커밋 메시지와 함께 표시
git branch -v

# 병합된 브랜치 확인
git branch --merged

# 병합되지 않은 브랜치 확인
git branch --no-merged
```

### 브랜치 비교
```bash
# main과 현재 브랜치 차이
git diff main

# 커밋 로그 비교
git log main..feature/branch-name --oneline
```

### 원격 브랜치 동기화
```bash
# 원격 브랜치 목록 갱신
git fetch --prune

# 삭제된 원격 브랜치 정리
git remote prune origin
```
