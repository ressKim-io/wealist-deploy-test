# Token Optimization Guide for Claude Code

> **목적:** Claude Code 사용 시 토큰을 효율적으로 사용하여 더 많은 작업을 완료하고 비용을 절감합니다.

## 🎯 핵심 원칙

1. **필요한 정보만 출력**
2. **실패한 방법은 빨리 포기**
3. **작은 단계로 검증**
4. **로그는 최소화**

---

## 📋 전략별 가이드

### 1. 로그 최소화 (가장 중요!)

**❌ 나쁜 예:**
```bash
docker compose logs user-service --tail=100
# → 불필요한 긴 로그 전체 출력, 토큰 낭비
```

**✅ 좋은 예:**
```bash
# 핵심만 grep으로 필터링
docker compose logs user-service --tail=50 | grep -E "Started|ERROR|Exception"

# 성공/실패만 확인
docker compose logs user-service --tail=20 | grep "Started" && echo "SUCCESS" || echo "FAILED"

# 특정 에러만 찾기
docker compose logs user-service 2>&1 | grep -A 3 "ERROR"
```

**절약 효과:** 로그 1회당 3,000~5,000 토큰 절약

---

### 2. 빌드 검증 단계 분리

**점진적 검증 (Fast-Fail):**

```bash
# Step 1: 컴파일만 먼저 (가장 빠름)
./gradlew compileJava
# → 문법 오류만 확인, 1~2초 소요

# Step 2: 성공하면 전체 빌드
./gradlew build -x test
# → 테스트 제외하고 빌드

# Step 3: 성공하면 Docker 배포
docker compose up -d user-service

# Step 4: 로그 확인 (핵심만)
docker compose logs user-service --tail=30 | grep -E "Started|ERROR"
```

**절약 효과:** 실패 시 빠르게 발견, 5,000~10,000 토큰 절약

---

### 3. 실패한 방법 빨리 포기

**기준:**
- ✅ 같은 에러 **2회 반복** → 접근 방식 변경
- ✅ 에러 메시지 동일 → 다른 해결책 시도
- ❌ 같은 방법 3회 이상 시도 금지

**예시:**
```
시도 1: implements Ordered 추가 → 실패
시도 2: GenericFilterBean 변경 → 같은 에러
→ 방향 전환 필요! (예: WebSearch로 공식 해결책 찾기)
```

**절약 효과:** 무의미한 반복 방지, 20,000+ 토큰 절약

---

### 4. WebSearch 적극 활용

**언제 사용:**
- 같은 에러가 2회 반복될 때
- 공식 문서/StackOverflow에 답이 있을 가능성이 높을 때
- Spring, Docker 등 well-known 기술 스택 문제

**예시:**
```bash
# 5,000 토큰으로 정확한 해결책 찾기
WebSearch: "Spring Security 6 OncePerRequestFilter registered order"
WebSearch: "Docker build cache not reflecting source changes"
```

**절약 효과:** 시행착오 없이 직접 해결, 15,000~30,000 토큰 절약

---

### 5. 근본 원인 먼저 파악

**❌ 나쁜 접근:**
- 에러 메시지만 보고 표면적 해결 시도
- "이것도 해보고 저것도 해보고"

**✅ 좋은 접근:**
1. **에러 메시지 분석:** "왜 이 에러가 발생하는가?"
2. **원인 추정:** "순환참조 vs 필터 등록 문제?"
3. **가설 검증:** 가장 가능성 높은 것부터 시도
4. **실패 시 피벗:** 원인 재분석 → 다른 가설

**예시:**
```
에러: "Filter does not have registered order"
❌ 단순 시도: @Order 추가, Ordered 인터페이스, GenericFilterBean...
✅ 분석: Spring Security 6.x가 필터 등록 방식 변경? → WebSearch → @Bean 등록 필요
```

**절약 효과:** 정확한 진단으로 1~2회 시도로 해결, 30,000+ 토큰 절약

---

### 6. 작업 중단/전환 기준

**명확한 기준 설정:**

| 토큰 사용량 | 상황 | 조치 |
|------------|------|------|
| ~30% (60k) | 같은 문제 3회 실패 | `/compact` 실행 또는 방향 전환 |
| ~50% (100k) | 진전 없음 | 새 세션 시작 고려 |
| ~70% (140k) | 복잡한 문제 | 즉시 중단, 사용자에게 보고 |

**체크리스트:**
- [ ] 같은 에러 3회 이상 반복?
- [ ] 30분 이상 진전 없음?
- [ ] 토큰 50% 이상 사용?
→ **하나라도 해당되면 중단 고려**

---

### 7. 효율적인 명령어 체이닝

**한 번에 여러 작업 수행:**

