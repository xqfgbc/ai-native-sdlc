#!/usr/bin/env bash
#
# scripts/new-service.sh — scaffold a new Spring Cloud microservice module
# for the AI-Native SDLC framework.
#
# The module joins the build automatically: settings.gradle.kts includes any
# services/<name>/ that contains a build.gradle.kts.
#
# Stack: JDK 21, Spring Boot 4.x, Spring Cloud 2025.1 (Oakwood), Kubernetes-
# native discovery (spring-cloud-kubernetes), Spring Cloud Config client,
# AWS RDS PostgreSQL (prod) / H2 (local) / Testcontainers (integration tests).
#
# Usage:
#   ./scripts/new-service.sh <service-name> [port] [base-package]
#
# Example:
#   ./scripts/new-service.sh order-service 8082
#
# Framework reminder: scaffolding is part of the Build stage. Nothing is
# implemented without an accepted plan (plan.md in the intent folder). The
# scaffold gives you the module shell; behavior comes from spec.md + plan.md.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICES_DIR="${ROOT_DIR}/services"

usage() {
  echo "Usage: ./scripts/new-service.sh <service-name> [port] [base-package]" >&2
  echo "  service-name: kebab-case, e.g. order-service" >&2
  exit 1
}

NAME="${1:-}"
PORT_ARG="${2:-}"
PKG_ARG="${3:-}"
[ -n "${NAME}" ] || usage

