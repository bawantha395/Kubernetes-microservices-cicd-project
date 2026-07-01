FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /app

# Copy pom.xml first for better caching
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# ---- Runtime stage ----
FROM eclipse-temurin:17-jdk-jammy

WORKDIR /app




# Install netcat for wait-for-it script
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Copy built jar from build stage
COPY --from=build /app/target/api.jar target/api.jar

# Copy wait scripts
COPY wait-for-it.sh .
COPY wait-for-mysql.sh .
RUN chmod +x wait-for-it.sh wait-for-mysql.sh

ENTRYPOINT ["./wait-for-mysql.sh", "java", "-jar", "target/api.jar"]# Manual Trigger Force
