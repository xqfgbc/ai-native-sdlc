package com.example.app.api;

import com.example.app.api.dto.HelloResponse;
import com.example.app.core.HelloService;
import jakarta.validation.constraints.Pattern;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** REST controller. Every endpoint: validated input + typed DTO + itest in src/itest/java. */
@RestController
@Validated
@RequestMapping("/api")
public class HelloController {

    private final HelloService helloService;

    public HelloController(HelloService helloService) {
        this.helloService = helloService;
    }

    @GetMapping("/hello")
    public HelloResponse hello(@RequestParam @Pattern(regexp = "[A-Za-z0-9 _-]{1,40}") String name) {
        return new HelloResponse(name, helloService.greet(name));
    }
}
