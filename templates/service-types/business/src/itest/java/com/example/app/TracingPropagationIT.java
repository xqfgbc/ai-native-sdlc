package com.example.app;

import com.sun.net.httpserver.HttpServer;
import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Proves W3C trace propagation without Docker: the inbound traceparent must be honoured and
 * re-injected by the auto-configured RestClient.Builder on the outbound call.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import({TracingPropagationIT.ProbeClientConfig.class, TracingPropagationIT.TraceProbeController.class})
class TracingPropagationIT {

    private static final BlockingQueue<String> TRACEPARENTS = new LinkedBlockingQueue<>();
    private static final HttpServer STUB = startStub();

    @LocalServerPort
    private int port;

    private final HttpClient http = HttpClient.newHttpClient();

    private static HttpServer startStub() {
        try {
            HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
            server.createContext("/probe", exchange -> {
                String traceparent = exchange.getRequestHeaders().getFirst("traceparent");
                if (traceparent != null) {
                    TRACEPARENTS.offer(traceparent);
                }
                exchange.sendResponseHeaders(204, -1);
                exchange.close();
            });
            server.start();
            return server;
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    @DynamicPropertySource
    static void stubUrl(DynamicPropertyRegistry registry) {
        registry.add("itest.stub.url", () -> "http://127.0.0.1:" + STUB.getAddress().getPort());
    }

    @AfterAll
    static void stopStub() {
        STUB.stop(0);
    }

    @BeforeEach
    void clearProbe() {
        TRACEPARENTS.clear();
    }

    @Test
    void inboundTraceparentIsHonouredAndPropagated() throws Exception {
        String inbound = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

        HttpResponse<String> res = get("/itest/trace", Map.of("traceparent", inbound));

        assertThat(res.statusCode()).isEqualTo(200);
        String outbound = TRACEPARENTS.poll(5, TimeUnit.SECONDS);
        assertThat(outbound).matches("00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}");
        String[] parts = outbound.split("-");
        assertThat(parts[1]).isEqualTo("4bf92f3577b34da6a3ce929d0e0e4736");
        assertThat(parts[2]).isNotEqualTo("00f067aa0ba902b7");
        assertThat(res.body()).contains("4bf92f3577b34da6a3ce929d0e0e4736");
    }

    @Test
    void withoutInboundTraceparentCreatesAndPropagatesNewTrace() throws Exception {
        HttpResponse<String> res = get("/itest/trace", Map.of());

        assertThat(res.statusCode()).isEqualTo(200);
        String outbound = TRACEPARENTS.poll(5, TimeUnit.SECONDS);
        assertThat(outbound).matches("00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}");
        String traceId = outbound.split("-")[1];
        assertThat(traceId).isNotEqualTo("0".repeat(32));
        assertThat(res.body()).contains(traceId);
    }

    private HttpResponse<String> get(String path, Map<String, String> headers) throws Exception {
        HttpRequest.Builder builder = HttpRequest.newBuilder(
                URI.create("http://localhost:" + port + path)).GET();
        headers.forEach(builder::header);
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    @TestConfiguration
    static class ProbeClientConfig {

        @Bean
        RestClient itestProbeClient(RestClient.Builder builder, @Value("${itest.stub.url}") String url) {
            return builder.baseUrl(url).build();
        }
    }

    @RestController
    static class TraceProbeController {

        private final RestClient probeClient;
        private final Tracer tracer;

        TraceProbeController(RestClient probeClient, Tracer tracer) {
            this.probeClient = probeClient;
            this.tracer = tracer;
        }

        @GetMapping("/itest/trace")
        Map<String, String> trace() {
            probeClient.get().uri("/probe").retrieve().toBodilessEntity();
            Span span = tracer.currentSpan();
            return Map.of("traceId", span == null ? "none" : span.context().traceId());
        }
    }
}
