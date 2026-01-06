# Stellar Assault - NES Game Makefile

# Assembler
ASM = ./tools/asm6f/asm6f

# Source files
SRC = src/main.asm
ROM = build/stellar-assault.nes

# Test configuration
TEST_ROM_DIR = tests/test-roms
TEST_SCRIPT = tests/test.lua

.PHONY: all clean test lint

all: $(ROM)

$(ROM): $(SRC) src/*.asm src/*.inc
	@echo "Building Stellar Assault..."
	@mkdir -p build
	$(ASM) $(SRC) $(ROM)
	@echo "ROM built: $(ROM)"

run: $(ROM)
	@echo "Note: Mesen2 requires X11. Use 'make test' for headless validation."
	@echo "To run manually: mesen $(ROM)"

test: $(ROM)
	@echo "Running automated tests..."
	@echo "Tests will be implemented with Mesen2 headless mode"
	@echo "For now, verify ROM builds successfully"
	@ls -lh $(ROM)

lint:
	@echo "Linting assembly code..."
	@echo "lin6 linter will be added when available"

clean:
	rm -rf build/

help:
	@echo "Stellar Assault - NES Game Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make         - Build ROM"
	@echo "  make run     - Build and run (requires Mesen2 with X11)"
	@echo "  make test    - Run automated tests"
	@echo "  make lint    - Lint assembly code"
	@echo "  make clean   - Remove build artifacts"
