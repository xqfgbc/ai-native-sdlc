package com.example.app.api.dto;

/** Response DTO (records only; entities never leave the persistence layer). */
public record HelloResponse(String name, String message) {
}
