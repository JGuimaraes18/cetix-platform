# Plano Técnico — CETIx Platform

| Campo | Valor |
| --- | --- |
| Documento | 01_PLAN.md |
| Versão | 1.0 |
| Data | 2026-11-04 |
| Status | Aguardando aprovação |
| Escopo | Planejamento técnico e levantamento de ambiente |
| Implementação | Não iniciada por decisão do solicitante |

> Este documento é exclusivamente de planejamento. Nenhum código de aplicação,
> dependência ou container foi criado ou executado durante o levantamento.

---

## 1. Diagnóstico do ambiente

### 1.1 Resumo executivo

O ambiente possui **Docker funcional** com imagens recentes de PHP, PostgreSQL,
Redis, Nginx, Node e Composer, o que permite desenvolver e testar todo o projeto
sem depender da instalação local de PHP. Entretanto, **PHP e Composer não estão
instalados no host**, e **Redis não está disponível nativamente**. A estratégia
recomendada é tornar o Docker Compose a fonte de verdade do ambiente de
desenvolvimento, mantendo o host apenas como hospedeiro do Docker e do Git.

### 1.2 Inventário detalhado

| Item | Situação | Versão / Detalhe | Observação |
| --- | --- | --- | --- |
| Sistema operacional | Disponível | Ubuntu 22.04.5 LTS (Jammy) | Kernel 6.8.0-138-generic, x86_64 |
| PHP | **Ausente** | `php: command not found` | Não é possível listar extensões no host |
| Composer | **Ausente** | `composer: command not found` | Deve rodar via container |
| Docker Engine | Disponível | 29.1.5 | Daemon ativo |
| Docker Compose | Disponível | v5.0.2 (plugin) | `docker compose` funcional |
| Driver de storage Docker | Disponível | overlayfs | Cgroup v2 |
| Recursos Docker | Disponível | 8 CPUs, ~15,9 GiB RAM | ~8,8 GiB disponíveis no host |
| Node.js | Disponível | v22.23.3 | Compatível com Next.js atual |
| npm | Disponível | 10.9.9 | Gerenciador padrão proposto |
| pnpm | Ausente | — | Não será exigido |
| yarn | Ausente | — | Não será exigido |
| Git | Disponível | 2.34.1 | Identidade configurada |
| Repositório | Inicializado | Branch `master`, sem commits | Remote `origin` aponta para GitHub |
| Cliente PostgreSQL | Disponível | psql 14.24 | Apenas cliente; servidor não verificado |
| Servidor PostgreSQL | Não verificado no host | — | Recomendado via container |
| Redis | **Ausente no host** | `redis-cli: command not found` | Recomendado via container |
| Build tools | Disponíveis | gcc, g++, make 4.3 | Úteis para extensões nativas |
| Utilitários | Disponíveis | curl, jq | Apoio a scripts e healthchecks |
| Disco | Disponível | ~211 GB livres em `/` | Suficiente para imagens e volumes |

### 1.3 Imagens Docker já presentes (relevantes)

| Imagem | Uso previsto |
| --- | --- |
| `php:8.5.12-cli-bookworm` | Composer, Artisan, Pest e tarefas CLI |
| `php:8.5.12-apache-bookworm` | Alternativa simplificada de runtime |
| `composer:2.10.3` | Instalação de dependências PHP |
| `postgres:18-alpine` | Banco de dados principal |
| `postgres:16-alpine` | Alternativa estável, se necessário |
| `redis:7-alpine` | Cache, sessões e filas |
| `nginx:alpine` | Reverse proxy e arquivos estáticos |
| `node:20-bookworm-slim` | Alternativa para build do frontend |
| `node:18-alpine` | Não recomendado para o projeto |

> A imagem PHP disponível é CLI/Apache. Para o runtime recomendado
> (Nginx + PHP-FPM) será necessário construir/baixar uma imagem `php:8.5-fpm`
> na etapa de bootstrap, o que é esperado e não fere as restrições atuais.

### 1.4 Extensões PHP necessárias para Laravel

Como o PHP não está instalado no host, **não foi possível verificar** quais
extensões existem localmente. A imagem Docker do backend deverá habilitar, no
mínimo:

| Extensão | Motivo |
| --- | --- |
| `ctype`, `filter`, `hash`, `pcre`, `tokenizer` | Requisitos base do Laravel |
| `mbstring` | Strings multibyte |
| `openssl` | Criptografia, HTTPS e Sanctum |
| `json` | Serialização de API |
| `curl` | Integrações HTTP |
| `dom`, `xml`, `xmlwriter` | Validação, parsers e testes |
| `fileinfo` | Upload e detecção de arquivos |
| `pdo`, `pdo_pgsql` | Acesso ao PostgreSQL |
| `bcmath` | Cálculos precisos (capacidade, custos) |
| `intl` | Formatação de datas/números |
| `zip` | Composer e pacotes |
| `sodium` | Criptografia moderna |
| `redis` (PECL) | Sessões, cache e filas via Redis |
| `gd` ou `imagick` | Opcional; apenas se houver imagens/fotos de ativos |

### 1.5 Lacunas e impacto

| Lacuna | Impacto | Mitigação |
| --- | --- | --- |
| PHP ausente no host | Não é possível rodar Artisan/Composer diretamente | Docker Compose como ambiente oficial |
| Composer ausente no host | Instalação de pacotes inviável fora do container | Container `composer` ou estágio de build |
| Redis ausente no host | Sessões/cache/filas não funcionam nativamente | Serviço `redis` no Compose |
| PostgreSQL apenas cliente | Sem servidor local confirmado | Serviço `postgres` no Compose |
| Repositório sem commits | Sem histórico para rollback | Primeiro commit apenas após aprovação |
| `php:8.5-fpm` não está local | Primeiro build exige pull da imagem | Executar no bootstrap, com internet |

### 1.6 Conclusão da Etapa 1

