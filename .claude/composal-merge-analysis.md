# composal 브랜치 → main 브랜치 병합 분석 (임시 메모)

**작성일**: 2025-10-31
**목적**: composal 브랜치의 디렉토리 구조를 main으로 병합 준비

---

## 📁 디렉토리 구조 비교

### main 브랜치 (현재 monorepo 구조)
```
wealist/
├── board/
│   ├── infrastructure/        # 개별 docker-compose 설정
│   │   ├── .env.example
│   │   ├── .gitignore
│   │   ├── README.md
│   │   └── docker-compose.yaml
│   └── services/kanban/       # FastAPI 서비스
│       ├── alembic/
│       ├── app/
│       ├── scripts/
│       ├── tests/
│       ├── API_DOCUMENTATION.md
│       ├── API_TEST_GUIDE.md
│       ├── Dockerfile
│       └── docker-compose.yaml
├── user/                      # Spring Boot 서비스
│   ├── src/
│   ├── build.gradle
│   └── API_DOCUMENTATION.md
├── frontend/                  # React 서비스
│   ├── src/
│   └── package.json
├── docker-compose.yaml        # 루트 통합 설정 (multi-DB 전략)
├── .env
├── .env.example              # 환경 변수 템플릿
└── init-db.sh                # PostgreSQL 초기화 스크립트
```

### composal 브랜치 (통합 평탄화 구조)
```
wealist/
├── kanban-service/            # FastAPI 서비스 (평탄화됨 - 루트 레벨)
│   ├── alembic/
│   ├── app/
│   ├── scripts/
│   ├── tests/
│   ├── API_DOCUMENTATION.md
│   ├── API_TEST_GUIDE.md
│   ├── Dockerfile
│   └── README.md
├── user/                      # Spring Boot 서비스 (기존)
│   └── (동일 구조)
├── user-service/              # ⚠️ Spring Boot 서비스 (중복? 확인 필요)
│   ├── gradle/
│   └── src/
├── frontend/                  # React 서비스
│   ├── Dockerfile             # ✅ 추가됨
│   └── (동일 구조)
├── docker-compose.yaml        # 루트 통합 설정 (단일 DB 전략)
├── .env                       # 환경 변수
├── README.md                  # ✅ 추가됨 (루트 레벨)
├── init-db.sh
└── .gitignore                 # 수정됨
```

---

## 🔑 주요 차이점 정리

| 항목 | main 브랜치 | composal 브랜치 | 영향도 |
|------|------------|----------------|--------|
| **Board 서비스 경로** | `board/services/kanban/` | `kanban-service/` (루트) | ⚠️ **높음** - 모든 import/path 수정 필요 |
| **Infrastructure 폴더** | `board/infrastructure/` 존재 | 삭제됨 | ⚠️ **높음** - 개별 docker-compose 제거 |
| **개별 docker-compose** | 각 서비스별 있음 | 모두 삭제 (통합만 사용) | ⚠️ **중간** - 개발 워크플로우 변경 |
| **user-service 폴더** | 없음 | 추가됨 (user와 중복?) | ⚠️ **높음** - 중복 여부 확인 필수 |
| **frontend Dockerfile** | 없음 | 추가됨 | ✅ **낮음** - 추가 기능 |
| **README.md** | 없음 | 루트에 추가됨 | ✅ **낮음** - 문서화 개선 |
| **.env.example** | 있음 | 삭제됨 | ⚠️ **중간** - 환경 변수 템플릿 손실 |
| **.gitignore** | 기존 | 수정됨 | 🔍 **확인 필요** |

---

## 📦 composal 브랜치의 주요 변경사항

### 1. Board 서비스 평탄화
- **변경**: `board/services/kanban/` → `kanban-service/`
- **이유**: 디렉토리 계층 단순화 (중첩 제거)
- **영향**:
  - docker-compose.yaml의 build context 변경
  - Dockerfile 경로 변경
  - 개발 환경 경로 변경

### 2. Infrastructure 폴더 제거
- **제거된 파일들**:
  - `board/infrastructure/.env.example`
  - `board/infrastructure/.gitignore`
  - `board/infrastructure/README.md`
  - `board/infrastructure/docker-compose.yaml`
  - `board/services/kanban/.env.example`
  - `board/services/kanban/docker-compose.dev.yaml`
  - `board/services/kanban/docker-compose.yaml`
- **이유**: 개별 docker-compose 제거, 통합 운영 전략
- **영향**: 개별 서비스 독립 실행 불가 (통합 실행만 가능)

### 3. User Service 중복 가능성
- **확인 필요**: `user/`와 `user-service/` 두 폴더 존재
- **가능성**:
  1. `user-service/`가 새 구조이고 `user/`는 레거시
  2. `user/`가 실제 코드이고 `user-service/`는 빌드 아티팩트
  3. 실수로 중복 생성
