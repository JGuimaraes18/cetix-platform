# Entrega 0.2 - Qualidade, CI e Documentacao Base

| Campo | Valor |
| --- | --- |
| Documento | `01_structural_improvement.md` |
| Data | 2026-11-05 |
| Status | Analise tecnica completa - aguardando aprovacao |
| Base | `01_PLAN_03.md` (Revisao 4) |
| Escopo | Lint, testes, CI, Makefile e README - sem funcionalidades de negocio |

---

## 1. Diagnostico do estado atual

### 1.1 Backend (Laravel 13.40 / PHP 8.5.12)

| Item | Estado | Detalhe |
| --- | --- | --- |
| `laravel/pint` | **Instalado** (v1.32.1) | `composer.json` + `composer.lock`. Sem `pint.json` - usa preset padrao `laravel`. |
| `pestphp/pest` | **Instalado** (v5.3.5) | Com `pest-plugin-laravel` v5.0.1, `pest-plugin-arch` v5.0.0, `pest-plugin-mutate` v5.0.2. |
| Teste Pest (Feature) | **Existe e passa** | `tests/Feature/HealthTest.php` - 1 teste, 6 assercoes. |
| Testes Arch | **Ausentes** | Diretorio `tests/Arch/` vazio. Nenhum teste de arquitetura. |
| Testes Unit | **Ausentes** | Diretorio `tests/Unit/` vazio. |
| `Pest.php` | **Ausente** | Sem arquivo `tests/Pest.php` (pode ser adicionado para helpers globais, mas nao e obrigatorios). |
| `phpunit.xml` | **Existe** | Testsuites Feature/Unit, env vars para PostgreSQL e Redis. |
| Pint `--test` | **Falha** | 3 issues: `config/providers.php`, `public/index.php`, `routes/api.php` - `fully_qualified_strict_types` e `no_unused_imports`. |
| `composer.json` | **OK** | `pest` em `require-dev`, `laravel/pint` em `require-dev`, script `test` aponta para `pest`. |

### 1.2 Frontend (Next.js 16.4.5 / Node 22.23.4 / TypeScript 5.9.3)

| Item | Estado | Detalhe |
| --- | --- | --- |
| ESLint 9 + `eslint-config-next` 16 | **Instalados** | Mas `eslint.config.mjs` esta **quebrado** (ver abaixo). |
| `eslint.config.mjs` | **Quebrado** | Importa `defineConfig` de `globals` - export que nao existe. O `eslint-config-next` 16 exporta um array flat config diretamente, nao usa `defineConfig`. |
| `tsc --noEmit` | **Falha** | `vitest.config.ts:1` - `Module '"vitest"' has no exported member 'Config'`. Import incorreto. |
| `next build` (producao) | **Falha** | `postcss.config.mjs` usa `defineConfig` e `tailwindcss()` sem imports. Com Tailwind v4 + `@tailwindcss/postcss`, a sintaxe correta e `import { postcss } from '@tailwindcss/postcss'`. |
| Vitest 3.2.7 | **Instalado e funcional** | `vitest.config.ts` referencia `setupFiles: ['./src/test/setup.ts']` que existe. Smoke test passa. |
| Testing Library | **Instalado** | `@testing-library/react` 16.3.3, `@testing-library/jest-dom` 6.9.1, `jsdom` 26.1.0. |
| Tailwind CSS 4 | **Instalado** | `tailwindcss` 4.3.4, `@tailwindcss/postcss` 4.3.4. `globals.css` usa `@import 'tailwindcss'` + `@theme` - correto para v4. |
| `package.json` scripts | **Parcial** | Tem `dev`, `build`, `start`, `lint`, `test`, `test:watch`. **Falta** script `typecheck` (`tsc --noEmit`). |

### 1.3 CI/CD (GitHub Actions)

| Item | Estado | Detalhe |
| --- | --- | --- |
| `.github/workflows/` | **Diretorio vazio** | Nenhum workflow criado. |
| `backend.yml` | **Ausente** | |
| `frontend.yml` | **Ausente** | |
| `docker.yml` | **Ausente** | |