O ambiente é **viável para o projeto**, desde que o desenvolvimento seja
conteinerizado. A ausência de PHP/Composer/Redis no host não é bloqueante e,
na prática, reforça a decisão de padronizar o ambiente via Docker. A única
verificação pendente é a compatibilidade exata entre Laravel 13 e PHP 8.5 no
momento do bootstrap; recomenda-se validar as constraints do Composer antes de
fixar versões.

---

## 2. Arquitetura recomendada

### 2.1 Visão geral

```text
+-----------------------------+          +-----------------------------+
|        Frontend Next.js     |  HTTPS   |        Backend Laravel      |
|  App Router + TypeScript    | -------> |  API REST versionada /api/v1|
|  Tailwind CSS               |  JSON    |  Sanctum + Spatie Permission|
+-------------+---------------+          +------+----------+-----------+
              |                                 |          |
              |                                 |          |
      +-------v--------+                +-------v--+  +----v-----+
      | Sessão/cookie  |                |PostgreSQL|  |  Redis   |
      | HttpOnly CSRF  |                |   18     |  | cache/   |
      +----------------+                +----------+  | filas    |
                                                      +----------+
```

Princípios:

1. **Monólito modular** no backend, sem microsserviços.
2. **Frontend e backend independentes**, comunicando-se exclusivamente por API REST.
3. **Docker Compose** como ambiente oficial de desenvolvimento.
4. **Segurança por padrão**: HTTPS em produção, cookies `HttpOnly`/`Secure`,
   CORS restrito, rate limiting, validação e autorização em todas as camadas.
5. **Simplicidade primeiro**: evitar dependências e abstrações sem necessidade
   comprovada; o projeto é portfólio, mas deve demonstrar maturidade e não
   complexidade artificial.

### 2.2 Organização do backend Laravel

Recomenda-se um **monólito modular baseado em pastas**, sem adotar
`nwidart/laravel-modules` neste primeiro momento. A estrutura proposta usa
namespaces próprios via PSR-4 e mantém as convenções nativas do Laravel.

```text
backend/
├── app/
│   ├── Modules/
│   │   ├── Auth/
│   │   │   ├── Actions/
│   │   │   ├── Http/
│   │   │   │   ├── Controllers/
│   │   │   │   ├── Requests/
│   │   │   │   └── Resources/
│   │   │   ├── Models/
│   │   │   ├── Policies/
│   │   │   ├── Routes/
│   │   │   └── Tests/
│   │   ├── Access/
│   │   ├── Datacenter/
│   │   ├── Rack/
│   │   ├── Asset/
│   │   ├── Service/
│   │   ├── Audit/
│   │   ├── Dashboard/
│   │   └── Shared/
│   │       ├── Enums/
│   │       ├── Exceptions/
│   │       ├── Support/
│   │       └── Traits/
│   ├── Providers/
│   └── ...
├── bootstrap/
├── config/
├── database/
│   ├── factories/
│   ├── migrations/
│   └── seeders/
├── routes/
│   ├── api.php
│   └── console.php
├── tests/
│   ├── Feature/
│   ├── Unit/
│   └── Arch/
└── composer.json
```

Diretrizes por módulo:

| Camada | Responsabilidade |
| --- | --- |
| `Models` | Entidades Eloquent, relacionamentos, casts, scopes |
| `Actions` | Casos de uso transacionais (ex.: `CreateAssetAction`) |
| `Http/Controllers` | Orquestração fina; sem regra de negócio pesada |
| `Http/Requests` | Validação e autorização de entrada |
| `Http/Resources` | Serialização estável da API |
| `Policies` | Autorização por recurso |
| `Routes` | Rotas do módulo, carregadas por um provider |
| `Tests` | Testes específicos do módulo |

Regras arquiteturais:

- Controllers não acessam modelos de outros módulos diretamente; usam
  `Actions`, contratos ou eventos.
- Não introduzir `Repositories` por padrão. Eloquent já é a camada de acesso a
  dados; repositories só entram se houver necessidade real de troca de fonte.
- Eventos de domínio para efeitos colaterais (ex.: auditoria, notificações).
- Enums nativos do PHP para status, criticidade e tipos.
- `declare(strict_types=1)` nos arquivos de aplicação.
- Um provider por módulo registra rotas, policies e observers.

### 2.3 Organização do frontend Next.js

Recomenda-se **Next.js com App Router**, TypeScript estrito e Tailwind CSS.
A organização será por **features**, evitando pastas genéricas gigantes.

```text
frontend/
├── src/
│   ├── app/
│   │   ├── (auth)/
│   │   │   └── login/page.tsx
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   ├── datacenters/
│   │   │   ├── racks/
│   │   │   ├── assets/
│   │   │   ├── services/
│   │   │   └── audit/
│   │   ├── layout.tsx
│   │   └── globals.css
│   ├── components/
│   │   ├── ui/
│   │   └── layout/
│   ├── features/
│   │   ├── auth/
│   │   ├── datacenters/
│   │   ├── racks/
│   │   ├── assets/
│   │   ├── services/
│   │   ├── audit/
│   │   └── dashboard/
│   ├── lib/
│   │   ├── api/
│   │   ├── auth/
│   │   └── utils/
│   ├── hooks/
│   ├── types/
│   └── config/
├── public/
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
└── package.json
```

Diretrizes:

- Server Components para leitura inicial e SEO; Client Components apenas onde há
  interatividade.
- Um cliente HTTP tipado em `src/lib/api` centraliza base URL, credenciais,
  tratamento de erro e CSRF.
- Validação de formulários com `zod` e mensagens consistentes.
- Componentes de UI próprios e pequenos; evitar bibliotecas de componentes
  pesadas no início.
- Sem `localStorage` para credenciais.
- Tipos da API em `src/types`, preferencialmente derivados de um contrato
  OpenAPI no futuro.

### 2.4 Comunicação frontend ↔ backend

