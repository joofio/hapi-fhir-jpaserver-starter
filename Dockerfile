FROM docker.io/library/maven:3.9.12-eclipse-temurin-17 AS build-hapi
WORKDIR /tmp/hapi-fhir-jpaserver-starter

# Fix SSL/TLS certificate issues by importing system CA certificates into Java's truststore
# This ensures Maven can connect to repositories over HTTPS
# Note: The 'changeit' password is Java's default cacerts password and cannot be changed
#       for the system truststore without breaking compatibility
ENV JAVA_HOME=/opt/java/openjdk
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    update-ca-certificates && \
    # Split the CA bundle and import each certificate into Java's cacerts
    mkdir -p /tmp/certs && cd /tmp/certs && \
    awk 'BEGIN {c=0} /-----BEGIN CERTIFICATE-----/{c++} {print > "cert" c ".pem"}' /etc/ssl/certs/ca-certificates.crt && \
    for cert in /tmp/certs/*.pem; do \
        if [ -f "$cert" ] && grep -q "BEGIN CERTIFICATE" "$cert" 2>/dev/null; then \
            alias="cert-$(basename "$cert" .pem)"; \
            ${JAVA_HOME}/bin/keytool -importcert -trustcacerts -cacerts \
                -storepass changeit -noprompt -alias "$alias" -file "$cert" 2>&1 | grep -v "already exists" || true; \
        fi; \
    done && \
    rm -rf /tmp/certs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ARG OPENTELEMETRY_JAVA_AGENT_VERSION=2.24.0
RUN curl -LSsO https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OPENTELEMETRY_JAVA_AGENT_VERSION}/opentelemetry-javaagent.jar

COPY pom.xml .
COPY server.xml .
RUN mvn -ntp dependency:go-offline

COPY src/ /tmp/hapi-fhir-jpaserver-starter/src/
RUN mvn clean install -DskipTests -Djdk.lang.Process.launchMechanism=vfork

FROM build-hapi AS build-distroless
RUN mvn package -DskipTests spring-boot:repackage -Pboot
RUN mkdir /app && cp /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /app/main.war

COPY src/main/java/HealthCheck.java /app/HealthCheck.java
RUN javac /app/HealthCheck.java


########### Use the official Tomcat image as base image for the Tomcat variant
########### it can be built using eg. `docker build --target tomcat .`
FROM docker.io/library/tomcat:10-jre21-temurin-noble AS tomcat

USER root
RUN rm -rf /usr/local/tomcat/webapps/ROOT && \
    mkdir -p /usr/local/tomcat/data/hapi/lucenefiles && \
    chown -R 65532:65532 /usr/local/tomcat/data/hapi/lucenefiles && \
    chmod 775 /usr/local/tomcat/data/hapi/lucenefiles

RUN mkdir -p /target && chown -R 65532:65532 /target
USER 65532

COPY --chown=65532:65532 catalina.properties /usr/local/tomcat/conf/catalina.properties
COPY --chown=65532:65532 server.xml /usr/local/tomcat/conf/server.xml
COPY --from=build-hapi --chown=65532:65532 /tmp/hapi-fhir-jpaserver-starter/target/ROOT.war /usr/local/tomcat/webapps/ROOT.war
COPY --from=build-hapi --chown=65532:65532 /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app

########### distroless brings focus on security and runs on plain spring boot - this is the default image
FROM gcr.io/distroless/java21-debian13:nonroot AS default
# 65532 is the nonroot user's uid
# used here instead of the name to allow Kubernetes to easily detect that the container
# is running as a non-root (uid != 0) user.
USER 65532:65532
WORKDIR /app

COPY --chown=nonroot:nonroot --from=build-distroless /app /app
COPY --chown=nonroot:nonroot --from=build-hapi /tmp/hapi-fhir-jpaserver-starter/opentelemetry-javaagent.jar /app

ENTRYPOINT ["java", "--class-path", "/app/main.war", "-Dloader.path=main.war!/WEB-INF/classes/,main.war!/WEB-INF/,/app/extra-classes", "org.springframework.boot.loader.PropertiesLauncher"]
