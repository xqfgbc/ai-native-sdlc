FROM eclipse-temurin:21-jre
ARG SERVER_PORT=8080
WORKDIR /app
COPY build/libs/gateway.jar app.jar
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