| Aspecto | Decisão |
| --- | --- |
| Protocolo | REST sobre HTTPS |
| Formato | JSON (`application/json`) |
| Versionamento | Prefixo `/api/v1` |
| Autenticação | Cookie de sessão Sanctum (SPA) + CSRF |
| Paginação | Query params `page`, `per_page`; resposta com `data`, `meta`, `links` |
| Filtros | Query params explícitos (`status`, `environment_id`, `search`) |
| Erros | Formato único com `message`, `errors` e `code` opcional |
| Datas | ISO 8601 em UTC; frontend formata no fuso do usuário |
| CORS | Apenas origem do frontend, com `credentials` |
| Rate limiting | Limites por rota e por usuário/IP |
| Documentação | OpenAPI gerado (Scramble ou Scribe) na entrega de hardening |

Recomenda-se **não** usar GraphQL nem tRPC, pois o backend é independente e a
API REST é requisito explícito.

### 2.5 Estratégia de autenticação com Sanctum

Cenário: SPA Next.js first-party, mas em origem separada do backend.

**Recomendação principal: autenticação por cookie de sessão do Sanctum.**

Fluxo:

1. Frontend chama `GET /sanctum/csrf-cookie` para obter o cookie `XSRF-TOKEN`.
2. Frontend envia `POST /api/v1/auth/login` com `withCredentials` e o token CSRF
   no header `X-XSRF-TOKEN`.
3. Backend autentica via guard `web` e regenera a sessão.
4. Sessões armazenadas no Redis.
5. Requisições seguintes usam o cookie de sessão `HttpOnly`.
6. `POST /api/v1/auth/logout` invalida a sessão e regenera o token CSRF.
7. `GET /api/v1/auth/me` retorna usuário, papéis e permissões efetivas.

Configurações obrigatórias:

- `SANCTUM_STATEFUL_DOMAINS` com os domínios do frontend.
- `SESSION_DOMAIN` compartilhado em produção (ex.: `.seudominio.com`).
- `SESSION_DRIVER=redis`.
- Cookies `HttpOnly`, `Secure` em produção e `SameSite=Lax`.
- `config/cors.php` com `supports_credentials = true` e origem explícita.
- Middleware `EnsureFrontendRequestsAreStateful` no grupo da API.
- Rate limiting no login e no reset de senha.

**Alternativa:** tokens pessoais do Sanctum (`Authorization: Bearer`) para
integrações, CLI e futuros aplicativos móveis. Não usar tokens em
`localStorage`; se necessário, usar cookies seguros ou memória de curta duração.

Justificativa: cookie de sessão reduz exposição a XSS, permite revogação
centralizada, integra-se melhor ao fluxo SPA do Sanctum e é o padrão recomendado
pela documentação oficial para SPAs first-party.

### 2.6 Controle de permissões (RBAC)

Uso do **Spatie Laravel Permission** com papéis e permissões no guard `web`.

Papéis iniciais sugeridos:

| Papel | Escopo |
| --- | --- |
| `admin` | Acesso total, gestão de usuários e permissões |
| `operator` | Gestão operacional de datacenters, racks, ativos e serviços |
| `auditor` | Leitura ampla e acesso à auditoria |
| `viewer` | Somente leitura |

Permissões nomeadas por módulo e ação:

```text
users.view, users.manage
roles.view, roles.manage
datacenters.view, datacenters.manage
environments.view, environments.manage
racks.view, racks.manage
assets.view, assets.manage
services.view, services.manage
audit.view
dashboard.view
```

Diretrizes:

- Autorização em **duas camadas**: middleware/permission na rota e Policy no
  recurso.
- Não usar checagem de papel diretamente no frontend como segurança; o frontend
  apenas esconde ações, o backend sempre valida.
- Seeders idempotentes para papéis e permissões.
- Limpar cache de permissões em eventos de alteração.
- **Não** habilitar o recurso de `teams` inicialmente; se houver necessidade de
  multi-tenant, avaliar em fase futura.
- Registrar em auditoria alterações de papéis e permissões.

### 2.7 Modelagem inicial do PostgreSQL

Decisões de modelagem:

- Chaves primárias **ULID** nas entidades de domínio (não enumeráveis, ordenáveis
  e adequadas para exposição pública).
- `timestamps` com timezone; armazenar em UTC.
- `softDeletes` em entidades críticas (datacenters, ambientes, racks, ativos,
  serviços, usuários).
- `jsonb` para metadados e valores de auditoria.
- Constraints e índices explícitos no banco, não apenas na aplicação.
- Enums de domínio via `string` + `check` ou enums nativos do PostgreSQL;
  recomenda-se `string` com validação na aplicação para facilitar evolução.

Entidades e relacionamentos principais:

```text
users 1---N audit_logs
users N---N roles N---N permissions        (tabelas do Spatie)

datacenters 1---N environments
environments 1---N racks
racks 1---N assets
asset_types 1---N assets
environments 1---N services
services N---N assets                       (service_asset)

users 1---N services                        (owner)
```

Tabelas propostas:

| Tabela | Campos principais | Restrições/índices |
| --- | --- | --- |
| `users` | `id` (ULID), `name`, `email`, `password`, `is_active`, timestamps, soft delete | `email` único |
| `roles`, `permissions`, `model_has_roles`, `model_has_permissions`, `role_has_permissions` | Estrutura do Spatie | Conforme pacote |
| `datacenters` | `id`, `name`, `code`, `city`, `state`, `country`, `address`, `timezone`, `status`, `notes` | `code` único; índice em `status` |
| `environments` | `id`, `datacenter_id`, `name`, `code`, `type`, `status`, `description` | `(datacenter_id, code)` único; FK |
| `racks` | `id`, `environment_id`, `name`, `code`, `row`, `position`, `total_units`, `power_capacity_watts`, `status` | `(environment_id, code)` único; `total_units > 0` |
| `asset_types` | `id`, `name`, `slug`, `category`, `is_active` | `slug` único |
| `assets` | `id`, `asset_tag`, `serial_number`, `name`, `manufacturer`, `model`, `asset_type_id`, `rack_id`, `environment_id`, `rack_unit_start`, `rack_unit_size`, `status`, `management_ip`, `mac_address`, `purchase_date`, `warranty_expires_at`, `notes` | `asset_tag` único; `serial_number` único quando não nulo; FKs; índices em `status`, `asset_type_id`, `rack_id` |
| `services` | `id`, `name`, `slug`, `environment_id`, `owner_id`, `criticality`, `status`, `url`, `description` | `slug` único; FKs; índice em `criticality` |
| `service_asset` | `service_id`, `asset_id` | PK composta; FKs com `cascade` |
| `audit_logs` | `id`, `auditable_type`, `auditable_id`, `event`, `old_values` (jsonb), `new_values` (jsonb), `user_id`, `ip_address`, `user_agent`, `created_at` | Índices em `(auditable_type, auditable_id)`, `user_id`, `created_at`; sem update/delete pela aplicação |

