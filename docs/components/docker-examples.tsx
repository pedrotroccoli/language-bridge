import { DynamicCodeBlock } from 'fumadocs-ui/components/dynamic-codeblock';
import { latestVersion } from '@/lib/generated/cli-snippets';

// Docker snippets for the Architecture page. The image tag is interpolated from
// the release manifest so the docs never advertise a stale version.
export const image = `ghcr.io/pedrotroccoli/language-bridge:${latestVersion}`;

const compose = `x-app: &app
  image: ${image}
  env_file: .env
  environment:
    RAILS_ENV: production
    DB_HOST: db
    DB_PORT: "5432"
  depends_on:
    db:
      condition: service_healthy

services:
  db:
    image: postgres:18
    restart: unless-stopped
    environment:
      POSTGRES_USER: back
      POSTGRES_PASSWORD: \${BACK_DATABASE_PASSWORD:?set BACK_DATABASE_PASSWORD in .env}
      POSTGRES_DB: back_production
    volumes:
      - pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U back -d back_production"]
      interval: 5s
      timeout: 5s
      retries: 10

  # One-shot: creates the 4 Solid databases (primary/cache/queue/cable) and migrates.
  migrate:
    <<: *app
    command: ["./bin/rails", "db:prepare"]
    environment:
      RAILS_ENV: production
      DB_HOST: db
      DB_PORT: "5432"
      RUN_DB_PREPARE: "false"
    restart: "no"

  web:
    <<: *app
    command: ["./bin/thrust", "./bin/rails", "server"]
    environment:
      RAILS_ENV: production
      DB_HOST: db
      DB_PORT: "5432"
      RUN_DB_PREPARE: "false"
      SOLID_QUEUE_IN_PUMA: "true"
    depends_on:
      db:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
    ports:
      - "8080:80"
    restart: unless-stopped
    volumes:
      - app-storage:/rails/storage

volumes:
  pg-data:
  app-storage:
`;

const run = `docker run -d --name language-bridge \\
  -p 8080:80 \\
  --env-file .env \\
  -e RAILS_ENV=production \\
  -e DB_HOST=your-postgres-host \\
  -e DB_PORT=5432 \\
  -e SOLID_QUEUE_IN_PUMA=true \\
  ${image} \\
  ./bin/thrust ./bin/rails server
`;

const dbPrepare = `docker run --rm \\
  --env-file .env \\
  -e RAILS_ENV=production \\
  -e DB_HOST=your-postgres-host -e DB_PORT=5432 \\
  -e RUN_DB_PREPARE=false \\
  ${image} \\
  ./bin/rails db:prepare
`;

export function DockerComposeExample() {
  return <DynamicCodeBlock lang="yaml" code={compose} codeblock={{ title: 'docker-compose.yml' }} />;
}

export function DockerRunExample() {
  return <DynamicCodeBlock lang="bash" code={run} />;
}

export function DockerDbPrepareExample() {
  return <DynamicCodeBlock lang="bash" code={dbPrepare} />;
}
