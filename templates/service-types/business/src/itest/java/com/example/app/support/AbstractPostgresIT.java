package com.example.app.support;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.net.http.HttpClient;

/**
 * Base for integration tests: real PostgreSQL via Testcontainers, Flyway owns the schema,
 * Hibernate validates it (application-itest.yml). @ServiceConnection wires the datasource.
 */
@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"spring.flyway.enabled=true", "spring.jpa.hibernate.ddl-auto=validate"})
@ActiveProfiles({"test", "itest"})
public abstract class AbstractPostgresIT {

    // Singleton container: started once for the whole test task so Spring's cached context
    // never points at a stopped database (per-class @Container + context cache breaks).
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    static {
        POSTGRES.start();
    }

    @LocalServerPort
    protected int port;

    protected final HttpClient http = HttpClient.newHttpClient();
}