### 1.4 Makefile

| Comando | Estado | Detalhe |
| --- | --- | --- |
| `make up` | **OK** | `docker compose up -d --build` |
| `make down` | **OK** | `docker compose down` |
| `make build` | **Parcial** | So faz `docker compose build`. Nao roda `next build` de producao. |
| `make test` | **Parcial** | Roda Pest e Vitest, mas nao roda `tsc --noEmit`. |
| `make lint` | **Parcial** | Roda Pint `--test` e `eslint .`, mas nao roda `tsc --noEmit` como parte do lint. |

### 1.5 Documentacao

| Item | Estado |
| --- | --- |
| `README.md` | **Ausente** |
| `docs/architecture/environments.md` | **Ausente** |

---

## 2. Pendencias identificadas

### 2.1 Bloqueantes (impedem criterios de aceite)

| # | Item | Impacto |
| --- | --- | --- |
| P1 | `eslint.config.mjs` quebrado | `make lint` falha no frontend; CI de frontend falha |
| P2 | `postcss.config.mjs` sintaxe incorreta para Tailwind v4 | `next build` falha; `make build` falha; CI de frontend falha |
| P3 | `tsc --noEmit` falha (`vitest.config.ts` import errado) | `make lint`/`make test` incompleto; CI de frontend falha |
| P4 | Nenhum workflow GitHub Actions | Criterio "CI verde em PR" nao atendido |
| P5 | `README.md` ausente | Criterio "README permite subir o projeto do zero" nao atendido |
| P6 | Pint encontra 3 issues de estilo | `make lint` falha no backend |

### 2.2 Complementares (escopo da entrega)

| # | Item | Impacto |
| --- | --- | --- |
| P7 | Sem testes Arch | Plano exige "Teste de arquitetura basico" |
| P8 | Sem `pint.json` | Nao e obrigatorio, mas da controle explicito do preset |
| P9 | Makefile `build` nao inclui `next build` | Criterio "Build de producao do Next.js" |
| P10 | Makefile `test`/`lint` nao incluem `tsc --noEmit` | Plano exige `tsc --noEmit` como parte do CI |
| P11 | Sem script `typecheck` no `package.json` | Conveniencia para desenvolvimento local |

---

## 3. Arquivos a criar

| Arquivo | Finalidade |
| --- | --- |
| `.github/workflows/backend.yml` | CI backend: setup PHP 8.5, Composer cache, services PostgreSQL 18 + Redis 7, `composer install`, Pint `--test`, Pest (com DB e Redis) |
| `.github/workflows/frontend.yml` | CI frontend: setup Node 22, npm cache, `npm ci`, `tsc --noEmit`, ESLint, Vitest, `next build` |
| `.github/workflows/docker.yml` | CI Docker: `docker compose build` para validar Dockerfiles |
| `backend/pint.json` | Configuracao explicita do Pint (preset `laravel`, `strict_types`) |
| `backend/tests/Arch/ArchitectureTest.php` | Teste Arch: modulos nao acessam internals de outros modulos |
| `README.md` | Instrucoes de setup, variaveis de ambiente, comandos Makefile, fluxo de desenvolvimento |

### 3.1 Detalhes dos workflows

#### `backend.yml`

```yaml
name: Backend
on:
  pull_request:
    paths: ['backend/**', 'docker/php/**', 'compose.yaml']
  push:
    branches: [main]
    paths: ['backend/**', 'docker/php/**', 'compose.yaml']

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.5', extensions: pdo_pgsql, redis, intl, bcmath, zip }
      - uses: actions/cache@v4
        with: { path: ~/.composer/cache, key: composer-${{ hashFiles('backend/composer.lock') }} }
      - run: cd backend && composer install --no-interaction --no-progress
      - run: cd backend && vendor/bin/pint --test

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18-alpine
        env: { POSTGRES_USER: cetix, POSTGRES_PASSWORD: secret, POSTGRES_DB: cetix }
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U cetix"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
    env:
      DB_HOST: 127.0.0.1
      REDIS_HOST: 127.0.0.1
      DB_PASSWORD: secret
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with: { php-version: '8.5', extensions: pdo_pgsql, redis, intl, bcmath, zip }
      - uses: actions/cache@v4
        with: { path: ~/.composer/cache, key: composer-${{ hashFiles('backend/composer.lock') }} }
      - run: cd backend && composer install --no-interaction --no-progress
      - run: cd backend && php artisan key:generate --force
      - run: cd backend && php artisan test
```

