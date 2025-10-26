# 첫 배포 가이드

첫 배포 시 데이터베이스 스키마를 생성해야 합니다.

## 문제 상황

- **JPA_DDL_AUTO=validate**: 테이블이 존재하는지만 검증 (테이블 생성 안 함)
- 첫 배포 시에는 테이블이 없어서 서비스가 시작되지 않음

## 해결 방법 (택 1)

### 방법 1: 임시로 JPA_DDL_AUTO=update 사용 (권장)

**1단계: .env 파일 수정**
```bash
# .env 파일에서 임시로 update로 변경
JPA_DDL_AUTO=update
```

**2단계: 첫 배포 실행**
```bash
./deploy.sh
```

**3단계: 스키마 생성 확인**
```bash
# User Service 로그 확인
docker compose logs user-service | grep -i "schema"

# DB 접속해서 테이블 확인
docker exec -it wealist-postgres psql -U user_service -d wealist_user_db -c "\dt"
```

**4단계: validate로 변경 (중요!)**
```bash
# .env 파일 수정
JPA_DDL_AUTO=validate

# 서비스 재시작
docker compose restart user-service
```

**5단계: 정상 동작 확인**
```bash
curl http://localhost:8081/health
```

---

### 방법 2: SQL 스크립트 수동 실행

User Service의 엔티티에서 DDL을 추출하여 수동 실행합니다.

**1단계: User Service에서 DDL 추출**

로컬 개발 환경에서:
```properties
# application.yml 또는 application.properties
spring.jpa.properties.javax.persistence.schema-generation.scripts.action=create
spring.jpa.properties.javax.persistence.schema-generation.scripts.create-target=schema.sql
```

실행 후 `schema.sql` 파일 생성됨.

**2단계: SQL 스크립트 실행**
```bash
# schema.sql을 컨테이너에 복사
docker cp schema.sql wealist-postgres:/tmp/

# PostgreSQL에서 실행
docker exec -it wealist-postgres psql -U user_service -d wealist_user_db -f /tmp/schema.sql
```

**3단계: 배포 실행**
```bash
# .env에서 JPA_DDL_AUTO=validate 확인
./deploy.sh
```

---

## Kanban Service는?

Kanban Service는 **Alembic 마이그레이션**을 사용하므로 `deploy.sh`에서 자동으로 처리됩니다:

```bash
docker compose run --rm kanban-service alembic upgrade head
```

## 이후 배포

첫 배포 이후에는 `JPA_DDL_AUTO=validate`로 유지하고 스키마 변경은:
- **User Service**: Flyway/Liquibase 도입 또는 수동 SQL 관리
- **Kanban Service**: Alembic 마이그레이션 계속 사용

## 트러블슈팅

### User Service가 시작되지 않을 때

```bash
# 로그 확인
docker compose logs user-service

# "Table 'xxx' doesn't exist" 에러가 보이면
# → JPA_DDL_AUTO=update로 변경 후 재배포
```

### 스키마가 생성되었는지 확인

```bash
# User DB 테이블 목록
docker exec -it wealist-postgres psql -U user_service -d wealist_user_db -c "\dt"

# Kanban DB 테이블 목록
docker exec -it wealist-postgres psql -U kanban_service -d wealist_kanban_db -c "\dt"

# Alembic 버전 확인
docker exec -it wealist-postgres psql -U kanban_service -d wealist_kanban_db -c "SELECT * FROM alembic_version;"
```

## 실무 권장사항

### 개발 환경
```env
JPA_DDL_AUTO=update  # 자동 스키마 업데이트
```

### 스테이징/운영 환경
```env
JPA_DDL_AUTO=validate  # 검증만 (안전)
```

그리고 마이그레이션 도구 사용:
- User Service: **Flyway** 또는 **Liquibase** 도입
- Kanban Service: **Alembic** 계속 사용

## 참고: Flyway 도입 (선택)

User Service에 Flyway를 추가하면 자동 마이그레이션 가능:

```gradle
// build.gradle
implementation 'org.flywaydb:flyway-core'
```

```sql
-- src/main/resources/db/migration/V1__init.sql
CREATE TABLE users (...);
```

이후 배포 시 자동으로 마이그레이션 실행됩니다.