Regras de integridade recomendadas:

- `assets.environment_id` deve ser consistente com o ambiente do rack.
- Um ativo não pode ocupar posições sobrepostas no mesmo rack; validar em
  transação e, se possível, reforçar com constraint.
- `rack_unit_start + rack_unit_size - 1 <= racks.total_units`.
- Exclusão de datacenter com ambientes, ou de rack com ativos, deve ser
  bloqueada ou exigir desativação/realocação explícita.
- Auditoria é **append-only**; não expor endpoints de edição/exclusão.
- Senhas e tokens nunca entram em `old_values`/`new_values`.

Evoluções futuras (fora do escopo inicial): redes/IPs, circuitos de energia,
contratos, fornecedores, anexos, etiquetas QR e multi-tenant.

### 2.8 Estratégia de testes

Ferramenta: **Pest**, integrado ao Laravel.

Pirâmide adaptada ao projeto:

| Nível | Escopo | Exemplos |
| --- | --- | --- |
| Unit | Actions, enums, regras puras, policies | Cálculo de ocupação de rack, permissões |
| Feature | Endpoints HTTP, validação, autorização, banco | CRUD de ativos, login, filtros |
| Arch | Limites arquiteturais | Módulos não acessam internals de outros |
| E2E (opcional) | Fluxos críticos no frontend | Login, criação de ativo |

Diretrizes:

- Banco de testes **PostgreSQL**, não SQLite, para validar `jsonb`, constraints e
  comportamento real.
- `RefreshDatabase` por padrão; transações quando possível.
- Factories e seeders determinísticos.
- Testes de autorização para cada endpoint sensível (401/403).
- Testes de contrato de resposta (estrutura, status, campos).
- Testes de arquitetura para impedir acoplamento indevido entre módulos.
- Cobertura meta: mínimo de 80% nos módulos críticos (Auth, Access, Asset,
  Audit); não perseguir 100% artificialmente.
- CI executa suíte completa com serviços PostgreSQL e Redis.
- Frontend: Vitest + Testing Library para componentes críticos; Playwright
  apenas para fluxos essenciais, se o custo compensar.

### 2.9 Organização dos containers

Serviços propostos no `compose.yaml`:

| Serviço | Imagem/base | Função |
| --- | --- | --- |
| `backend` | `php:8.5-fpm-bookworm` customizado | PHP-FPM + extensões |
| `nginx` | `nginx:alpine` | Reverse proxy do backend |
| `frontend` | `node:22-bookworm-slim` | Next.js em modo dev/build |
| `postgres` | `postgres:18-alpine` | Banco principal |
| `redis` | `redis:7-alpine` | Cache, sessões e filas |
| `worker` | mesma imagem do backend | `queue:work` (habilitar quando houver filas) |
| `scheduler` | mesma imagem do backend | `schedule:work` (habilitar quando houver agendamentos) |

Diretrizes:

- `compose.yaml` base para desenvolvimento e `compose.prod.yaml` (ou
  `docker-compose.prod.yml`) para produção.
- Volumes nomeados para PostgreSQL e Redis; bind mount do código apenas em dev.
- Healthchecks para Postgres, Redis, backend e frontend.
- Rede interna dedicada; apenas `nginx` e `frontend` expõem portas.
- Variáveis sensíveis via `.env` (nunca versionado) e `.env.example` versionado.
- Imagens de produção multi-stage, sem dev dependencies e rodando como usuário
  não-root.
- Composer e npm executados em estágios de build, não no runtime.
- `Makefile` com atalhos: `make up`, `make down`, `make test`, `make lint`,
  `make migrate`, `make fresh`.

---

## 3. Estrutura proposta do repositório

Monorepo com backend, frontend, infraestrutura e documentação:

```text
cetix-platform/
├── .github/
│   └── workflows/
│       ├── backend.yml
│       ├── frontend.yml
│       └── docker.yml
├── backend/
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/
│   ├── routes/
│   ├── storage/
│   ├── tests/
│   ├── composer.json
│   ├── composer.lock
│   ├── phpunit.xml
│   └── pint.json
├── frontend/
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── package-lock.json
│   ├── next.config.ts
│   ├── tailwind.config.ts
│   ├── tsconfig.json
│   └── eslint.config.mjs
├── docker/
│   ├── php/
│   │   └── Dockerfile
│   ├── nginx/
│   │   └── default.conf
│   └── node/
│       └── Dockerfile
├── docs/
│   ├── agents/
│   │   └── 01_PLAN.md
│   ├── architecture/
│   └── api/
├── compose.yaml
├── compose.prod.yaml
├── Makefile
├── .editorconfig
├── .gitignore
├── .env.example
└── README.md
```

Justificativa:

- Monorepo facilita versionamento coordenado e portfólio único.
- Separação clara entre aplicações e infraestrutura.
- `docs/` mantém decisões, planos e contratos próximos do código.
- Sem submódulos ou workspaces npm complexos neste momento.

---

## 4. Dependências necessárias