> **Nota sobre `phpunit.xml`:** O arquivo atual aponta `DB_HOST=postgres` e `REDIS_HOST=redis`.
> No CI (GitHub Actions), os services expõem em `127.0.0.1`. O `<env>` do `phpunit.xml` com
> `force="false"` (default) permite que env vars do sistema sobrescrevam. O workflow define
> `DB_HOST=127.0.0.1` e `REDIS_HOST=127.0.0.1` no `env` do job, o que sobrescreve os valores
> do XML.

#### `frontend.yml`

```yaml
name: Frontend
on:
  pull_request:
    paths: ['frontend/**', 'docker/node/**', 'compose.yaml']
  push:
    branches: [main]
    paths: ['frontend/**', 'docker/node/**', 'compose.yaml']

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm', cache-dependency-path: 'frontend/package-lock.json' }
      - run: cd frontend && npm ci
      - run: cd frontend && npx tsc --noEmit
      - run: cd frontend && npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm', cache-dependency-path: 'frontend/package-lock.json' }
      - run: cd frontend && npm ci
      - run: cd frontend && npm run test

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22', cache: 'npm', cache-dependency-path: 'frontend/package-lock.json' }
      - run: cd frontend && npm ci
      - run: cd frontend && npm run build
```

#### `docker.yml`

```yaml
name: Docker
on:
  pull_request:
    paths: ['docker/**', 'compose.yaml', 'backend/**', 'frontend/**']
  push:
    branches: [main]
    paths: ['docker/**', 'compose.yaml', 'backend/**', 'frontend/**']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker compose build
```

---

## 4. Arquivos a modificar

| Arquivo | Mudanca | Motivo |
| --- | --- | --- |
| `frontend/eslint.config.mjs` | Reescrever: importar `eslint-config-next` como array flat config | P1 - ESLint quebrado |
| `frontend/postcss.config.mjs` | Reescrever: `import { postcss } from '@tailwindcss/postcss'` | P2 - Build de producao falha |
| `frontend/vitest.config.ts` | Corrigir: remover `import type { Config }` | P3 - `tsc --noEmit` falha |
| `frontend/package.json` | Adicionar script `"typecheck": "tsc --noEmit"` | P11 |
| `backend/config/providers.php` | Corrigir estilo (Pint) | P6 |
| `backend/public/index.php` | Corrigir estilo (Pint) | P6 |
| `backend/routes/api.php` | Corrigir estilo (Pint) + remover import nao usado | P6 |
| `backend/phpunit.xml` | Adicionar testsuite `Arch` | P7, P4 |
| `Makefile` | Adicionar `typecheck`; atualizar `lint` e `build` | P9, P10 |

---

## 5. Dependencias necessarias

### 5.1 Backend (Composer)

Nenhuma nova dependencia. Todas as necessarias ja estao instaladas:

| Pacote | Versao instalada | Uso |
| --- | --- | --- |
| `laravel/pint` | 1.32.1 | Lint/format |
| `pestphp/pest` | 5.3.5 | Testes |
| `pestphp/pest-plugin-arch` | 5.0.0 | Testes de arquitetura |
| `pestphp/pest-plugin-laravel` | 5.0.1 | Integracao Laravel |

### 5.2 Frontend (npm)

Nenhuma nova dependencia. Todas as necessarias ja estao instaladas:

