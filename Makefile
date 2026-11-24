# ==============================================================================
# Lipi Programming Language — Root Makefile
# Self-hosted native toolchain build, bootstrap, test, and packaging targets
# ==============================================================================

SHELL := /bin/bash
.PHONY: all bootstrap build test clean install uninstall update release unikernel

all: bootstrap build

# Bootstrap Stage-3 Modular Compiler from canonical genesis seed
bootstrap:
	@mkdir -p bin dist
	@if [ ! -x bin/lipc ]; then \
		echo "🌱 Bootstrapping Stage-3 Compiler from genesis seed..."; \
		chmod +x src/boot/lipi-seed 2>/dev/null || true; \
		if [ -f src/boot/lipi-seed ]; then \
			./src/boot/lipi-seed src/compiler/driver_cli.lp bin/lipc_stage1 && \
			chmod +x bin/lipc_stage1 && \
			./bin/lipc_stage1 src/compiler/driver_cli.lp bin/lipc && \
			chmod +x bin/lipc && \
			cp -f bin/lipc bin/lipc_bin && \
			cp -f bin/lipc bin/lipc_micro && \
			chmod +x bin/lipc_bin bin/lipc_micro && \
			rm -f bin/lipc_stage1; \
		elif [ -f src/boot/seed.b64 ]; then \
			(base64 -d src/boot/seed.b64 > bin/lipc_seed 2>/dev/null || \
			 base64 --decode src/boot/seed.b64 > bin/lipc_seed 2>/dev/null || \
			 base64 -D src/boot/seed.b64 > bin/lipc_seed 2>/dev/null) && \
			chmod +x bin/lipc_seed && \
			./bin/lipc_seed src/compiler/driver_cli.lp bin/lipc && \
			chmod +x bin/lipc && \
			cp -f bin/lipc bin/lipc_bin && \
			cp -f bin/lipc bin/lipc_micro && \
			chmod +x bin/lipc_bin bin/lipc_micro && \
			rm -f bin/lipc_seed; \
		fi; \
		echo "✔ Compiler bootstrapped: bin/lipc"; \
	fi

# Build sovereign developer toolchain using native compiler
build: bootstrap
	@echo "🔨 Building core developer toolchain..."
	@mkdir -p dist dist/vscode
	@if [ -d editors/vscode ] && command -v zip >/dev/null 2>&1; then \
		rm -rf /tmp/lipi_vsix_stage dist/lipi-language-1.0.1.vsix dist/vscode/lipi-language-1.0.1.vsix && \
		mkdir -p /tmp/lipi_vsix_stage/extension && \
		cp -a editors/vscode/. /tmp/lipi_vsix_stage/extension/ && \
		printf '%s\n' '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".vsixmanifest" ContentType="text/xml"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".ts" ContentType="text/plain"/><Default Extension=".md" ContentType="text/markdown"/><Default Extension=".png" ContentType="image/png"/><Default Extension=".svg" ContentType="image/svg+xml"/><Default Extension=".woff" ContentType="font/woff"/></Types>' > '/tmp/lipi_vsix_stage/[Content_Types].xml' && \
		printf '%s\n' '<?xml version="1.0" encoding="utf-8"?><PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011"><Metadata><Identity Language="en-US" Id="lipi-language" Version="1.0.1" Publisher="lipi-lang"/><DisplayName>Lipi Programming Language</DisplayName><Description xml:space="preserve">Language support for Lipi (bilingual English &amp; Bengali native systems language)</Description><Tags>lipi,bengali,compiler</Tags><Categories>Programming Languages,Snippets</Categories><Icon>extension/icons/icon.png</Icon></Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/><Asset Type="Microsoft.VisualStudio.Services.Icons.Default" Path="extension/icons/icon.png" Addressable="true"/></Assets></PackageManifest>' > /tmp/lipi_vsix_stage/extension.vsixmanifest && \
		(cd /tmp/lipi_vsix_stage && zip -rq "$(CURDIR)/dist/lipi-language-1.0.1.vsix" '[Content_Types].xml' extension.vsixmanifest extension) && \
		cp -f dist/lipi-language-1.0.1.vsix dist/vscode/lipi-language-1.0.1.vsix && \
		rm -rf /tmp/lipi_vsix_stage; \
	fi
	@./bin/lipc src/tools/lipi.lp bin/lipi && chmod +x bin/lipi
	@./bin/lipc src/tools/aati.lp bin/aati && chmod +x bin/aati
	@cp -f bin/aati bin/haat && chmod +x bin/haat
	@cp -f bin/aati bin/lipipkg && chmod +x bin/lipipkg
	@./bin/lipc src/tools/lipilsp.lp bin/lipilsp && chmod +x bin/lipilsp
	@cp -f bin/lipilsp bin/lipils && chmod +x bin/lipils
	@./bin/lipc src/tools/lipidbg.lp bin/lipidbg && chmod +x bin/lipidbg
	@./bin/lipc src/tools/lipifmt.lp bin/lipifmt --kavach && chmod +x bin/lipifmt
	@./bin/lipc src/tools/lipiconvert.lp bin/lipiconvert && chmod +x bin/lipiconvert
	@./bin/lipc src/tools/lipidoc.lp bin/lipidoc --kavach && chmod +x bin/lipidoc
	@./bin/lipc src/tools/lipirepl.lp bin/lipirepl && chmod +x bin/lipirepl
	@./bin/lipc src/tools/lipiassimilate.lp bin/lipiassimilate && chmod +x bin/lipiassimilate
	@./bin/lipc src/tools/lipi_akhara.lp bin/lipi_akhara --kavach && chmod +x bin/lipi_akhara
	@./bin/lipc src/tools/lipi_unikernel_boot.lp bin/lipi_unikernel_boot && chmod +x bin/lipi_unikernel_boot
	@./bin/lipc build.lp bin/lipi-build && chmod +x bin/lipi-build
	@./bin/lipc tests/run_tests.lp bin/lipi-test && chmod +x bin/lipi-test
	@echo "Native Lipi developer toolchain built in bin/"

