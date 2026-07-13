.PHONY: clean commit push github combine serve \
        electron-install electron-build-win electron-build-linux electron-build \
        tauri-install tauri-build tauri-build-win tauri-build-linux \
        build-all

SCHEMA ?= data/sql/Tablas8.sql

combine:
	{ \
	  echo "=== index.html ===" && cat frontend/index.html && \
	  echo "" && echo "=== schema-config.js ===" && cat frontend/schema-config.js && \
	  echo "" && echo "=== ruta-procesos-data.js ===" && cat frontend/ruta-procesos-data.js && \
	  echo "" && echo "=== styles.css ===" && cat frontend/vendor/styles.css && \
	  echo "" && echo "=== app.go ===" && cat app.go && \
	  echo "" && echo "=== main.go ===" && cat main.go && \
	  echo "" && echo "=== Tablas8.sql ===" && cat $(SCHEMA) && \
	  echo "" && echo "=== wails.json ===" && cat wails.json && \
	  echo "" && echo "=== go.mod ===" && cat go.mod && \
	  echo "" && echo "=== doc.md ===" && cat docs/doc.md && \
	  echo "" && echo "=== decisiones.md ===" && cat docs/decisiones.md && \
	  echo "" && echo "=== ai-context.md ===" && cat docs/ai-context.md && \
	  echo "" && echo "=== funciones.md ===" && cat docs/funciones.md; \
	} > combined.txt
	@echo "combined.txt generado (schema: $(SCHEMA))"

clean:
	rm -f combined.txt

serve:
	@echo "Abriendo http://localhost:8000/frontend/index.html"
	@lsof -ti:8000 | xargs kill -9 2>/dev/null; sleep 0.5
	python3 -m http.server 8000 --directory .

# --- Electron ---
electron-install:
	npm install --save-dev --no-bin-links electron@latest electron-builder@latest

electron-build-win:
	npm run build

electron-build-win-termux:
	node node_modules/electron-builder/cli.js --win dir --x64

electron-build-linux:
	npm run build:linux

electron-build: electron-build-linux

# --- Tauri ---
tauri-install:
	npm install --save-dev --no-bin-links @tauri-apps/cli@latest

tauri-build-win:
	npx tauri build --bundles nsis

tauri-build-linux:
	npx tauri build --bundles appimage

tauri-build: tauri-build-win

# --- Wails ---
wails-install:
	go install github.com/wailsapp/wails/v2/cmd/wails@latest

wails-build-linux:
	wails build -platform linux/amd64 -tags webkit2_41 -debug

wails-build-linux-prod:
	wails build -platform linux/amd64 -tags webkit2_41

wails-build-win:
	wails build -platform windows/amd64 -webview2 embed

wails-build: wails-build-linux

wails-dev:
	wails dev

# --- Ambos ---
build-all: electron-build-win tauri-build-win wails-build-win

# --- Git ---
commit:
	git add -A
	git commit -m "$(msg)"

push:
	git push

github: commit push
