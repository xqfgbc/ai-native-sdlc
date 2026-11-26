import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.api.plugins.quality.CheckstyleExtension
import org.gradle.api.tasks.SourceSetContainer
import org.gradle.api.tasks.testing.Test
import org.gradle.jvm.toolchain.JavaLanguageVersion

// Business service repo (standalone). Fixed base package com.example.app; the service name
// is rendered into {{SERVICE}} (application name, bootJar name, Dockerfile).
plugins {
    java
    checkstyle
    alias(libs.plugins.spring.boot)
}

group = "com.example"
version = "0.1.0-SNAPSHOT"

extensions.configure<JavaPluginExtension> {
    toolchain { languageVersion.set(JavaLanguageVersion.of(21)) }
}

tasks.withType<Test>().configureEach { useJUnitPlatform() }

val itestDir = file("src/itest/java")
if (itestDir.exists()) {
    val itest = the<SourceSetContainer>().create("itest")
    itest.java.srcDir(itestDir)
    // A custom source set does not inherit the main output; without this Spring Boot
    // cannot find @SpringBootConfiguration at runtime.
    itest.compileClasspath += sourceSets.main.get().output
    itest.runtimeClasspath += sourceSets.main.get().output
    configurations.named(itest.implementationConfigurationName) {
        extendsFrom(configurations.getByName("testImplementation"))
    }
    configurations.named(itest.runtimeOnlyConfigurationName) {
        extendsFrom(configurations.getByName("testRuntimeOnly"))
    }
    dependencies { add("itestImplementation", "org.springframework.boot:spring-boot-starter-test") }
    tasks.register<Test>("integrationTest") {
        group = "verification"
        testClassesDirs = itest.output.classesDirs
        classpath = itest.runtimeClasspath
    }
    tasks.named("check") { dependsOn("integrationTest") }
}

extensions.configure<CheckstyleExtension> {
    toolVersion = "10.12.5"
    configDirectory.set(file("config/checkstyle"))
}

dependencies {
    implementation(platform(project(":platform")))

    implementation(libs.spring.boot.starter.webmvc)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.spring.boot.starter.actuator)
    implementation(libs.spring.boot.starter.data.jpa)
    implementation(libs.spring.boot.starter.restclient)
    implementation(libs.spring.boot.starter.opentelemetry)
    implementation(libs.spring.cloud.starter.kubernetes.client)
    implementation(libs.spring.cloud.starter.config)
    implementation(libs.spring.cloud.starter.circuitbreaker.resilience4j)

    implementation(libs.spring.boot.starter.flyway)
    runtimeOnly(libs.flyway.database.postgresql)
    runtimeOnly(libs.postgresql)
    runtimeOnly(libs.h2)

    testImplementation(libs.spring.boot.starter.test)
    testImplementation(libs.spring.boot.webmvc.test)
    testImplementation(libs.spring.boot.data.jpa.test)
    testImplementation(libs.spring.boot.testcontainers)
    testImplementation(libs.testcontainers.postgresql)
    testImplementation(libs.testcontainers.junit.jupiter)
    testImplementation(libs.archunit.junit5)
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("{{SERVICE}}.jar")
}