### 4.1 Backend (Composer)

| Dependência | Finalidade | Obrigatória |
| --- | --- | --- |
| `php` `^8.5` | Runtime | Sim |
| `laravel/framework` `^13` | Framework | Sim |
| `laravel/sanctum` | Autenticação SPA/tokens | Sim |
| `spatie/laravel-permission` | RBAC | Sim |
| `pestphp/pest` + `pestphp/pest-plugin-laravel` | Testes | Sim (dev) |
| `laravel/pint` | Formatação | Sim (dev) |
| `nunomaduro/collision` | Erros legíveis em CLI | Sim (dev) |
| `laravel/tinker` | REPL | Sim (dev) |
| `dedoc/scramble` | OpenAPI | Opcional (dev) |
| `laravel/horizon` | Monitoramento de filas Redis | Opcional, apenas se filas |
| `spatie/laravel-activitylog` | Auditoria pronta | Opcional; recomendação inicial é auditoria própria |

Observações:

- Validar no bootstrap se Laravel 13 aceita PHP 8.5 sem conflitos. Caso o
  pacote ainda não suporte oficialmente, usar a última versão estável compatível
  e registrar a decisão.
- Não adicionar pacotes de módulos, repositórios genéricos ou admin panels
  (ex.: Filament) sem necessidade aprovada.
- Para auditoria, a recomendação é um módulo próprio com observers/listeners,
  garantindo controle do schema e das regras de redaction.

### 4.2 Frontend (npm)

| Dependência | Finalidade | Obrigatória |
| --- | --- | --- |
| `next` | Framework React | Sim |
| `react`, `react-dom` | UI | Sim |
| `typescript` | Tipagem | Sim |
| `tailwindcss` + `@tailwindcss/postcss` | Estilo | Sim |
| `zod` | Validação de formulários/contratos | Sim |
| `eslint`, `eslint-config-next` | Lint | Sim (dev) |
| `prettier`, `prettier-plugin-tailwindcss` | Formatação | Sim (dev) |
| `vitest`, `@testing-library/react`, `jsdom` | Testes de componentes | Opcional (dev) |
| `@playwright/test` | E2E | Opcional (dev) |
| `@tanstack/react-query` | Cache/estado de servidor | Opcional; só se necessário |

Observações:

- Não usar `axios` por padrão; `fetch` nativo com wrapper tipado é suficiente.
- Não adotar biblioteca de componentes grande no início; criar componentes
  pequenos em `components/ui`.
- Evitar dependências de estado global até existir necessidade real.

### 4.3 Infraestrutura e ferramentas

| Item | Versão sugerida | Observação |
| --- | --- | --- |
| Docker Engine | 29.x | Já disponível |
| Docker Compose | v5.x | Já disponível |
| PostgreSQL | 18-alpine | Imagem já presente |
| Redis | 7-alpine | Imagem já presente |
| Nginx | alpine | Imagem já presente |
| Node.js | 22 LTS | Host e imagem |
| PHP | 8.5 | Imagem 8.5.12 disponível |
| Composer | 2.10.x | Imagem 2.10.3 disponível |
| GitHub Actions | — | CI/CD |

---

## 5. Roadmap de desenvolvimento

O roadmap é organizado em entregas pequenas, incrementais e testáveis. Cada
entrega deve terminar com pipeline verde e documentação mínima atualizada.

### Entrega 0 — Fundação do repositório e ambiente Docker

**Objetivo:** criar a base do monorepo, o ambiente conteinerizado e o esqueleto
das aplicações, sem regras de negócio.

**Funcionalidades:**
- Estrutura `backend/`, `frontend/`, `docker/`, `docs/`, `.github/`.
- `compose.yaml` com backend, nginx, frontend, postgres e redis.
- Dockerfile PHP 8.5-FPM com extensões necessárias.
- Dockerfile Node 22 e configuração do Next.js.
- Laravel instalado e configurado para PostgreSQL/Redis.
- Next.js com TypeScript, Tailwind e layout inicial.
- Endpoint `GET /api/v1/health`.
- `Makefile`, `.env.example`, `.editorconfig`, `.gitignore`.
- Pipeline inicial de lint e testes.

**Arquivos/componentes:**
- `compose.yaml`, `compose.prod.yaml`
- `docker/php/Dockerfile`, `docker/nginx/default.conf`, `docker/node/Dockerfile`
- `backend/*` (esqueleto Laravel)
- `frontend/*` (esqueleto Next.js)
- `.github/workflows/backend.yml`, `frontend.yml`, `docker.yml`
- `Makefile`, `README.md`

**Critérios de aceitação:**
- `make up` sobe todos os serviços com healthchecks saudáveis.
- `GET /api/v1/health` responde `200` com status da aplicação.
- Frontend acessível e consumindo o health check.
- `make test` executa testes do backend e do frontend.
- `make lint` passa sem erros.
- CI verde no primeiro Pull Request.
- Nenhuma credencial versionada.

**Testes necessários:**
- Feature test do health check.
- Teste de arquitetura básico do backend.
- Build de produção do frontend.
- Smoke test de conectividade com PostgreSQL e Redis.

---

### Entrega 1 — Autenticação e usuários

**Objetivo:** permitir login, logout, sessão e gestão básica de usuários.

**Funcionalidades:**
- Migração e model `User` com ULID, status ativo/inativo e soft delete.
- Instalação e configuração do Sanctum para SPA.
- Endpoints: `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`,
  `POST /auth/forgot-password`, `POST /auth/reset-password`.
- Atualização de perfil do próprio usuário.
- Listagem e gestão de usuários por administrador.
- Rate limiting no login e recuperação de senha.
- Tela de login e guarda de rotas no frontend.

