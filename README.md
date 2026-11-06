# CETIX

Sistema de gestao de documentos e processos para o setor de tecnologia da informacao.

## Stack Tecnologica

| Camada | Tecnologia | Versao |
| --- | --- | --- |
| Backend | PHP / Laravel | 8.5 / 13 |
| Frontend | Node.js / Next.js | 22 / 16 |
| Banco de Dados | PostgreSQL | 18 |
| Cache / Fila | Redis | 7 |
| Testes (Backend) | Pest | 5 |
| Testes (Frontend) | Vitest | 3 |
| Lint (Backend) | Laravel Pint | 1 |
| Lint (Frontend) | ESLint | 9 |
| Tipos (Frontend) | TypeScript | 5 |

## Pre-requisitos

- Docker
- Docker Compose (v2)

## Setup

```bash
# 1. Clonar o repositório
git clone <url-do-repositorio> && cd CETIx

# 2. Copiar os arquivos de ambiente
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# 3. Gerar a chave de criptografia do Laravel
make key

# 4. Subir o ambiente
make up
```

Após o `make up`, os servicos ficam disponiveis em:

| Servico | URL |
| --- | --- |
| Frontend (Next.js) | http://localhost:3000 |
| Backend API | http://localhost:8000 |
| Healthcheck | http://localhost:8000/api/healthz |
| PostgreSQL | localhost:5432 (user: `cetix`, pass: `secret`) |
| Redis | localhost:6379 |

## Variaveis de Ambiente

### Backend (`backend/.env`)

| Variavel | Padrao | Descricao |
| --- | --- | --- |
| `APP_NAME` | `CETIX` | Nome da aplicacao |
| `APP_ENV` | `local` | Ambiente (local, production, testing) |
| `APP_KEY` | _(vazio)_ | Chave de criptografia Laravel (gerada por `make key`) |
| `APP_DEBUG` | `true` | Modo debug |
| `APP_URL` | `http://localhost:8000` | URL base da API |
| `FRONTEND_URL` | `http://localhost:3000` | URL do frontend (CORS) |
| `DB_CONNECTION` | `pgsql` | Driver do banco |
| `DB_HOST` | `postgres` | Host do PostgreSQL |
| `DB_PORT` | `5432` | Porta do PostgreSQL |
| `DB_DATABASE` | `cetix` | Nome do banco |
| `DB_USERNAME` | `cetix` | Usuario do banco |
| `DB_PASSWORD` | `secret` | Senha do banco |
| `REDIS_CLIENT` | `phpredis` | Cliente Redis |
| `REDIS_HOST` | `redis` | Host do Redis |
| `REDIS_PORT` | `6379` | Porta do Redis |
| `CACHE_STORE` | `redis` | Driver de cache |
| `QUEUE_CONNECTION` | `redis` | Driver de fila |
| `SESSION_DRIVER` | `redis` | Driver de sessao |
| `SANCTUM_STATEFUL_DOMAINS` | `localhost:3000,127.0.0.1:3000` | Domios permitidos p/ Sanctum |
| `AUDIT_DB_HOST` | `postgres` | Host do banco de auditoria |
| `AUDIT_DB_DATABASE` | `cetix` | Banco de auditoria |
| `AUDIT_DB_USERNAME` | `cetix_maintenance` | Usuario de auditoria |

### Frontend (`frontend/.env`)

| Variavel | Padrao | Descricao |
| --- | --- | --- |
| `NEXT_PUBLIC_API_URL` | `http://localhost:8000` | URL da API (browser) |
| `NEXT_PUBLIC_APP_URL` | `http://localhost:3000` | URL do app (browser) |
| `API_INTERNAL_URL` | `http://backend:8000` | URL da API (server-side, Docker) |

## Comandos Makefile

| Comando | Descricao |
| --- | --- |
| `make up` | Sobe todos os servicos (build + start) |
| `make down` | Derruba todos os servicos |
| `make ps` | Lista os contenedores e status |
| `make logs` | Exibe os logs (follow, ultimo 100) |
| `make build` | Build das images + build de producao do frontend |
| `make test` | Executa testes Pest (backend) e Vitest (frontend) |
| `make lint` | Typecheck + Pint (backend) + ESLint (frontend) |
| `make typecheck` | Verificacao de tipos TypeScript (`tsc --noEmit`) |
| `make migrate` | Executa migrations do Laravel |
| `make key` | Gera a chave de criptografia (`APP_KEY`) |

## Fluxo de Desenvolvimento

```bash
# Subir o ambiente (primeira vez ou apos pull)
make up

# Gerar APP_KEY (apenas na primeira vez)
make key

# Rodar migrations
make migrate

# Verificar saude das dependencias
curl http://localhost:8000/api/healthz

# Rodar testes
make test

# Rodar lint + typecheck
make lint
```

## Estrutura do Repositorio

```
CETIx/
├── backend/              # API Laravel (PHP 8.5)
│   ├── app/
│   │   ├── Modules/      # Modulos de dominio
│   │   │   └── Shared/   # Compartilhado (Enums, Exceptions, Support, Traits)
│   │   └── Providers/    # Service providers
│   ├── config/
│   ├── routes/           # Rotas da API
│   ├── tests/
│   │   ├── Arch/         # Testes de arquitetura (Pest Arch)
│   │   ├── Feature/      # Testes de funcionalidade
│   │   └── Unit/         # Testes unitarios
│   ├── phpunit.xml
│   ├── pint.json
│   └── composer.json
├── frontend/             # SPA Next.js (Node 22, TypeScript)
│   ├── src/
│   │   ├── app/          # App Router
│   │   └── test/         # Setup e testes Vitest
│   ├── eslint.config.mjs
│   ├── postcss.config.mjs
│   ├── vitest.config.ts
│   └── package.json
├── docker/
│   ├── php/Dockerfile    # Image PHP 8.5 (Laravel)
│   └── node/Dockerfile   # Image Node 22 (Next.js)
├── docs/
│   └── agents/           # Documentacao de entregas
├── .github/
│   └── workflows/        # CI: backend.yml, frontend.yml, docker.yml
├── compose.yaml          # Docker Compose
└── Makefile              # Comandos de conveniencia
```

## CI/CD (GitHub Actions)

| Workflow | Disparo | Jobs |
| --- | --- | --- |
| `backend.yml` | PR/push em `backend/`, `docker/php/`, `compose.yaml` | `lint` (Pint), `test` (Pest + PostgreSQL + Redis) |
| `frontend.yml` | PR/push em `frontend/`, `docker/node/`, `compose.yaml` | `lint` (tsc + ESLint), `test` (Vitest), `build` (next build) |
| `docker.yml` | PR/push em `docker/`, `compose.yaml`, `backend/`, `frontend/` | `build` (docker compose build) |

## Notas

- O ambiente de desenvolvimento usa Docker Compose para isolar todas as dependencias.
- Nao ha credenciais hardcoded no repositório: `.env` e `.env.production` estao no `.gitignore`.
- O `phpunit.xml` define env vars para o ambiente Docker; no CI, os services expoe PostgreSQL e Redis em `127.0.0.1` e as env vars do job sobrescrevem os valores do XML.
- O build de producao do frontend usa `output: 'standalone'` (Next.js), gerando um artefato otimizado para deploy.