| Pacote | Versao instalada | Uso |
| --- | --- | --- |
| `eslint` | 9.39.5 | Lint |
| `eslint-config-next` | 16.4.5 | Regras Next.js (flat config) |
| `typescript` | 5.9.3 | `tsc --noEmit` |
| `vitest` | 3.2.7 | Testes |
| `@tailwindcss/postcss` | 4.3.4 | PostCSS Tailwind v4 |
| `tailwindcss` | 4.3.4 | CSS |
| `next` | 16.4.5 | Build de producao |

### 5.3 CI (GitHub Actions)

| Action | Versao | Uso |
| --- | --- | --- |
| `actions/checkout` | v4 | Clone do repositório |
| `actions/setup-node` | v4 | Node 22 + cache npm |
| `actions/cache` | v4 | Cache Composer |
| `shivammathur/setup-php` | v2 | PHP 8.5 + extensoes |

---

## 6. Compatibilidades verificadas

| Par | Status | Detalhe |
| --- | --- | --- |
| Pint 1.32 + PHP 8.5 | **OK** | Pint suporta PHP 8.1+. Funciona corretamente. |
| Pest 5.3.5 + PHP 8.5 | **OK** | Pest 5 exige PHP 8.4+. Funciona com 8.5. |
| Pest Arch 5.0 + Pest 5.3 | **OK** | Plugin instalado e compativel. |
| Laravel 13.40 + PHP 8.5 | **OK** | Laravel 13 suporta 8.3 a 8.5. |
| ESLint 9.39 + eslint-config-next 16.4.5 | **OK** | `eslint-config-next` 16 exporta flat config (array). ESLint 9 suporta flat config nativamente. |
| TypeScript 5.9.3 + Next.js 16.4.5 | **OK** | Next 16 exige TS >= 5.1. |
| Vitest 3.2.7 + jsdom 26.1.0 | **OK** | Smoke test ja passa. |
| Tailwind 4.3.4 + `@tailwindcss/postcss` 4.3.4 | **OK** | Configuracao CSS-first. `globals.css` ja usa `@import 'tailwindcss'` + `@theme`. |
| PostgreSQL 18-alpine + Laravel 13 | **OK** | `pdo_pgsql` instalado. |
| Redis 7-alpine + Laravel 13 | **OK** | `ext-redis` instalado. |
| Node 22 + Next.js 16 | **OK** | Next 16 exige Node >= 20.9. |

### 6.1 Incompatibilidades identificadas (configuracao, nao versao)

| # | Problema | Causa | Correcao |
| --- | --- | --- | --- |
| C1 | `eslint.config.mjs` quebra | Importa `defineConfig` de `globals` (nao existe). O `eslint-config-next` 16 exporta um array flat config diretamente. | Reescrever usando o export default do `eslint-config-next` como base. |
| C2 | `postcss.config.mjs` quebra | Usa `defineConfig` e `tailwindcss()` sem imports. Com Tailwind v4, o plugin PostCSS e `@tailwindcss/postcss`. | `import { postcss } from '@tailwindcss/postcss'; export default postcss();` |
| C3 | `vitest.config.ts` falha no `tsc` | Importa `Config` de `vitest` (export nomeado que nao existe). | Remover `import type { Config }`; usar `defineConfig` de `vitest/config` sem anotacao de tipo. |
| C4 | `phpunit.xml` nao funciona fora do Docker | `DB_HOST=postgres` e `REDIS_HOST=redis` sao nomes de rede Docker. No CI, services expoe em `localhost`. | Definir env vars `DB_HOST=127.0.0.1` e `REDIS_HOST=127.0.0.1` no job do CI. |

---

## 7. Sequencia recomendada de implementacao

### Etapa 1 - Corrigir build de producao do frontend (bloqueante)

**Objetivo:** `next build` e `tsc --noEmit` passam.

1. Corrigir `frontend/postcss.config.mjs`:
   ```js
   import { postcss } from '@tailwindcss/postcss';
   export default postcss();
   ```
