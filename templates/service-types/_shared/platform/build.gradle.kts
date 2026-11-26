// Platform module: the Gradle equivalent of a parent BOM. All services take
// their dependency versions from the constraints here, which import the
// Spring Boot and Spring Cloud BOMs from gradle/libs.versions.toml.
//
// Version policy: the platform team owns these versions. Feature changes
// never bump dependencies here (see AGENTS.md §7, CLAUDE.md "Things agents
// get wrong").

plugins {
    `java-platform`
}

javaPlatform {
    allowDependencies()
}

dependencies {
    // Import the upstream BOMs as direct platform dependencies — this is what
    // re-exports their managed versions to consumers. (Must be at top level of
    // `dependencies`, NOT inside `constraints`, for the versions to flow.)
    api(platform(libs.spring.boot.bom))
    api(platform(libs.spring.cloud.bom))
    api(platform(libs.testcontainers.bom))

    constraints {
        // Starters used across services — versions flow from the BOMs above.
        api(libs.spring.boot.starter.webmvc)
        api(libs.spring.boot.starter.webflux)
        api(libs.spring.boot.starter.validation)
        api(libs.spring.boot.starter.actuator)
        api(libs.spring.boot.starter.data.jpa)
        api(libs.spring.boot.starter.test)
        api(libs.spring.boot.testcontainers)

        // Spring Cloud: gateway, k8s-native discovery, config, resilience.
        api(libs.spring.cloud.starter.gateway.server.webflux)
        api(libs.spring.cloud.starter.loadbalancer)
        api(libs.spring.cloud.starter.kubernetes.client)
        api(libs.spring.cloud.starter.kubernetes.client.config)
        api(libs.spring.cloud.starter.config)
        api(libs.spring.cloud.config.server)
        api(libs.spring.cloud.starter.circuitbreaker.resilience4j)

        // Databases and test tooling.
        api(libs.postgresql)
        api(libs.h2)
        api(libs.testcontainers.postgresql)
        api(libs.testcontainers.junit.jupiter)

        // Architecture guardrails (ArchUnit) for every service's test suite.
        api(libs.archunit.junit5)
    }
}