if ! [[ "${NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "ERROR: service name must be kebab-case (lowercase letters, digits, hyphens)." >&2
  usage
fi

if [ -d "${SERVICES_DIR}/${NAME}" ]; then
  echo "ERROR: services/${NAME} already exists." >&2
  exit 1
fi

# ---- Derived values -------------------------------------------------------

# Class base: strip a trailing "-service" so order-service -> OrderService.
BASE="${NAME}"
if [[ "${BASE}" == *-service ]]; then
  BASE="${BASE%-service}"
fi

PascalCase() {
  local s="$1"
  s="${s//-/ }"
  s="$(echo "${s}" | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i,1,1)) substr($i,2); print }' OFS="")"
  echo "${s}"
}

CLASS_BASE="$(PascalCase "${BASE}")"              # e.g. Order
PKG_SUFFIX="$(echo "${BASE}" | tr -cd 'a-z0-9')"  # e.g. order
PKG="${PKG_ARG:-com.example.${PKG_SUFFIX}}"
JAVA_PKG_DIR="$(echo "${PKG}" | tr '.' '/')"

# Default port: one above the highest port in existing services.
if [ -z "${PORT_ARG}" ]; then
  PORT="$(awk '/^[[:space:]]*port:/ {print $2}' \
      "${SERVICES_DIR}"/*/src/main/resources/application.yml 2>/dev/null \
    | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  PORT="${PORT:-8080}"
  PORT="$((PORT + 1))"
else
  PORT="${PORT_ARG}"
fi

echo "Scaffolding service '${NAME}'"
echo "  package : ${PKG}"
echo "  port    : ${PORT}"
echo "  module  : services/${NAME} (auto-registered via settings.gradle.kts)"

SVC_DIR="${SERVICES_DIR}/${NAME}"
mkdir -p \
  "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/api/dto" \
  "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/core" \
  "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/adapters/persistence/entity" \
  "${SVC_DIR}/src/main/resources" \
  "${SVC_DIR}/src/test/java/${JAVA_PKG_DIR}" \
  "${SVC_DIR}/src/itest/java/${JAVA_PKG_DIR}"

# ---- build.gradle.kts -------------------------------------------------------

cat > "${SVC_DIR}/build.gradle.kts" <<EOF
// Scaffolded by scripts/new-service.sh. Versions come from the platform
// module (which imports the Spring Boot / Spring Cloud / Testcontainers BOMs);
// never add versioned coordinates here — dependency versions are
// platform-owned.

plugins {
    java
    checkstyle
    alias(libs.plugins.spring.boot)
}

dependencies {
    implementation(platform(project(":platform")))

    implementation(libs.spring.boot.starter.webmvc)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.spring.boot.starter.actuator)
    implementation(libs.spring.boot.starter.data.jpa)

    // Kubernetes-native discovery + externalised config + resilience.
    implementation(libs.spring.cloud.starter.kubernetes.client)
    implementation(libs.spring.cloud.starter.config)
    implementation(libs.spring.cloud.starter.circuitbreaker.resilience4j)

    // AWS RDS PostgreSQL in production; H2 for local dev.
    runtimeOnly(libs.postgresql)
    runtimeOnly(libs.h2)

    testImplementation(libs.spring.boot.starter.test)
    testImplementation(libs.spring.boot.testcontainers)
    testImplementation(libs.testcontainers.postgresql)
    testImplementation(libs.testcontainers.junit.jupiter)
    // Deterministic architecture guardrails (see architecture-guardrails skill).
    testImplementation(libs.archunit.junit5)
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("${NAME}.jar")
}
EOF

# ---- Java sources ----------------------------------------------------------

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/${CLASS_BASE}Application.java" <<EOF
package ${PKG};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ${CLASS_BASE}Application {

    public static void main(String[] args) {
        SpringApplication.run(${CLASS_BASE}Application.class, args);
    }
}
EOF

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/api/dto/HelloResponse.java" <<EOF
package ${PKG}.api.dto;

/** Response DTO. Records only; entities never leave the adapters layer. */
public record HelloResponse(String name, String message) {
}
EOF

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/core/HelloService.java" <<EOF
package ${PKG}.core;

import org.springframework.stereotype.Service;

/**
 * Domain logic. May use Spring context annotations (@Service, @Transactional)
 * but must not import web/http classes — see the spring-service-conventions skill.
 */
@Service
public class HelloService {

    public String greet(String name) {
        return "Hello, " + name + " — served by ${NAME}";
    }
}
EOF

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/api/HelloController.java" <<EOF
package ${PKG}.api;

import ${PKG}.api.dto.HelloResponse;
import ${PKG}.core.HelloService;
import jakarta.validation.constraints.Pattern;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller. Every endpoint: validated input, typed DTO response,
 * integration test in src/itest/java (see secure-api-review skill).
 */
@RestController
@Validated
@RequestMapping("/api/${BASE}")
public class HelloController {

    private final HelloService helloService;

    public HelloController(HelloService helloService) {
        this.helloService = helloService;
    }

    @GetMapping("/hello")
    public HelloResponse hello(
            @RequestParam @Pattern(regexp = "[A-Za-z0-9 _-]{1,40}") String name) {
        return new HelloResponse(name, helloService.greet(name));
    }
}
EOF

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/adapters/persistence/entity/package-info.java" <<EOF
/**
 * Persistence is an adapter. Spring Data repositories and JPA entities live
 * here; nothing in api/ touches them directly except through core/ services.
 */
package ${PKG}.adapters.persistence.entity;
EOF

cat > "${SVC_DIR}/src/main/java/${JAVA_PKG_DIR}/adapters/README.md" <<'EOF'
# adapters/

Code that talks to external systems:

- `persistence/` — Spring Data repositories + JPA entities (AWS RDS PostgreSQL
  in production; see the aws-postgres skill for migrations and secret handling).
- HTTP clients (RestClient/WebClient) — must set timeouts and be wrapped with a
  Resilience4j circuit breaker (see the resiliency-review skill).
- Messaging clients (Kafka/SQS) — schema-first; never edit generated classes.

Nothing in `api/` calls an adapter directly; calls go through `core/` services.
EOF

# ---- Resources -------------------------------------------------------------

cat > "${SVC_DIR}/src/main/resources/application.yml" <<EOF
server:
  port: \${SERVER_PORT:${PORT}}

spring:
  application:
    name: ${NAME}
  config:
    # Fail-open for local boot; in the cluster this resolves to the
    # config-server Service via Kubernetes DNS.
    import: "optional:configserver:http://config-server:8888"
  datasource:
    # AWS RDS PostgreSQL — credentials come from the environment / External
    # Secrets Operator, never from committed values.
    url: \${DB_URL:jdbc:postgresql://localhost:5432/${PKG_SUFFIX}}
    username: \${DB_USERNAME:${PKG_SUFFIX}}
    password: \${DB_PASSWORD:}
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
  mvc:
    # RFC 9457 ProblemDetail for every error response (Spring defaults this off).
    problemdetails:
      enabled: true
  cloud:
    kubernetes:
      discovery:
        enabled: true

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      probes:
        enabled: true
EOF

cat > "${SVC_DIR}/src/main/resources/application-local.yml" <<EOF
# Local profile for make run / docker-compose: H2, no Config Server, no
# Kubernetes discovery.
spring:
  config:
    import: ""
  datasource:
    url: jdbc:h2:mem:${PKG_SUFFIX};DB_CLOSE_DELAY=-1
    username: sa
    password: ""
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: update
  cloud:
    kubernetes:
      discovery:
        enabled: false
EOF

cat > "${SVC_DIR}/src/main/resources/application-test.yml" <<EOF
# Test profile: no Config Server, no Kubernetes discovery, H2 by default.
# Integration tests override the datasource with Testcontainers PostgreSQL.
spring:
  config:
    import: ""
  datasource:
    url: jdbc:h2:mem:${PKG_SUFFIX}_test;DB_CLOSE_DELAY=-1
    username: sa
    password: ""
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: update
  cloud:
    kubernetes:
      discovery:
        enabled: false
EOF

# ---- Tests -----------------------------------------------------------------

cat > "${SVC_DIR}/src/test/java/${JAVA_PKG_DIR}/${CLASS_BASE}ApplicationTests.java" <<EOF
package ${PKG};

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class ${CLASS_BASE}ApplicationTests {

    @Test
    void contextLoads() {
    }
}
EOF

cat > "${SVC_DIR}/src/test/java/${JAVA_PKG_DIR}/ArchitectureTest.java" <<EOF
package ${PKG};

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.library.GeneralCodingRules;
import jakarta.persistence.Entity;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.RestController;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

/**
 * Architecture guardrails — deterministic layering/design checks (see the
 * architecture-guardrails skill). A violation fails {@code make test}; fix the
 * code, never weaken a rule (rule changes are a platform-team PR).
 */
class ArchitectureTest {

    private static final JavaClasses CLASSES = new ClassFileImporter().importPackages("${PKG}");

    @Test
    void apiMustNotCallAdaptersDirectly() {
        ArchRule rule = noClasses().that().resideInAPackage("${PKG}.api..")
                .should().dependOnClassesThat().resideInAPackage("${PKG}.adapters..");
        rule.check(CLASSES);
    }

    @Test
    void apiMustNotDependOnEntities() {
        ArchRule rule = noClasses().that().resideInAPackage("${PKG}.api..")
                .should().dependOnClassesThat().areAnnotatedWith(Entity.class);
        rule.check(CLASSES);
    }

    @Test
    void coreMustNotDependOnWebOrApi() {
        ArchRule rule = noClasses().that().resideInAPackage("${PKG}.core..")
                .should().dependOnClassesThat().resideInAnyPackage(
                        "${PKG}.api..",
                        "org.springframework.web..",
                        "org.springframework.http..",
                        "jakarta.servlet..");
        rule.check(CLASSES);
    }

    @Test
    void controllersLiveInApi() {
        ArchRule rule = classes().that().areAnnotatedWith(RestController.class)
                .should().resideInAPackage("${PKG}.api..");
        rule.check(CLASSES);
    }

    @Test
    void entitiesLiveInAdaptersPersistence() {
        ArchRule rule = classes().that().areAnnotatedWith(Entity.class)
                .should().resideInAPackage("${PKG}.adapters.persistence..")
                .allowEmptyShould(true);
        rule.check(CLASSES);
    }

    @Test
    void noFieldInjection() {
        GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION.check(CLASSES);
    }

    @Test
    void asyncMethodsArePublic() {
        ArchRule rule = methods().that().areAnnotatedWith(Async.class)
                .should().bePublic()
                .allowEmptyShould(true);
        rule.check(CLASSES);
    }

    @Test
    void configurationPropertiesAreValidated() {
        ArchRule rule = classes().that().areAnnotatedWith(ConfigurationProperties.class)
                .should().beAnnotatedWith(Validated.class)
                .allowEmptyShould(true);
        rule.check(CLASSES);
    }

    @Test
    void noLegacyDate() {
        ArchRule rule = noClasses().should().dependOnClassesThat()
                .haveFullyQualifiedName("java.util.Date");
        rule.check(CLASSES);
    }

    @Test
    void transactionalMethodsArePublic() {
        ArchRule rule = methods().that().areAnnotatedWith(Transactional.class)
                .should().bePublic()
                .allowEmptyShould(true);
        rule.check(CLASSES);
    }

    @Test
    void packagesAreFreeOfCycles() {
        ArchRule rule = slices().matching("${PKG}.(*)..").should().beFreeOfCycles();
        rule.check(CLASSES);
    }
}
EOF

cat > "${SVC_DIR}/src/itest/java/${JAVA_PKG_DIR}/${CLASS_BASE}EndpointIT.java" <<EOF
package ${PKG};

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration test for every endpoint (repo convention: every endpoint needs
 * one in src/itest/java). Runs against a real PostgreSQL via Testcontainers —
 * parity with AWS RDS — through the gradle 'integrationTest' task, wired into
 * 'check'.
 *
 * Uses the JDK HttpClient (not TestRestTemplate): Boot 4 moved/deprecated the
 * test HTTP clients, so the JDK client keeps this template stable across the
 * Boot 4.x line (see the spring-testing / spring-boot-4-migration skills).
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Testcontainers
class ${CLASS_BASE}EndpointIT {

    @Container
    @ServiceConnection   // auto-configures the datasource; no @DynamicPropertySource
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @LocalServerPort
    private int port;

    private final HttpClient http = HttpClient.newHttpClient();

    private HttpResponse<String> get(String path) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(
                URI.create("http://localhost:" + port + path)).GET().build();
        return http.send(request, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void healthIsUp() throws Exception {
        HttpResponse<String> res = get("/actuator/health");
        assertThat(res.statusCode()).isEqualTo(200);
        assertThat(res.body()).contains("UP");
    }

    @Test
    void helloEndpointResponds() throws Exception {
        HttpResponse<String> res = get("/api/${BASE}/hello?name=Alice");
        assertThat(res.statusCode()).isEqualTo(200);
        assertThat(res.body()).contains("Alice");
    }
}
EOF

# ---- Dockerfile + README ----------------------------------------------------

cat > "${SVC_DIR}/Dockerfile" <<EOF
FROM eclipse-temurin:21-jre
ARG SERVER_PORT=${PORT}
WORKDIR /app
COPY build/libs/${NAME}.jar app.jar
EXPOSE \${SERVER_PORT}
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF

cat > "${SVC_DIR}/README.md" <<EOF
# ${NAME}

Spring Cloud microservice scaffolded by \`scripts/new-service.sh\` (AI-Native
SDLC framework).

- Base package: \`${PKG}\`
- Port: ${PORT}
- Discovery: Kubernetes-native (spring-cloud-kubernetes)
- Config: Spring Cloud Config client (\`optional:configserver:\`)
- Database: AWS RDS PostgreSQL (prod) / H2 (local) / Testcontainers (itest)
- Endpoints:
  - \`GET /api/${BASE}/hello?name=<name>\` — sample endpoint
  - \`GET /actuator/health\` — health
- Gateway route (add in \`gateway/src/main/resources/application.yml\`):
  \`Path=/api/${BASE}/**\` -> \`lb://${NAME}\`

## Commands

\`\`\`bash
./gradlew :services:${NAME}:test             # unit tests (H2)
./gradlew :services:${NAME}:integrationTest  # integration tests (Testcontainers PostgreSQL)
./gradlew :services:${NAME}:check            # everything (unit + itest + checkstyle)
\`\`\`

## Before extending this service

Framework rule: nothing is implemented without an accepted plan.
Commit \`intent.md\`, \`spec.md\`, and \`plan.md\` for the next change first
(templates in \`intent/\` and \`docs/\`).
EOF

# ---- Next steps --------------------------------------------------------------

cat <<EOF

Done. The module is picked up automatically by settings.gradle.kts.
Next steps (AI-native SDLC):

  1. Write the intent:        intent/$(date +%F)-${NAME}/intent.md  (template: intent/TEMPLATE.md)
  2. Produce the spec:        intent/.../spec.md  (template: docs/spec-template.md)
  3. Accept a plan:           intent/.../plan.md  (template: docs/plan-template.md — gate to implementation)
  4. Build with plan mode:    start your agent in plan mode with spec.md + plan.md
  5. Verify:                  make build && make lint && make test && make itest
  6. Open a PR:               review runs per REVIEW.md; branch protection holds the gate
  7. Deploy:                  GitOps via Flux CD — see docs/repository-topology.md
EOF
