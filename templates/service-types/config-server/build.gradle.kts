import org.gradle.api.plugins.JavaPluginExtension
import org.gradle.api.plugins.quality.CheckstyleExtension
import org.gradle.api.tasks.SourceSetContainer
import org.gradle.api.tasks.testing.Test
import org.gradle.jvm.toolchain.JavaLanguageVersion

// Config-server service repo (standalone).
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

    implementation(libs.spring.cloud.config.server)
    implementation(libs.spring.boot.starter.actuator)

    testImplementation(libs.spring.boot.starter.test)
}

tasks.named<org.springframework.boot.gradle.tasks.bundling.BootJar>("bootJar") {
    archiveFileName.set("config-server.jar")
}