**Arquivos/componentes:**
- `backend/app/Modules/Auth/*`
- `backend/app/Modules/Users/*`
- `backend/database/migrations/*users*`
- `backend/config/sanctum.php`, `backend/config/cors.php`
- `backend/routes/api.php`
- `backend/database/seeders/AdminUserSeeder.php`
- `frontend/src/app/(auth)/login/page.tsx`
- `frontend/src/features/auth/*`
- `frontend/src/lib/api/client.ts`
- `frontend/src/middleware.ts`

**Critérios de aceitação:**
- Login com credenciais válidas cria sessão e retorna o usuário.
- Login inválido retorna `422`/`401` sem revelar se o e-mail existe.
- Rotas protegidas retornam `401` sem sessão.
- Logout invalida a sessão e o cookie.
- CSRF validado em requisições de escrita.
- Senhas armazenadas com hash e nunca retornadas pela API.
- Usuário inativo não consegue autenticar.
- Frontend redireciona corretamente e mantém sessão entre recarregamentos.

**Testes necessários:**
- Feature: login sucesso, login inválido, throttling, logout, `me`.
- Feature: acesso não autenticado, usuário inativo, reset de senha.
- Unit/Feature: regras de perfil e gestão de usuários.
- Frontend: teste do formulário de login e da guarda de rota (se adotado).

---

### Entrega 2 — Perfis e permissões (RBAC)

**Objetivo:** implementar autorização baseada em papéis e permissões.

**Funcionalidades:**
- Instalação e configuração do Spatie Laravel Permission.
- Seeders idempotentes de permissões e papéis (`admin`, `operator`,
  `auditor`, `viewer`).
- Atribuição e remoção de papéis de usuários.
- Endpoints de listagem de papéis e permissões.
- Policies por módulo e middleware de permissão.
- Interface de gestão de papéis e permissões.
- Auditoria de alterações de acesso (gancho para a Entrega 7).

**Arquivos/componentes:**
- `backend/app/Modules/Access/*`
- `backend/database/migrations/*permission*`
- `backend/config/permission.php`
- `backend/app/Modules/*/Policies/*`
- `backend/app/Providers/AuthServiceProvider.php`
- `frontend/src/features/access/*` (se houver UI)
- `frontend/src/lib/auth/permissions.ts`

**Critérios de aceitação:**
- `admin` acessa todos os recursos.
- `viewer` recebe `403` em operações de escrita.
- Permissões são verificadas no backend, não apenas na UI.
- Cache de permissões é limpo após alterações.
- Seeders podem ser executados repetidamente sem duplicar dados.
- Matriz de permissões documentada em `docs/architecture`.

**Testes necessários:**
- Unit: policies e regras de autorização.
- Feature: cada papel contra operações críticas (200/403).
- Feature: atribuição/remoção de papéis.
- Arch: módulos não burlam policies diretamente.

---

### Entrega 3 — Datacenters e ambientes

**Objetivo:** cadastrar e gerenciar datacenters e seus ambientes.

**Funcionalidades:**
- CRUD de datacenters.
- CRUD de ambientes vinculados a datacenters.
- Filtros por status, cidade e tipo de ambiente.
- Paginação e busca.
- Bloqueio de exclusão com dependências.
- Telas de listagem, detalhe e formulário.

**Arquivos/componentes:**
- `backend/app/Modules/Datacenter/Models/Datacenter.php`
- `backend/app/Modules/Datacenter/Models/Environment.php`
- `backend/app/Modules/Datacenter/Actions/*`
- `backend/app/Modules/Datacenter/Http/*`
- `backend/app/Modules/Datacenter/Policies/*`
- `backend/app/Modules/Datacenter/Routes/api.php`
- `backend/database/migrations/*datacenters*`, `*environments*`
- `backend/database/factories/DatacenterFactory.php`, `EnvironmentFactory.php`
- `frontend/src/features/datacenters/*`
- `frontend/src/app/(dashboard)/datacenters/*`

**Critérios de aceitação:**
- CRUD completo com validação e mensagens claras.
- `code` único por escopo definido.
- Não é possível excluir datacenter com ambientes ativos.
- Listagens paginadas e filtráveis.
- Ações respeitam permissões.
- Respostas seguem o contrato da API.

**Testes necessários:**
- Feature: criar, listar, atualizar e excluir.
- Feature: validação de campos obrigatórios e unicidade.
- Feature: autorização por papel.
- Feature: bloqueio de exclusão com dependências.
- Unit: regras de status e tipos de ambiente.

---

### Entrega 4 — Racks

**Objetivo:** gerenciar racks e sua capacidade física dentro dos ambientes.

**Funcionalidades:**
- CRUD de racks vinculados a ambientes.
- Controle de unidades (U), posição, fileira e capacidade de energia.
- Cálculo de ocupação e unidades livres.
- Filtros por ambiente e status.
- Bloqueio de exclusão com ativos alocados.
- Telas de listagem, detalhe e formulário.

**Arquivos/componentes:**
- `backend/app/Modules/Rack/Models/Rack.php`
- `backend/app/Modules/Rack/Actions/*`
- `backend/app/Modules/Rack/Http/*`
- `backend/app/Modules/Rack/Policies/*`
- `backend/database/migrations/*racks*`
- `backend/database/factories/RackFactory.php`
- `frontend/src/features/racks/*`
- `frontend/src/app/(dashboard)/racks/*`

**Critérios de aceitação:**
- `code` único por ambiente.
- `total_units` maior que zero e respeitado.
- Ocupação calculada corretamente a partir dos ativos.
- Exclusão bloqueada quando houver ativos.
- Ações respeitam permissões.
- Listagens paginadas e filtráveis.

**Testes necessários:**
- Feature: CRUD e validações.
- Unit: cálculo de ocupação e unidades livres.
- Feature: bloqueio de exclusão e autorização.
- Feature: filtros e paginação.

---

### Entrega 5 — Ativos de infraestrutura

**Objetivo:** cadastrar ativos, tipos e alocação em racks.

