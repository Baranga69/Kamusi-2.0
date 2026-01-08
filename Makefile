.PHONY: up api admin mobile dev

up:
	docker compose up -d postgres

api:
	cd apps/api && poetry install && poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

admin:
	pnpm --filter @kamusi/admin dev

mobile:
	cd apps/mobile && flutter pub get && flutter run

dev:
	./scripts/dev.sh