2. Corrigir `frontend/vitest.config.ts`:
   ```ts
   import { defineConfig } from 'vitest/config';
   export default defineConfig({
     test: {
       environment: 'jsdom',
       globals: true,
       setupFiles: ['./src/test/setup.ts'],
       include: ['src/**/*.test.{ts,tsx}'],
     },
   });
   ```
3. Verificar `npx tsc --noEmit` e `next build` no container.

**Arquivos:** `frontend/postcss.config.mjs`, `frontend/vitest.config.ts`
**Validacao:** `docker compose exec frontend npx tsc --noEmit` && `docker compose exec frontend npx next build`

### Etapa 2 - Corrigir ESLint (bloqueante)

**Objetivo:** `eslint .` passa no frontend.

1. Reescrever `frontend/eslint.config.mjs`:
   ```js
   import nextConfig from 'eslint-config-next';
   export default [
     ...nextConfig,
     { ignores: ['.next/**', 'node_modules/**', 'e2e/**'] },
   ];
   ```
   > `eslint-config-next` 16 exporta um array de flat config objects. Spread e adicionar ignores.

2. Verificar `npx eslint .` no container.

**Arquivos:** `frontend/eslint.config.mjs`
**Validacao:** `docker compose exec frontend npx eslint .`

### Etapa 3 - Corrigir Pint no backend (bloqueante)

**Objetivo:** `vendor/bin/pint --test` passa.

1. Criar `backend/pint.json`:
   ```json
   {
     "preset": "laravel",
     "rules": {
       "strict_types": true
     }
   }
   ```
2. Executar `vendor/bin/pint` (sem `--test`) para corrigir automaticamente:
   - `config/providers.php`
   - `public/index.php`
   - `routes/api.php`
3. Verificar `vendor/bin/pint --test` passa.

**Arquivos:** `backend/pint.json` (novo), `backend/config/providers.php`, `backend/public/index.php`, `backend/routes/api.php`
**Validacao:** `docker compose exec backend vendor/bin/pint --test`

### Etapa 4 - Testes de arquitetura (complementar)

**Objetivo:** Teste Arch basico para limites de modulos.

1. Criar `backend/tests/Arch/ArchitectureTest.php`:
   ```php
   <?php
   declare(strict_types=1);
   namespace Tests\Arch;
   use Tests\TestCase;
   class ArchitectureTest extends TestCase
   {
       public function test_modules_do_not_access_each_others_internals(): void
       {
           arch()
               ->expect('App\Modules\*')
               ->notToUse('App\Modules\*\Http\Controllers');
       }
   }
   ```
2. Adicionar testsuite `Arch` no `phpunit.xml`:
   ```xml
   <testsuite name="Arch">
       <directory>tests/Arch</directory>
   </testsuite>
   ```

**Arquivos:** `backend/tests/Arch/ArchitectureTest.php` (novo), `backend/phpunit.xml`
**Validacao:** `docker compose exec backend ./vendor/bin/pest --testsuite=Arch`

### Etapa 5 - Ajustar `phpunit.xml` para CI (suporte a CI)

**Objetivo:** Testes funcionam tanto no Docker (dev) quanto no GitHub Actions (CI).

1. Manter o `phpunit.xml` com valores Docker (`postgres`, `redis`).
2. No workflow CI, definir env vars `DB_HOST=127.0.0.1`, `REDIS_HOST=127.0.0.1`, `DB_PASSWORD=secret` no job.
3. O `<env>` do `phpunit.xml` com `force="false"` (default) permite override por env vars do sistema.

**Arquivos:** `backend/phpunit.xml` (verificacao de comportamento)
**Validacao:** Testes passam no CI com services PostgreSQL/Redis.

### Etapa 6 - Workflows GitHub Actions (bloqueante)

**Objetivo:** CI verde em PR.

1. Criar `.github/workflows/backend.yml` (lint + test com services).
2. Criar `.github/workflows/frontend.yml` (lint + test + build).
3. Criar `.github/workflows/docker.yml` (docker compose build).

