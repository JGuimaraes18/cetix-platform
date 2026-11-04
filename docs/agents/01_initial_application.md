# Entrega 0.1 - Esqueleto do Monorepo e Ambiente Docker

## Status: COMPLETO

## O que foi entregue

### Estrutura do Monorepo
```
CETIx/
├── backend/          # Laravel 13 / PHP 8.5
├── frontend/         # Next.js 16 / Node 22
├── docker/           # Dockerfiles
│   ├── php/Dockerfile
│   └── node/Dockerfile
├── compose.yaml      # Docker Compose
├── Makefile          # Comandos de conveniência
├── .env              # Variáveis de ambiente (raiz)
├── .env.example      # Template
├── .gitignore
├── .editorconfig
└── docs/
```

### Serviços Docker

| Serviço | Imagem | Porta Host | Healthcheck |
|---------|--------|------------|-------------|
| frontend | cetix-frontend | 3000 | `GET /api/healthz` |
| backend | cetix-backend | 8000 | `GET /api/v1/health` |
| postgres | postgres:18-alpine | interna | `pg_isready` |
| redis | redis:7-alpine | interna | `redis-cli ping` |

### Arquitetura de Dependências
- **Frontend** NÃO depende de backend, postgres ou redis (liveness apenas)
- **Backend** depende de postgres e redis com estado `healthy` (readiness)
- PostgreSQL e Redis NÃO expõem portas no host (rede interna apenas)

### Healthchecks
- `GET /api/healthz` (frontend): Retorna `{"status":"ok"}` com 200 se o Next.js está rodando
- `GET /api/v1/health` (backend): Retorna `{"status":"ok","checks":{"database":"ok","redis":"ok"}}` com 200 se DB e Redis estão disponíveis; 503 caso contrário

### Testes
- Backend (Pest): 1 teste passando
- Frontend (Vitest): 1 teste passando

### Validações de Arquitetura
- [x] Frontend continua saudável com backend parado
- [x] PostgreSQL e Redis sem portas expostas no host
- [x] Backend espera postgres e redis ficarem healthy antes de iniciar
- [x] Frontend não tem `depends_on` para backend/postgres/redis

## Comandos

```bash
# Subir ambiente
make up

# Ver status
make ps

# Rodar testes
make test

# Parar ambiente
make down

# Logs
make logs
```

## Arquivos Criados

### Raiz
- `compose.yaml`
- `Makefile`
- `.env` / `.env.example`
- `.gitignore`
- `.editorconfig`

### Docker
- `docker/php/Dockerfile` - PHP 8.5 CLI com extensões (pdo_pgsql, redis, intl, gd, zip)
- `docker/node/Dockerfile` - Node 22 slim com curl

### Backend
- `backend/composer.json`
- `backend/artisan`
- `backend/bootstrap/app.php`
- `backend/public/index.php`
- `backend/routes/api.php`
- `backend/routes/console.php`
- `backend/config/*.php` (app, database, session, cache, cors, queue)
- `backend/tests/Feature/HealthTest.php`
- `backend/phpunit.xml`

### Frontend
- `frontend/package.json`
- `frontend/src/app/layout.tsx`
- `frontend/src/app/page.tsx`
- `frontend/src/app/api/healthz/route.ts`
- `frontend/src/test/smoke.test.ts`
- `frontend/tsconfig.json`
- `frontend/next.config.ts`
- `frontend/vitest.config.ts`
- `frontend/eslint.config.mjs`
