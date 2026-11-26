package com.example.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

/**
 * Spring Cloud Config Server.
 *
 * Externalised configuration is the single source of truth for every service's
 * runtime properties. Local development runs the {@code native} profile
 * (filesystem backend over {@code ./config}); production reads the same files
 * from the GitOps-managed infra repository via the {@code git} backend
 * (see README.md and docs/repository-topology.md).
 */
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
