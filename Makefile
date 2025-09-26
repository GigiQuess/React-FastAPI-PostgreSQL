# Makefile - docker-compose driven development helper
# 想定: docker-compose.yml がプロジェクトルートにあること

.PHONY: up build up-detached down restart rebuild logs ps exec install-backend install-frontend migrate seed test fmt shell

COMPOSE := docker-compose
PROJECT_DIR := .

# Start (foreground)
up:
    $(COMPOSE) up --build

# Start detached (background)
up-detached:
    $(COMPOSE) up -d --build

# Stop and remove containers, networks (keep volumes)
down:
    $(COMPOSE) down

# Recreate containers (stop, remove, build, start detached)
rebuild: down
    $(COMPOSE) up -d --build --force-recreate

# Show logs for all services (follow)
logs:
    $(COMPOSE) logs -f

# Show docker-compose ps
ps:
    $(COMPOSE) ps

# Execute a command in a service container
# Usage: make exec SERVICE=backend CMD="bash -lc 'alembic upgrade head'"
exec:
    @test -n "$(SERVICE)" || (echo "Specify SERVICE target e.g. SERVICE=backend" && exit 1)
    @test -n "$(CMD)" || (echo "Specify CMD e.g. CMD=\"bash -lc 'ls -la'\"" && exit 1)
    $(COMPOSE) exec $(SERVICE) sh -lc "$(CMD)"

# Open an interactive shell in a service container (default backend)
# Usage: make shell SERVICE=backend
shell:
    $(COMPOSE) exec $(SERVICE) sh
    # For bash-enabled images: docker-compose exec $(SERVICE) bash

# Install backend Python deps inside backend container
install-backend:
    $(COMPOSE) exec backend sh -lc "python -m pip install --upgrade pip && pip install -r /workspace/backend/requirements.txt"

# Install frontend Node deps inside frontend container
install-frontend:
    $(COMPOSE) exec frontend sh -lc "cd /workspace/frontend && if [ -f package-lock.json ]; then npm ci; else npm install; fi"

# Run Alembic migrations (assumes alembic is available in backend image)
migrate:
    $(COMPOSE) exec backend sh -lc "cd /workspace/backend && alembic upgrade head"

# Run seed script (if exists)
seed:
    $(COMPOSE) exec backend sh -lc "cd /workspace/backend && python scripts/seed.py"

# Run backend tests
test:
    $(COMPOSE) exec backend sh -lc "cd /workspace/backend && pytest -q"

# Format code (backend: black / frontend: prettier)
fmt:
    $(COMPOSE) exec backend sh -lc "cd /workspace/backend && black ."
    $(COMPOSE) exec frontend sh -lc "cd /workspace/frontend && npx prettier --write \"src/**/*.{js,jsx,ts,tsx,json,css,md}\""

# Tailored convenience targets
# Start only backend (useful during backend-focused dev)
backend-up:
    $(COMPOSE) up -d --build backend

# Start only frontend
frontend-up:
    $(COMPOSE) up -d --build frontend

# Start only db
db-up:
    $(COMPOSE) up -d db

# Remove volumes and data (use with caution)
prune-volumes:
    $(COMPOSE) down -v

# Clean all images created by docker-compose for this project
clean-images:
    # careful: this removes images referenced by the compose project
    -@docker images --filter=reference="$(shell basename `pwd`)*" -q | xargs -r docker rmi -f