**Funcionalidades:**
- CRUD de tipos de ativo.
- CRUD de ativos com tag, serial, fabricante, modelo e status.
- Alocação em rack com posição e tamanho em U.
- Validação de sobreposição e capacidade.
- Consistência entre ambiente do ativo e ambiente do rack.
- Busca por tag, serial, nome e IP.
- Histórico de status (preparação para auditoria).
- Telas de listagem, detalhe e formulário.

**Arquivos/componentes:**
- `backend/app/Modules/Asset/Models/Asset.php`
- `backend/app/Modules/Asset/Models/AssetType.php`
- `backend/app/Modules/Asset/Enums/*`
- `backend/app/Modules/Asset/Actions/*`
- `backend/app/Modules/Asset/Http/*`
- `backend/app/Modules/Asset/Policies/*`
- `backend/database/migrations/*asset_types*`, `*assets*`
- `backend/database/factories/AssetFactory.php`, `AssetTypeFactory.php`
- `frontend/src/features/assets/*`
- `frontend/src/app/(dashboard)/assets/*`

**Critérios de aceitação:**
- `asset_tag` único; `serial_number` único quando informado.
- Alocação não ultrapassa a capacidade do rack.
- Não há sobreposição de unidades no mesmo rack.
- Ambiente do ativo é compatível com o do rack.
- Desalocação libera as unidades corretamente.
- Exclusão usa soft delete e respeita permissões.
- Busca e filtros funcionam com paginação.

**Testes necessários:**
- Feature: CRUD de ativos e tipos.
- Unit: validação de posição, tamanho e sobreposição.
- Feature: conflitos de alocação e capacidade excedida.
- Feature: unicidade e consistência de ambiente.
- Feature: autorização e soft delete.

---

### Entrega 6 — Serviços e aplicações

**Objetivo:** mapear serviços/aplicações e suas dependências de ativos.

**Funcionalidades:**
- CRUD de serviços com criticidade, status, responsável e ambiente.
- Vínculo N:N entre serviços e ativos.
- Filtros por criticidade, ambiente e status.
- Visualização de ativos associados.
- Bloqueio de exclusão com vínculos ou regra explícita de desvinculação.

**Arquivos/componentes:**
- `backend/app/Modules/Service/Models/Service.php`
- `backend/app/Modules/Service/Actions/*`
- `backend/app/Modules/Service/Http/*`
- `backend/app/Modules/Service/Policies/*`
- `backend/database/migrations/*services*`, `*service_asset*`
- `backend/database/factories/ServiceFactory.php`
- `frontend/src/features/services/*`
- `frontend/src/app/(dashboard)/services/*`

**Critérios de aceitação:**
- CRUD completo com validação.
- Vínculo e desvínculo de ativos funcionam e são auditáveis.
- Serviço pertence a um ambiente válido.
- Responsável é um usuário ativo.
- Filtros por criticidade e status funcionam.
- Ações respeitam permissões.

**Testes necessários:**
- Feature: CRUD e validações.
- Feature: vínculo/desvínculo N:N.
- Feature: autorização e filtros.
- Unit: regras de criticidade e status.

---

### Entrega 7 — Auditoria

**Objetivo:** registrar e consultar alterações relevantes do sistema.

**Funcionalidades:**
- Tabela `audit_logs` append-only.
- Observer/listener para eventos `created`, `updated` e `deleted`.
- Registro de usuário, IP, user agent, valores antigos e novos.
- Redaction de campos sensíveis (senhas, tokens).
- Endpoint de consulta com filtros por entidade, usuário, evento e período.
- Tela de auditoria com paginação.
- Comando de retenção/limpeza com política configurável.

**Arquivos/componentes:**
- `backend/app/Modules/Audit/Models/AuditLog.php`
- `backend/app/Modules/Audit/Observers/*`
- `backend/app/Modules/Audit/Listeners/*`
- `backend/app/Modules/Audit/Http/*`
- `backend/app/Modules/Audit/Console/PruneAuditLogs.php`
- `backend/database/migrations/*audit_logs*`
- `frontend/src/features/audit/*`
- `frontend/src/app/(dashboard)/audit/*`

**Critérios de aceitação:**
- Criação, atualização e exclusão geram registros corretos.
- Dados sensíveis nunca aparecem nos logs.
- Logs não podem ser alterados ou excluídos pela API.
- Filtros e paginação funcionam.
- Apenas `admin` e `auditor` acessam.
- Política de retenção documentada e testada.

**Testes necessários:**
- Feature: eventos registrados com valores corretos.
- Feature: redaction de campos sensíveis.
- Feature: autorização e filtros.
- Unit: comando de retenção.

---

### Entrega 8 — Dashboard

**Objetivo:** fornecer visão consolidada da infraestrutura.

**Funcionalidades:**
- Totais de datacenters, ambientes, racks, ativos e serviços.
- Ocupação de racks e capacidade livre.
- Ativos por tipo e status.
- Serviços por criticidade e status.
- Últimas alterações de auditoria.
- Filtros por ambiente/datacenter.
- Cache curto com Redis, com invalidação em alterações relevantes.

**Arquivos/componentes:**
- `backend/app/Modules/Dashboard/Http/Controllers/*`
- `backend/app/Modules/Dashboard/Actions/*`
- `backend/app/Modules/Dashboard/Routes/api.php`
- `frontend/src/features/dashboard/*`
- `frontend/src/app/(dashboard)/page.tsx`
- `frontend/src/components/ui/cards/*`, `charts/*`

**Critérios de aceitação:**
- Indicadores corretos em relação aos dados cadastrados.
- Respostas em tempo aceitável com volume de seed de referência.
- Cache não entrega dados desatualizados após alterações críticas.
- Acesso respeita permissões.
- Layout responsivo e com estados de carregamento/erro.

**Testes necessários:**
- Feature: agregações e filtros.
- Unit: cálculos de ocupação e totais.
- Feature: autorização.
- Teste de performance básico com dados de seed.

---

### Entrega 9 — Hardening, CI/CD e entrega

**Objetivo:** preparar a aplicação para produção e finalizar a documentação.