# Build bare-metal Multiboot2 unikernel image
unikernel: build
	@echo "Building Multiboot2 unikernel image..."
	@./bin/lipi_unikernel_boot
	@echo "Unikernel image ready at dist/lipi_kernel.bin"

# Build Windows PE32+ native release binaries
windows: build
	@echo "Building Windows PE32+ binaries..."
	@mkdir -p dist
	@./bin/lipc src/compiler/driver_cli.lp dist/lipc.exe --target windows
	@./bin/lipc src/tools/lipi.lp dist/lipi.exe --target windows
	@./bin/lipc src/tools/aati.lp dist/aati.exe --target windows
	@zip -q -r dist/lipi-1.0.1-windows-x86_64.zip dist/*.exe install.ps1 README.md LICENSE utso/ aati/ examples/
	@echo "Windows PE32+ binaries and archive created in dist/"

# Package standalone pre-built release archive for Linux x86_64 and Windows
release: build unikernel windows
	@echo "Packaging standalone release distribution..."
	@mkdir -p dist
	@tar -czf dist/lipi-1.0.1-linux-x86_64.tar.gz bin/ utso/ aati/ examples/ install.sh LICENSE README.md
	@echo "Standalone release archive created: dist/lipi-1.0.1-linux-x86_64.tar.gz"

# Run full regression test suite (265 tests)
test: bootstrap
	@echo "Running regression test suite..."
	@if [ -x bin/lipi ]; then \
		./bin/lipi test; \
	elif [ -x bin/lipi-test ]; then \
		./bin/lipi-test; \
	else \
		./bin/lipc tests/run_tests.lp bin/lipi-test && ./bin/lipi-test; \
	fi

# Install toolchain into user's environment (~/.local/bin)
install:
	@./install.sh

# Update toolchain from GitHub repository
update:
	@echo "🔄 Updating LiPi repository from GitHub..."
	@git pull origin main
	@$(MAKE) build
	@echo "✔ LiPi updated and rebuilt successfully!"

# Uninstall toolchain from user's environment
uninstall:
	@./install.sh --uninstall

# Clean generated binaries and build artifacts
clean:
	@rm -rf bin/ dist/ build/ *.bin /tmp/lipi_tst_*
	@echo "🧹 Cleaned build artifacts."
