#!/usr/bin/env bash
set -euo pipefail

# Host-side helper for docker-compose projects.
# Usage: bash ./scripts/post-compose-setup.sh
# Optional env overrides:
#  COMPOSE_CMD default: docker-compose
#  BACKEND_SERVICE default: backend
#  FRONTEND_SERVICE default: frontend
#  DB_SERVICE default: db
#  BACKEND_WORKDIR path inside backend container for project; default /workspace/backend
#  FRONTEND_WORKDIR path inside frontend container for project; default /workspace/frontend

COMPOSE_CMD="${COMPOSE_CMD:-docker-compose}"
BACKEND_SERVICE="${BACKEND_SERVICE:-backend}"
FRONTEND_SERVICE="${FRONTEND_SERVICE:-frontend}"
DB_SERVICE="${DB_SERVICE:-db}"
BACKEND_WORKDIR="${BACKEND_WORKDIR:-/workspace/backend}"
FRONTEND_WORKDIR="${FRONTEND_WORKDIR:-/workspace/frontend}"
RETRIES="${RETRIES:-12}"
SLEEP="${SLEEP:-2}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

# 1. Start compose services (detached)
log "Starting docker-compose services (detached)..."
$COMPOSE_CMD up -d --build

# 2. Create .env for backend if absent by copying template inside project (host-side)
if [ -f "./backend/.env.example" ] && [ ! -f "./backend/.env" ]; then
  log "Copying backend/.env.example to backend/.env"
  cp ./backend/.env.example ./backend/.env
elif [ ! -f "./backend/.env" ]; then
  log "Generating basic backend/.env (development values)"
  cat > ./backend/.env <<EOF
DATABASE_URL=postgresql+asyncpg://postgres:password@${DB_SERVICE}:5432/postgres
SECRET_KEY=dev-secret
DEBUG=true
EOF
fi

# 3. Wait for Postgres to accept TCP connections from host via container network
log "Waiting for Postgres service '${DB_SERVICE}' to accept connections..."
for i in $(seq 1 $RETRIES); do
  # Try to exec a short python TCP connect from a temporary container attached to the compose network.
  # Use busybox/nc as fallback if python not available.
  if $COMPOSE_CMD exec -T $DB_SERVICE pg_isready -U postgres >/dev/null 2>&1; then
    log "Postgres reported ready by pg_isready"
    break
  else
    log "Postgres not ready yet (attempt $i/$RETRIES). Sleeping $SLEEP s"
    sleep $SLEEP
  fi

  if [ "$i" -eq "$RETRIES" ]; then
    log "Timed out waiting for Postgres. Continuing; some steps may fail."
  fi
done

# 4. Install backend Python deps inside backend container
if $COMPOSE_CMD exec -T $BACKEND_SERVICE test -f "${BACKEND_WORKDIR}/requirements.txt" >/dev/null 2>&1; then
  log "Installing backend Python dependencies inside '${BACKEND_SERVICE}'"
  $COMPOSE_CMD exec -T $BACKEND_SERVICE sh -lc "python -m pip install --upgrade pip && pip install -r ${BACKEND_WORKDIR}/requirements.txt"
else
  log "No requirements.txt detected at ${BACKEND_WORKDIR}; skipping backend pip install"
fi

# 5. Run Alembic migrations if available inside backend container
log "Checking for alembic configuration inside backend container"
if $COMPOSE_CMD exec -T $BACKEND_SERVICE sh -lc "test -d ${BACKEND_WORKDIR}/alembic || grep -q alembic ${BACKEND_WORKDIR}/requirements.txt 2>/dev/null || command -v alembic >/dev/null 2>&1" >/dev/null 2>&1; then
  log "Attempting to run alembic upgrade head inside '${BACKEND_SERVICE}'"
  $COMPOSE_CMD exec -T $BACKEND_SERVICE sh -lc "cd ${BACKEND_WORKDIR} && alembic upgrade head || echo 'alembic upgrade head failed'"
else
  log "No alembic setup detected; skipping migrations"
fi

# 6. Install frontend Node deps inside frontend container
if $COMPOSE_CMD exec -T $FRONTEND_SERVICE test -f "${FRONTEND_WORKDIR}/package.json" >/dev/null 2>&1; then
  log "Installing frontend Node dependencies inside '${FRONTEND_SERVICE}'"
  $COMPOSE_CMD exec -T $FRONTEND_SERVICE sh -lc "cd ${FRONTEND_WORKDIR} && if [ -f package-lock.json ]; then npm ci; else npm install; fi"
else
  log "No package.json detected at ${FRONTEND_WORKDIR}; skipping frontend install"
fi

# 7. Run seed script if present inside backend container
if $COMPOSE_CMD exec -T $BACKEND_SERVICE test -f "${BACKEND_WORKDIR}/scripts/seed.py" >/dev/null 2>&1; then
  log "Running database seed script inside '${BACKEND_SERVICE}'"
  $COMPOSE_CMD exec -T $BACKEND_SERVICE sh -lc "cd ${BACKEND_WORKDIR} && python scripts/seed.py || echo 'seed script failed'"
else
  log "No seed script found at ${BACKEND_WORKDIR}/scripts/seed.py; skipping seed"
fi

# 8. Adjust ownership of mounted workspace directories to match container user if desired
# This step attempts to chown from inside backend container to avoid host permission issues.
# It is safe to skip if your images already set appropriate permissions.
log "Attempting to adjust ownership of workspace files from within '${BACKEND_SERVICE}' (best-effort)"
$COMPOSE_CMD exec -T $BACKEND_SERVICE sh -lc "if id -u vscode >/dev/null 2>&1; then chown -R vscode:vscode /workspace || true; fi" || true

log "Post-compose setup finished. Helpful next steps:"
log "  - Tail logs: ${COMPOSE_CMD} logs -f"
log "  - Run backend dev server: ${COMPOSE_CMD} exec ${BACKEND_SERVICE} sh -lc \"cd ${BACKEND_WORKDIR} && uvicorn main:app --reload --host 0.0.0.0 --port 8000\""
log "  - Run frontend dev server: ${COMPOSE_CMD} exec ${FRONTEND_SERVICE} sh -lc \"cd ${FRONTEND_WORKDIR} && npm run dev -- --host\""
