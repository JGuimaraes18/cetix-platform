.PHONY: up down build logs ps migrate key test lint

up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build

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

lint:
	docker compose exec backend vendor/bin/pint --test
	docker compose exec frontend npm run lint
