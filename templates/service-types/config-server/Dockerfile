FROM eclipse-temurin:21-jre
ARG SERVER_PORT=8888
WORKDIR /app
COPY build/libs/config-server.jar app.jar
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