Detalhes na secao 3.1.

**Arquivos:** `.github/workflows/backend.yml`, `.github/workflows/frontend.yml`, `.github/workflows/docker.yml` (todos novos)
**Validacao:** Push/PR dispara workflows; todos passam.

### Etapa 7 - Makefile (complementar)

**Objetivo:** Comandos completos e consistentes.

1. Adicionar `typecheck` ao `Makefile`:
   ```makefile
   typecheck:
   docker compose exec frontend npx tsc --noEmit
   ```
2. Atualizar `lint` para incluir `typecheck`:
   ```makefile
   lint: typecheck
   docker compose exec backend vendor/bin/pint --test
   docker compose exec frontend npm run lint
   ```
3. Atualizar `build` para incluir build de producao do frontend:
   ```makefile
   build:
   docker compose build
   docker compose exec frontend npm run build
   ```
4. Adicionar script `typecheck` ao `package.json`:
   ```json
   "typecheck": "tsc --noEmit"
   ```

**Arquivos:** `Makefile`, `frontend/package.json`
**Validacao:** `make lint`, `make test`, `make build` passam localmente.

### Etapa 8 - README (bloqueante)

**Objetivo:** Documentacao para subir o projeto do zero.

Conteudo minimo:
- Descricao do projeto (CETIX)
- Stack tecnologico
- Pre-requisitos (Docker, Docker Compose)
- Setup: clonar, copiar `.env`, `make up`
- Variaveis de ambiente (tabela com `backend/.env.example` e `frontend/.env.example`)
- Comandos Makefile (`up`, `down`, `ps`, `logs`, `test`, `lint`, `build`, `migrate`, `key`)
- Endpoints de healthcheck
- Fluxo basico de desenvolvimento
- Estrutura do repositorio

**Arquivos:** `README.md` (novo)
**Validacao:** Uma pessoa consegue subir o projeto seguindo apenas o README.

---

## 8. Estrategia de testes

| Nivel | Ferramenta | O que testa | Quando roda |
| --- | --- | --- | --- |
| Backend - Feature | Pest | Health check (DB + Redis) | `make test`, CI |
| Backend - Arch | Pest Arch | Limites de modulos | `make test`, CI |
| Backend - Lint | Pint | Estilo de codigo PHP | `make lint`, CI |
| Frontend - Unit | Vitest | Smoke test | `make test`, CI |
| Frontend - Lint | ESLint | Estilo de codigo TS/TSX | `make lint`, CI |
| Frontend - Types | `tsc --noEmit` | Verificacao de tipos | `make lint`, CI |
| Frontend - Build | `next build` | Build de producao | `make build`, CI |
| Docker | `docker compose build` | Dockerfiles validos | CI |

### 8.1 Testes com PostgreSQL e Redis no CI

- **GitHub Actions services:** `postgres:18-alpine` e `redis:7-alpine` como services do job.
- **Env vars no job:** `DB_HOST=127.0.0.1`, `REDIS_HOST=127.0.0.1`, `DB_PASSWORD=secret`.
- **O `phpunit.xml`** mantem os valores Docker; o CI sobrescreve via env vars do sistema.
- **Migrations:** Nao sao executadas no CI (nenhuma migration existe ainda na Entrega 0.2).

### 8.2 O que NAO e testado nesta entrega

- Funcionalidades de negocio (Entrega 1+)
- E2E com Playwright (Entrega 12)
- Cobertura de codigo (meta para entregas futuras)
- Testes de concorrencia (Entrega 8)

---

## 9. Criterios de aceite