```bash
# ✅ 성공 시에만 다음 단계 (&&)
cd user && ./gradlew compileJava && ./gradlew build && echo "BUILD SUCCESS"

# ✅ 실패 시 메시지만 (||)
./gradlew build -x test || echo "BUILD FAILED"

# ✅ 성공 여부만 확인
./gradlew compileJava > /dev/null 2>&1 && echo "OK" || echo "FAIL"

# ✅ 체이닝으로 빌드+배포+확인
cd user && \
  ./gradlew build -x test && \
  docker compose up -d user-service && \
  sleep 5 && \
  docker compose logs user-service --tail=20 | grep "Started"
```

**절약 효과:** 도구 호출 횟수 감소, 3,000~5,000 토큰 절약

---

### 8. 불필요한 파일 읽기 최소화

**❌ 나쁜 예:**
```bash
# 전체 파일 읽기 (큰 파일인 경우 토큰 낭비)
Read: build.gradle (전체)
Read: docker-compose.yaml (전체)
```

**✅ 좋은 예:**
```bash
# 특정 부분만 grep
grep "dependencies" build.gradle
grep "user-service" docker-compose.yaml -A 10

# 라인 범위 지정
Read: build.gradle (offset: 0, limit: 50)
```

**절약 효과:** 대용량 파일 처리 시 5,000~10,000 토큰 절약

---

## 🔧 실전 적용 예시

### Case 1: Spring Boot 빌드 에러

```bash
# 1단계: 컴파일만 (2초, 1k 토큰)
./gradlew compileJava

# 실패 시 에러만 확인
./gradlew compileJava 2>&1 | grep "error:"

# 2단계: 수정 후 전체 빌드 (10초, 3k 토큰)
./gradlew build -x test

# 3단계: 성공 시 Docker (20초, 3k 토큰)
docker compose up -d user-service

# 4단계: 로그 핵심만 (5초, 2k 토큰)
docker compose logs user-service --tail=30 | grep -E "Started|ERROR"
```

**총 소요:** ~9k 토큰 (기존 방식: ~30k 토큰)

---

### Case 2: Docker 캐시 문제

```bash
# ❌ 비효율적 (20k 토큰)
docker compose build --no-cache user-service  # 전체 로그 출력
docker compose up -d user-service
docker compose logs user-service --tail=100

# ✅ 효율적 (7k 토큰)
docker compose build --no-cache user-service > /dev/null && \
  docker compose up -d user-service && \
  sleep 5 && \
  docker compose logs user-service --tail=20 | grep "Started"
```

---

## 📊 토큰 예산 관리

### 작업별 예상 토큰

| 작업 유형 | 예상 토큰 | 절약 전략 적용 시 |
|---------|---------|---------------|
| 간단한 코드 수정 | 5k~10k | 3k~5k |
| 빌드 에러 수정 | 10k~20k | 5k~10k |
| Docker 문제 해결 | 15k~30k | 8k~15k |
| 복잡한 디버깅 | 30k~60k | 15k~30k |

### 세션당 권장 작업량

- **200k 예산 기준:**
  - 간단한 작업: 10~15개
  - 중간 작업: 5~7개
  - 복잡한 작업: 2~3개

---

## ✅ 체크리스트 (매 작업 시작 전)

```markdown
작업 시작 전:
- [ ] 로그는 grep으로 필터링할 계획인가?
- [ ] 컴파일만 먼저 확인할 수 있는가?
- [ ] 같은 방법을 3회 이상 시도하지 않았는가?
- [ ] WebSearch로 먼저 찾아볼 수 있는가?
- [ ] 토큰 사용량이 30% 미만인가?

작업 중:
- [ ] 에러가 2회 반복되면 방향 전환
- [ ] 불필요한 전체 로그 출력 피하기
- [ ] 성공/실패만 확인 가능한 경우 echo 사용

작업 후:
- [ ] 다음 세션을 위해 핵심 정보만 기록
- [ ] 불필요한 파일/로그 정리
```

---

## 💡 추가 팁

1. **명령어 결합:**
   ```bash
   # 한 번에 여러 작업
   cd dir && build && deploy && verify
   ```

2. **출력 리다이렉션:**
   ```bash
   # 성공 시 출력 숨기기
   command > /dev/null 2>&1
   ```

3. **조건부 실행:**
   ```bash
   # 조건에 따라 분기
   test condition && success_cmd || fail_cmd
   ```

4. **Sleep 최소화:**
   ```bash
   # 대기 시간 줄이기
   sleep 3  # 충분한 경우 5초 대신 3초
   ```

---

## 📝 참고사항

- 이 가이드는 **wealist 프로젝트** 기준으로 작성되었습니다
- Claude Code가 매 세션마다 이 파일을 참조합니다
- 프로젝트 특성에 맞게 수정해서 사용하세요

**마지막 업데이트:** 2025-10-30
**작성자:** 토큰 최적화 경험 기반
