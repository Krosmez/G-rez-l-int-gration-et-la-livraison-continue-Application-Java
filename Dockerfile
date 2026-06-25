# syntax=docker/dockerfile:1

###############################################################################
# Stage 1 — Build : compilation + packaging avec le wrapper Gradle (JDK 21)
###############################################################################
FROM eclipse-temurin:21-jdk-jammy AS build

WORKDIR /workspace

# Le wrapper Gradle (jar + scripts) et la configuration du projet d'abord :
# cela permet de mettre en cache la couche de dépendances tant que la config
# ne change pas.
COPY gradlew settings.gradle build.gradle ./
COPY gradle ./gradle

# Les scripts peuvent avoir été commités avec des fins de ligne CRLF (Windows).
# On les normalise et on rend le wrapper exécutable avant de l'invoquer.
RUN sed -i 's/\r$//' gradlew && chmod +x gradlew

# Sources de l'application
COPY src ./src

# Compilation + packaging du WAR exécutable (commandes du README).
# Les tests sont exécutés en CI : @SpringBootTest exige une base PostgreSQL
# qui n'est pas disponible pendant le build de l'image, on les saute donc ici.
RUN ./gradlew clean bootWar -x test --no-daemon

###############################################################################
# Stage 2 — Runtime : exécution sur Eclipse Temurin JRE 21
###############################################################################
FROM eclipse-temurin:21-jre-jammy AS runtime

WORKDIR /app

# Exécution avec un utilisateur non-root
RUN groupadd --system spring && useradd --system --gid spring spring

# Récupération du WAR exécutable produit à l'étape précédente
COPY --from=build /workspace/build/libs/*.war app.war

USER spring

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.war"]