| # | Criterio | Como validar |
| --- | --- | --- |
| A1 | `make lint` passa localmente | Executar no ambiente Docker |
| A2 | `make test` passa localmente | Executar no ambiente Docker |
| A3 | `make build` passa localmente | Executar no ambiente Docker |
| A4 | CI verde em PR | Abrir PR e verificar workflows |
| A5 | Nenhuma credencial versionada | Revisar `.env`, `phpunit.xml`, workflows |
| A6 | README permite subir o projeto do zero | Seguir instrucoes do README em ambiente limpo |
| A7 | `tsc --noEmit` passa | `docker compose exec frontend npx tsc --noEmit` |
| A8 | `next build` passa | `docker compose exec frontend npx next build` |
| A9 | `eslint .` passa | `docker compose exec frontend npx eslint .` |
| A10 | `pint --test` passa | `docker compose exec backend vendor/bin/pint --test` |
| A11 | Pest (Feature + Arch) passa | `docker compose exec backend ./vendor/bin/pest` |
| A12 | Vitest passa | `docker compose exec frontend npm run test` |

---

## 10. Riscos e possiveis impedimentos

| # | Risco | Probabilidade | Impacto | Mitigacao |
| --- | --- | --- | --- | --- |
| R1 | `phpunit.xml` nao respeita env vars do sistema | Media | Alto (CI falha) | Testar localmente simulando CI; se necessario, criar `phpunit.ci.xml` |
| R2 | `eslint-config-next` 16 muda formato de export em update patch | Baixa | Medio | Fixar versao exata no `package.json` |
| R3 | Pest Arch nao suporta a convencao de modulos | Baixa | Medio | Validar no bootstrap; usar config custom se necessario |
| R4 | `next build` com `output: 'standalone'` gera artefato grande no CI | Baixa | Baixo | Nao upload do artefato ou usar exclusoes |
| R5 | GitHub Actions sem Docker para `docker.yml` | Baixa | Medio | `ubuntu-latest` tem Docker disponivel |
| R6 | PostgreSQL 18-alpine no CI vs. 18-bookworm em prod | Baixa | Baixo | Para CI, `alpine` e aceitavel |
| R7 | Env var `DB_PASSWORD` vazia no `phpunit.xml` | Media | Medio | Definir `DB_PASSWORD=secret` no env do job CI |

---

## 11. Resumo de mudancas

### Arquivos a criar (6)

| Arquivo | Etapa |
| --- | --- |
| `.github/workflows/backend.yml` | 6 |
| `.github/workflows/frontend.yml` | 6 |
| `.github/workflows/docker.yml` | 6 |
| `backend/pint.json` | 3 |
| `backend/tests/Arch/ArchitectureTest.php` | 4 |
| `README.md` | 8 |

### Arquivos a modificar (9)

| Arquivo | Etapa | Mudanca |
| --- | --- | --- |
| `frontend/postcss.config.mjs` | 1 | Corrigir para Tailwind v4 |
| `frontend/vitest.config.ts` | 1 | Remover import invalido de `Config` |
| `frontend/eslint.config.mjs` | 2 | Reescrever para flat config |
| `frontend/package.json` | 7 | Adicionar script `typecheck` |
| `backend/config/providers.php` | 3 | Corrigir estilo (Pint) |
| `backend/public/index.php` | 3 | Corrigir estilo (Pint) |
| `backend/routes/api.php` | 3 | Corrigir estilo (Pint) + remover import |
| `backend/phpunit.xml` | 4 | Adicionar testsuite `Arch` |
| `Makefile` | 7 | Adicionar `typecheck`; atualizar `lint` e `build` |

### Dependencias a adicionar (0)

Nenhuma. Todas as dependencias necessarias ja estao instaladas.

---

## 12. O que NAO muda nesta entrega

- `compose.yaml` - sem alteracoes
- `docker/php/Dockerfile` - sem alteracoes
- `docker/node/Dockerfile` - sem alteracoes
- `backend/bootstrap/app.php` - sem alteracoes
- `backend/routes/api.php` - apenas correcao de estilo (Pint), sem mudanca funcional
- `frontend/src/**` - sem alteracoes de codigo de aplicacao
- Nenhuma funcionalidade de negocio
- Nenhuma autenticacao ou RBAC
- Nenhuma migration nova
- Nenhum commit ou push

---

## 13. Aprovacao

Aguardando aprovacao para iniciar a implementacao.
