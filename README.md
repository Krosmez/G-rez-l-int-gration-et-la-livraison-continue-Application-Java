# Workshop Organizer Web API

Welcome to the Workshop Organizer Web API! This application is designed to facilitate workshops open to the public. Whether you’re organizing coding bootcamps, art classes, or any other type of workshop, this API will help manage registrations, schedules, and resources.

## Table of Contents

1. Context
2. Technical Overview
3. Building and Running
4. Testing
5. Packaging
6. Continuous Integration & Delivery
7. Publishing to GitHub Registry

## Context

Workshops play a crucial role in fostering learning and collaboration. Our application aims to streamline the workshop organization process, making it easier for organizers to manage participants, sessions, and materials. Whether you're a seasoned workshop host or just starting out, this API has got you covered!

## Technical Overview

- **Java Development Kit (JDK):** We use **JDK 21**, tested with **Adoptium**, to power our application.
- **Database:** Our backend relies on a **PostgreSQL 13** database for data storage.
- **Build Tool:** We leverage **Gradle 8.7** for managing dependencies and building the project.
- **Spring Boot:** Our application is based on **Spring Boot 3.2.4**, which provides a robust framework for creating RESTful APIs.
- **Application Server:** Our application can run on Tomcat server that require version 10.1.24.

## Building and Running

To compile and run the application locally, follow these steps:

1. Ensure you have JDK 21 installed.
2. Clone this repository.
3. Navigate to the project root directory.
4. Execute the following command to compile the Java code :
   ```bash
   ./gradlew clean compileJava
   ```
5. To run the application locally, either:
   Execute the main method in the Application class from your IDE.
   Use the Spring Boot Gradle Plugin :
   ```bash
   ./gradlew bootRun
   ```
   For production, package the application as WAR and use a tomcat server

To run correctly the application with docker after you building it with tag workshop-organizer, run the following

```bash
docker compose up -d
```

## Configuration

You can configure the application with these environment variables

- SPRING_DATASOURCE_URL: JDBC URI for DB access (ex. jdbc:postgresql://db:5432/workshopsdb)
- SPRING_DATASOURCE_USERNAME: Database user name used by the application
- SPRING_DATASOURCE_PASSWORD: Database user password used by the application

The provided `docker-compose.yml` wires these values automatically (database `workshopsdb`, user `workshops_user`), so no manual configuration is required when running with Docker Compose.

## Testing

We take testing seriously! To verify the correctness of our application, run the following command:

```bash
./gradlew clean test
```

During execution junit reports are generated in the `build/test-results/test` folder.

## Packaging

When you’re ready to package the application for deployment, create a deployable WAR file:

```bash
./gradlew bootWar
```

The generated war file can be used with many application servers such as Tomcat, Wildfly...

## Continuous Integration & Delivery

The project ships with a GitHub Actions pipeline defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml). It runs on every push (any branch), on pull requests targeting `main`, and can be triggered manually. The pipeline is generic: it auto-detects the project type (Java/Gradle or Node/Angular) and adapts its steps accordingly. It is organized in three jobs:

1. **Tests** — Sets up the JDK, runs the unit tests through the unified `run-tests.sh` script, and publishes a JUnit report as a GitHub check.
2. **Build & push image** — Builds the Docker image, validates it with a smoke test (starts an ephemeral PostgreSQL 13 database and waits for the API to answer on port 8080), then pushes it to the GitHub Container Registry tagged `<branch>-<short-sha>`. Publishing is skipped on pull requests.
3. **Release** — On pushes to `main` only, [semantic-release](https://semantic-release.gitbook.io/) analyzes Conventional Commits, computes the next version, creates a GitHub release and `CHANGELOG.md`, bumps the `version` in `build.gradle`, and re-tags the already-built Docker image with the semantic version and `latest`.

### Conventional Commits

Versioning is fully automated with [semantic-release](https://semantic-release.gitbook.io/), configured in [`.releaserc.json`](./.releaserc.json). All commits **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) specification, as they drive the next version number:

| Commit type                   | Example                          | Version bump              |
| ----------------------------- | -------------------------------- | ------------------------- |
| `fix:`                        | `fix: correct medal count`       | patch (`1.2.3` → `1.2.4`) |
| `feat:`                       | `feat: add country details page` | minor (`1.2.3` → `1.3.0`) |
| `feat!:` / `BREAKING CHANGE:` | `feat!: drop legacy API`         | major (`1.2.3` → `2.0.0`) |

Other types (`chore:`, `docs:`, `test:`, `ci:`, `refactor:`, …) do not trigger a release.

## Publishing to GitHub Registry

Docker images are published automatically by the CI pipeline to the **GitHub Container Registry (GHCR)** at `ghcr.io/<owner>/<repository>`. There is nothing to run manually — pushing your commits triggers the workflow.

Image tagging convention:

- `ghcr.io/<owner>/<repository>:<branch>-<short-sha>` — built and pushed for every branch (except pull requests).
- `ghcr.io/<owner>/<repository>:<x.y.z>` and `:latest` — added on `main` when semantic-release publishes a new version.

Authentication is handled by the built-in `GITHUB_TOKEN` (the workflow requests `packages: write` permission), so no personal access token needs to be configured. To pull a published image:

```bash
docker pull ghcr.io/<owner>/<repository>:latest
```

Feel free to enhance this README with additional details, such as API endpoints, security considerations, and deployment instructions. Happy organizing! 🚀
