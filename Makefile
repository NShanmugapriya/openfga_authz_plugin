.PHONY: help start stop restart logs test lint clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

start: ## Start all services with Docker Compose
	docker-compose up -d
	@echo "Services starting..."
	@echo "OpenFGA: http://localhost:8080"
	@echo "APISIX Gateway: http://localhost:9080"
	@echo "APISIX Admin: http://localhost:9180"

stop: ## Stop all services
	docker-compose down

restart: stop start ## Restart all services

logs: ## Show logs from all services
	docker-compose logs -f

logs-apisix: ## Show APISIX logs only
	docker logs -f apisix

logs-openfga: ## Show OpenFGA logs only
	docker logs -f openfga

test: ## Run tests
	@echo "Running basic validation tests..."
	@docker-compose up -d
	@sleep 10
	@curl -f http://localhost:8080/healthz && echo "✓ OpenFGA is healthy"
	@curl -f http://localhost:9080 && echo "✓ APISIX is healthy"
	@docker-compose down

lint: ## Lint Lua code (requires luacheck)
	@if command -v luacheck >/dev/null 2>&1; then \
		luacheck apisix/plugins/*.lua --globals ngx --max-line-length 120; \
	else \
		echo "luacheck not found. Install with: luarocks install luacheck"; \
		exit 1; \
	fi

format: ## Format Lua code (requires lua-format)
	@if command -v lua-format >/dev/null 2>&1; then \
		find apisix/plugins -name "*.lua" -exec lua-format -i {} \;; \
	else \
		echo "lua-format not found. Install with: luarocks install --server=https://luarocks.org/dev luaformatter"; \
	fi

clean: ## Clean up containers and volumes
	docker-compose down -v
	@echo "Cleaned up Docker containers and volumes"

install: ## Install dependencies (luarocks)
	@echo "Installing development dependencies..."
	@if command -v luarocks >/dev/null 2>&1; then \
		luarocks install luacheck; \
		echo "✓ Installed luacheck"; \
	else \
		echo "luarocks not found. Please install LuaRocks first."; \
	fi

setup-openfga: ## Set up OpenFGA with example store and model
	@echo "Setting up OpenFGA..."
	@bash scripts/setup-openfga.sh

validate-plugin: ## Validate plugin syntax
	@lua -e "dofile('apisix/plugins/openfga-authz.lua')" && echo "✓ Plugin syntax is valid"

check-requirements: ## Check if required tools are installed
	@echo "Checking requirements..."
	@command -v docker >/dev/null 2>&1 || { echo "✗ Docker is not installed"; exit 1; }
	@echo "✓ Docker is installed"
	@command -v docker-compose >/dev/null 2>&1 || { echo "✗ Docker Compose is not installed"; exit 1; }
	@echo "✓ Docker Compose is installed"
	@command -v curl >/dev/null 2>&1 || { echo "✗ curl is not installed"; exit 1; }
	@echo "✓ curl is installed"
	@echo "All requirements met!"

dev: start logs ## Start services and follow logs

.DEFAULT_GOAL := help