**Funcionalidades:**
- Dockerfiles multi-stage para produção, usuário não-root.
- Pipeline completa de CI: lint, testes, build de imagens.
- Análise de dependências e varredura de vulnerabilidades.
- Configuração de logs estruturados e healthchecks.
- Documentação OpenAPI e README completo.
- Seed de demonstração para portfólio.
- ADRs registrando decisões arquiteturais.
- Checklist de segurança e LGPD.

**Arquivos/componentes:**
- `docker/php/Dockerfile` (estágio produção)
- `docker/node/Dockerfile` (estágio produção)
- `compose.prod.yaml`
- `.github/workflows/*.yml`
- `docs/architecture/adr-*.md`
- `docs/api/openapi.yaml` (ou geração)
- `README.md`

**Critérios de aceitação:**
- Pipeline verde em `main`.
- Imagens de produção constroem e sobem sem dev dependencies.
- Aplicação responde com headers de segurança e sem dados sensíveis.
- Documentação permite que outra pessoa rode o projeto do zero.
- Nenhuma vulnerabilidade crítica conhecida nas dependências.
- Fluxos críticos cobertos por testes.

**Testes necessários:**
- Suíte completa backend e frontend.
- Testes E2E dos fluxos de login, cadastro de ativo e consulta de auditoria.
- Smoke test das imagens de produção.
- Verificação de headers e cookies.

---

## 6. Possíveis riscos e decisões arquiteturais

### 6.1 Decisões arquiteturais (ADRs resumidos)

| ID | Decisão | Justificativa | Consequências |
| --- | --- | --- | --- |
| ADR-001 | Monólito modular em `app/Modules` sem pacote de módulos | Menos dependências, controle total, convenções Laravel | Disciplina manual para manter limites |
| ADR-002 | Docker Compose como ambiente oficial | Host sem PHP/Composer/Redis | Curva inicial de Docker; ambiente reproduzível |
| ADR-003 | Sanctum com cookie de sessão para SPA | Mais seguro contra XSS, revogação central | Requer CORS/CSRF bem configurados |
| ADR-004 | PostgreSQL como banco único | Requisito e recursos avançados (`jsonb`, constraints) | Operação de banco relacional |
| ADR-005 | ULID nas entidades de domínio | IDs não enumeráveis e ordenáveis | Chaves maiores que inteiros |
| ADR-006 | API versionada em `/api/v1` | Evolução sem quebrar clientes | Manutenção de compatibilidade |
| ADR-007 | Sem repositories por padrão | Evitar abstração desnecessária | Acoplamento ao Eloquent aceito |
| ADR-008 | Auditoria própria com observers | Controle de schema e redaction | Mais código a manter |
| ADR-009 | RBAC sem `teams` inicialmente | Simplicidade; multi-tenant não é requisito | Migração futura pode exigir ajustes |
| ADR-010 | Frontend sem biblioteca pesada de UI/estado | Menos dependências, mais controle | Mais tempo em componentes base |

### 6.2 Riscos técnicos

| Risco | Probabilidade | Impacto | Mitigação |
| --- | --- | --- | --- |
| Incompatibilidade Laravel 13 + PHP 8.5 | Média | Alto | Validar constraints no bootstrap; fallback para versão estável |
| Configuração incorreta de CORS/CSRF no Sanctum | Média | Alto | Testes de integração reais com cookie; checklist de segurança |
| Modelagem de alocação de ativos gerar inconsistências | Média | Alto | Transações, validações e testes de concorrência |
| Crescimento excessivo da auditoria | Média | Médio | Índices, retenção configurável, partição futura |
| Acoplamento entre módulos | Média | Médio | Testes de arquitetura e revisão de PR |
| Dashboard lento com volume alto | Baixa/Média | Médio | Índices, cache Redis e agregações otimizadas |
| Divergência de contrato entre frontend e backend | Média | Médio | OpenAPI, tipos compartilhados e testes de contrato |
| Perda de dados em migrações | Baixa | Alto | Backup antes de migrar, migrações reversíveis |
| Exposição de segredos | Baixa | Alto | `.env` fora do Git, secrets no CI, revisão de PR |
| Complexidade excessiva do monólito modular | Média | Médio | Entregas pequenas e revisão de abstrações |

### 6.3 Riscos de processo

| Risco | Mitigação |
| --- | --- |
| Escopo crescer além dos 8 módulos | Congelar escopo por entrega e registrar mudanças |
| Falta de testes em módulos de CRUD | Checklist de testes por entrega |
| Ambiente local divergir do CI | Usar as mesmas imagens e serviços no CI |
| Documentação ficar desatualizada | Atualizar docs no mesmo PR da mudança |
| Dependências vulneráveis | Dependabot e varredura no CI |

### 6.4 Segurança e conformidade

- HTTPS obrigatório em produção; HSTS.
- Cookies `HttpOnly`, `Secure`, `SameSite=Lax`.
- CORS com origem explícita e `credentials`.
- Rate limiting em autenticação e endpoints sensíveis.
- Validação de entrada com Form Requests e `zod`.
- Autorização em todas as rotas e policies.
- Senhas com `bcrypt`/`argon2id`; nunca logadas.
- Princípio do menor privilégio no usuário do banco.
- Backups automáticos do PostgreSQL e teste de restauração.
- Auditoria com retenção definida e redaction de dados pessoais.
- Revisão de dependências e varredura de vulnerabilidades no CI.

---

## 7. Próximos passos

1. Aprovar este plano e as decisões arquiteturais.
2. Confirmar a versão exata de Laravel 13 e sua compatibilidade com PHP 8.5.
3. Confirmar as versões de PostgreSQL (18) e Redis (7) para desenvolvimento.
4. Definir domínio/subdomínio do frontend e backend para Sanctum/CORS.
5. Iniciar a Entrega 0 somente após aprovação explícita.

> Nenhuma implementação, instalação ou commit será realizada sem autorização.
