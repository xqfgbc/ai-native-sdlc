package com.example.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Spring Cloud Gateway (WebFlux). Kubernetes-native discovery: {@code lb://}
 * routes resolve against the Kubernetes Service catalog through the
 * spring-cloud-kubernetes DiscoveryClient. In a cluster you can also enable the
 * discovery route locator to route {@code /api/<service>/**} automatically; the
 * explicit routes below keep the surface reviewable (see AGENTS.md).
 */
@SpringBootApplication
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
