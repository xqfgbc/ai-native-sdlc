FROM eclipse-temurin:21-jre
ARG SERVER_PORT=8081
WORKDIR /app
COPY build/libs/{{SERVICE}}.jar app.jar
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
