# ==============================================================================
# 👑 LIPI SOVEREIGN PROGRAMMING LANGUAGE — ROOT MAKEFILE
# ⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc | Sovereign Build Automation
# ==============================================================================

SHELL := /bin/bash
.PHONY: all bootstrap build test clean install uninstall update

all: bootstrap build

# Bootstrap Stage-3 Modular Compiler from canonical genesis seed
bootstrap:
	@mkdir -p bin dist
	@if [ ! -x bin/lipc ]; then \
		echo "🌱 Bootstrapping Stage-3 Compiler from genesis seed..."; \
		chmod +x src/boot/lipi-seed 2>/dev/null || true; \
		if [ -f src/boot/lipi-seed ]; then \
			./src/boot/lipi-seed src/compiler/driver_cli.lp bin/lipc_bin && \
			chmod +x bin/lipc_bin && \
			(printf '\000\000\000\000\001\000\000\000' | dd of=bin/lipc_bin bs=1 seek=202 count=8 conv=notrunc >/dev/null 2>&1 || true) && \
			cp -f bin/lipc_bin bin/lipc && \
			cp -f bin/lipc_bin bin/lipc_micro && \
			chmod +x bin/lipc bin/lipc_micro; \
		elif [ -f src/boot/seed.b64 ]; then \
			(base64 -d src/boot/seed.b64 > bin/lipc 2>/dev/null || \
			 base64 --decode src/boot/seed.b64 > bin/lipc 2>/dev/null || \
			 base64 -D src/boot/seed.b64 > bin/lipc 2>/dev/null) && \
			(printf '\000\000\000\000\001\000\000\000' | dd of=bin/lipc bs=1 seek=202 count=8 conv=notrunc >/dev/null 2>&1 || true) && \
			chmod +x bin/lipc && \
			cp -f bin/lipc bin/lipc_bin && \
			cp -f bin/lipc bin/lipc_micro && \
			chmod +x bin/lipc_bin bin/lipc_micro; \
		fi; \
		echo "✔ Compiler bootstrapped: bin/lipc"; \
	fi

# Build sovereign developer toolchain using native compiler
build: bootstrap
	@echo "🔨 Building core developer toolchain..."
	@mkdir -p dist
	@if [ -d editors/vscode ] && [ ! -f dist/lipi-language-1.0.0.vsix ] && command -v zip >/dev/null 2>&1; then \
		(cd editors/vscode && zip -rq ../../dist/lipi-language-1.0.0.vsix . >/dev/null 2>&1 || true); \
	fi
	@./bin/lipc src/tools/lipi.lp bin/lipi && chmod +x bin/lipi
	@./bin/lipc src/tools/lipipkg.lp bin/lipipkg && chmod +x bin/lipipkg
	@./bin/lipc src/tools/lipilsp.lp bin/lipilsp && chmod +x bin/lipilsp
	@./bin/lipc src/tools/lipidbg.lp bin/lipidbg && chmod +x bin/lipidbg
	@./bin/lipc src/tools/lipifmt.lp bin/lipifmt && chmod +x bin/lipifmt
	@./bin/lipc src/tools/lipiconvert.lp bin/lipiconvert && chmod +x bin/lipiconvert
	@./bin/lipc src/tools/lipidoc.lp bin/lipidoc && chmod +x bin/lipidoc
	@./bin/lipc src/tools/lipirepl.lp bin/lipirepl && chmod +x bin/lipirepl
	@./bin/lipc src/tools/lipiassimilate.lp bin/lipiassimilate && chmod +x bin/lipiassimilate
	@./bin/lipc build.lp bin/lipi-build && chmod +x bin/lipi-build
	@./bin/lipc tests/run_tests.lp bin/lipi-test && chmod +x bin/lipi-test
	@echo "👑 100% Native LiPi Developer Toolchain Ready!"

# Run autonomous 203 regression test suite
test: bootstrap
	@echo "🧪 Running full 203 regression test suite..."
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
