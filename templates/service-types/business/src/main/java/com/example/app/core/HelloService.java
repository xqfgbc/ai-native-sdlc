package com.example.app.core;

import org.springframework.stereotype.Service;

/** Domain logic (must not import web/http classes). */
@Service
public class HelloService {

    public String greet(String name) {
        return "Hello, " + name;
    }
}