- **조치**: 내용 비교 후 하나로 통합 필요

### 4. docker-compose.yaml 구조 차이

#### main 브랜치 (Multi-Database 전략):
```yaml
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_SUPERUSER}
      # 여러 DB 생성 스크립트 사용
      USER_DB_NAME: ${USER_DB_NAME}
      KANBAN_DB_NAME: ${KANBAN_DB_NAME}
    volumes:
      - ./init-db.sh:/docker-entrypoint-initdb.d/init-db.sh

  user-service:
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/${USER_DB_NAME}
      - SPRING_REDIS_DATABASE=0

  kanban-service:
    environment:
      - DATABASE_URL=postgresql://.../postgres:5432/${KANBAN_DB_NAME}
      - REDIS_URL=redis://.../redis:6379/1
```

#### composal 브랜치 (Single-Database 전략):
```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}        # 단일 DB
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    # init-db.sh 사용하지 않음

  kanban-service:
    environment:
      DATABASE_URL: postgresql://.../postgres:${POSTGRES_PORT}/${POSTGRES_DB}
      REDIS_URL: redis://.../redis:${REDIS_PORT}/0

  user-service:
    environment:
      # (확인 필요 - 파일이 잘림)
```

**⚠️ 중요한 차이점**:
- main: 각 서비스가 독립적인 DB 사용 (마이크로서비스 원칙)
- composal: 단일 DB 공유 (모놀리식 접근)

---

## 🚨 병합 시 주의사항

### 1. 데이터베이스 전략 충돌
- **문제**: main은 multi-DB, composal은 single-DB
- **해결**: 어느 전략을 유지할지 결정 필요
- **권장**: main의 multi-DB 전략 유지 (마이크로서비스 격리)

### 2. 경로 변경 영향 범위
- **영향받는 파일들**:
  - `docker-compose.yaml` - build context
  - `.claudeignore` - 경로 패턴
  - `CLAUDE.md` - 문서 내 경로 참조
  - CI/CD 스크립트 (있다면)
  - IDE 설정 파일

### 3. .env.example 손실
- composal에서 삭제됨
- main의 `.env.example` 내용 보존 필요

### 4. user/user-service 중복 해결
- 병합 전 반드시 확인 필요
- 빌드 및 런타임 테스트 필수

---

## ✅ 권장 병합 전략

### Phase 1: 조사 및 준비
1. ✅ composal 브랜치의 user/user-service 폴더 내용 비교
2. ✅ composal 브랜치의 docker-compose.yaml 전체 내용 확인
3. ✅ composal 브랜치의 README.md 내용 확인
4. ✅ .gitignore 변경사항 확인

### Phase 2: Feature 브랜치 생성
```bash
git checkout main
git checkout -b feature/merge-composal-structure
```

### Phase 3: 선택적 병합
1. **채택할 변경사항**:
   - ✅ Board 서비스 평탄화 (kanban-service/)
   - ✅ Infrastructure 폴더 제거 (개별 docker-compose 삭제)
   - ✅ frontend Dockerfile 추가
   - ✅ 루트 README.md 추가
   - ✅ .gitignore 개선사항

2. **main 브랜치 유지사항**:
   - ⚠️ Multi-Database 전략 유지
   - ⚠️ .env.example 보존
   - ⚠️ PostgreSQL 17-alpine 버전 유지
   - ⚠️ Redis DB 분리 전략 유지

3. **확인 후 결정**:
   - ❓ user vs user-service 중복 문제
   - ❓ init-db.sh 사용 여부

### Phase 4: 테스트
1. docker-compose up 성공 여부
2. User Service 빌드 및 실행
3. Kanban Service 빌드 및 실행
4. Frontend 빌드 및 실행
5. 서비스 간 통신 확인

### Phase 5: 문서 업데이트
1. CLAUDE.md 경로 업데이트
2. .claude/context.md 업데이트
3. API_DOCUMENTATION.md 경로 수정

---

## 🔍 즉시 확인 필요 사항

### 1. user vs user-service 비교
```bash
# composal 브랜치에서
git checkout composal
ls -la user/
ls -la user-service/
diff -r user/ user-service/ | head -50
```

### 2. composal docker-compose.yaml 전체 내용
```bash
git show composal:docker-compose.yaml
```

### 3. composal README.md 내용
```bash
git show composal:README.md
```

### 4. .gitignore 변경사항
```bash
git diff main composal -- .gitignore
```

---

## 📝 다음 작업 시 할 일

1. **user/user-service 중복 조사**
2. **composal docker-compose.yaml 전체 분석**
3. **병합 전략 최종 결정** (multi-DB vs single-DB)
4. **feature 브랜치 생성**
5. **단계별 병합 진행**

---

**메모 종료** - 나중에 이 파일 참고하여 작업 진행
