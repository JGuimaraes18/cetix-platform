.PHONY: up down build logs ps migrate key test lint typecheck

up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build
	docker compose exec frontend npm run build

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

migrate:
	docker compose exec backend php artisan migrate

key:
	docker compose exec backend php artisan key:generate

test:
	docker compose exec backend php artisan test
	docker compose exec frontend npm run test

typecheck:
	docker compose exec frontend npx tsc --noEmit

lint: typecheck
	docker compose exec backend vendor/bin/pint --test
	docker compose exec frontend npm run lint
