package com.example.app;

import com.example.app.support.AbstractPostgresIT;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.assertj.core.api.Assertions.assertThat;

/** Smoke tests: the app starts against PostgreSQL and the scaffold endpoint still works. */
class AppEndpointIT extends AbstractPostgresIT {

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
        HttpResponse<String> res = get("/api/hello?name=Alice");
        assertThat(res.statusCode()).isEqualTo(200);
        assertThat(res.body()).contains("Alice");
    }
}
