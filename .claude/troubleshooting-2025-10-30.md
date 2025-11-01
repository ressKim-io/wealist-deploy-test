# JWT 필터 순환참조 & 필터 등록 문제 해결 (2025-10-30)

## 🔥 문제 1: 순환참조로 인한 무한 재시작

### 증상
```
User Service가 무한 재시작 반복
Circular dependency 에러 발생
```

### 근본 원인
```java
SecurityConfig
  └── @Bean PasswordEncoder  // PasswordEncoder 생성
      (사용)
  └── @Bean SecurityFilterChain
      └── AuthService 주입 필요
          └── PasswordEncoder 필요 (다시 SecurityConfig로 돌아감)
```

**순환 구조:**
1. SecurityConfig가 PasswordEncoder Bean 생성
2. SecurityConfig가 AuthService 주입 받음
3. AuthService가 PasswordEncoder 필요
4. PasswordEncoder는 SecurityConfig에서 생성 중 → **순환!**

### 해결 방법
**PasswordEncoder를 별도의 Configuration으로 분리**

#### 생성한 파일: `PasswordEncoderConfig.java`
```java
package OrangeCloud.UserRepo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class PasswordEncoderConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

#### 수정한 파일: `SecurityConfig.java`
```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    // ❌ 제거: @Bean PasswordEncoder
    // ✅ PasswordEncoderConfig에서 관리

    @Bean
    public SecurityFilterChain filterChain(
            HttpSecurity http,
            JwtTokenProvider jwtTokenProvider,
            AuthService authService  // PasswordEncoder는 별도 Bean에서 주입됨
    ) throws Exception {
        // ... filter configuration
    }
}
```

#### 왜 이렇게 하면 해결되는가?
1. **PasswordEncoder**: PasswordEncoderConfig에서 독립적으로 생성 (먼저)
2. **AuthService**: PasswordEncoder Bean을 주입받음
3. **SecurityConfig**: AuthService Bean을 주입받음
4. 순환 없이 순차적으로 Bean 생성 완료 ✅

---

## 🔥 문제 2: "The Filter does not have a registered order"

### 증상
```
ERROR: The Filter class OrangeCloud.UserRepo.filter.JwtAuthenticationFilter
       does not have a registered order
```

순환참조는 해결했지만, 필터 등록 시 새로운 에러 발생

### 근본 원인
**Spring Security의 FilterOrderRegistration 메커니즘**

Spring Security 6.x는 내부적으로 `FilterOrderRegistration` 클래스에서 필터 순서를 관리합니다.

```java
// ❌ 잘못된 코드 (SecurityConfig.java:58)
.addFilterBefore(jwtExceptionFilter, JwtAuthenticationFilter.class)
.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
```

**문제점:**
- `JwtAuthenticationFilter.class`는 **커스텀 필터**
- FilterOrderRegistration에 **등록되지 않은 필터**
- `addFilterBefore(A, B)` 사용 시 B는 반드시 **등록된 필터**여야 함
- 등록되지 않은 필터를 anchor로 사용 → **에러 발생**

**FilterOrderRegistration에 등록된 필터 예시:**
- `UsernamePasswordAuthenticationFilter`
- `BasicAuthenticationFilter`
- `CorsFilter`
- `CsrfFilter`
- 등등... (Spring Security 내장 필터들)

### 해결 방법
**모든 필터를 등록된 필터(UsernamePasswordAuthenticationFilter)를 anchor로 변경**

#### 수정 전 (❌ 에러 발생)
```java
// JWT 예외 처리 필터를 JWT 인증 필터 앞에 추가
.addFilterBefore(jwtExceptionFilter, JwtAuthenticationFilter.class)  // ❌ 커스텀 필터를 anchor로 사용
// JWT 인증 필터 추가
.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
```

#### 수정 후 (✅ 정상 작동)
```java
// JWT 인증 필터 추가 (UsernamePasswordAuthenticationFilter 전)
.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
// JWT 예외 처리 필터 추가 (가장 앞에 배치되어 exception 처리)
.addFilterBefore(jwtExceptionFilter, UsernamePasswordAuthenticationFilter.class)
```

#### 실제 필터 체인 순서
Spring Security는 같은 anchor에 대해 **나중에 추가된 필터가 앞에** 배치됩니다:

```
Request
  → JwtExceptionFilter (두 번째로 추가됨, 가장 앞에 위치)
    → JwtAuthenticationFilter (첫 번째로 추가됨)
      → UsernamePasswordAuthenticationFilter
        → ...
```

**왜 이 순서가 중요한가?**
1. **JwtExceptionFilter가 가장 앞**: JWT 검증 중 발생한 예외를 catch해서 JSON 응답으로 변환
2. **JwtAuthenticationFilter**: 실제 JWT 토큰 검증 및 인증 처리
3. **UsernamePasswordAuthenticationFilter**: 기본 인증 (우리는 사용 안 함)

---

## 📊 결과

### Before (문제 상황)
```
❌ User Service 무한 재시작
❌ Circular dependency 에러
❌ Filter order registration 에러
```

### After (해결 완료)
```
✅ User Service 정상 시작 (3.7초)
✅ Tomcat started on port 8080
✅ Health check: 200 OK
✅ Status: Up (healthy)
```

### 수정된 파일 목록
1. **생성:** `user/src/main/java/OrangeCloud/UserRepo/config/PasswordEncoderConfig.java`
2. **수정:** `user/src/main/java/OrangeCloud/UserRepo/config/SecurityConfig.java`

---

## 🎓 핵심 교훈

### 1. 순환참조 해결 원칙
- **Configuration 분리**: 관심사가 다른 Bean은 별도 Configuration으로 분리
- **PasswordEncoder처럼 여러 곳에서 사용되는 Bean은 독립적인 Configuration으로**
- `@Lazy`는 임시방편, 근본적 해결책은 아님

### 2. Spring Security Filter 등록 원칙
- `addFilterBefore(A, B)`에서 **B는 반드시 FilterOrderRegistration에 등록된 필터여야 함**
- 커스텀 필터끼리는 서로 anchor로 사용 불가
- 모든 커스텀 필터는 **Spring Security 내장 필터를 anchor로 사용**

### 3. 디버깅 시 주의사항
- Docker 빌드 캐시 문제로 코드 변경이 반영 안 될 수 있음
- `docker compose build --no-cache`로 완전히 새로 빌드
- 로컬 JAR 먼저 빌드 후 Docker 이미지 생성 권장

---

## 🔍 참고 자료

### WebSearch 결과
- Spring Security 6.x에서 `FilterOrderRegistration` 메커니즘 확인
- GitHub Issue: spring-projects/spring-boot#31142
- `addFilterBefore()`는 anchor 필터가 등록되어 있어야 함

---

**작성일:** 2025-10-30
**해결 시간:** WebSearch로 근본 원인 파악 후 5분 이내 해결
**이전 시도:** 7~8회 실패 (Ordered 인터페이스, @Order, GenericFilterBean 등)
**성공 요인:** WebSearch로 공식 문서 및 Issue 확인 → 정확한 해결책 적용
