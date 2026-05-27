# Makefile for notifications.nvim
#
# Common targets:
#   make test          Run all tests (uses plenary.busted via tests/minimal_init.lua)
#   make test TESTS=... Run specific test file or directory
#   make lint          Run selene (if installed)
#
# The test runner will automatically clone plenary.nvim into /tmp if needed.

.PHONY: test lint help clean

NVIM ?= nvim

test:
	@echo "==> Running tests"
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua

# Run selene linter if available (configured in selene.toml)
lint:
	@if command -v selene >/dev/null 2>&1; then \
		echo "==> Running selene..."; \
		selene lua/ tests/; \
	else \
		echo "==> selene not found in PATH, skipping lint"; \
	fi

# Remove any temporary plenary clone (created by minimal_init.lua)
clean:
	@rm -rf /tmp/plenary.nvim
	@echo "Cleaned temporary test dependencies."

help:
	@echo "notifications.nvim development targets:"
	@echo ""
	@echo "  make test            Run all tests"
	@echo "  make lint            Run selene linter (if installed)"
	@echo "  make clean           Remove cached plenary clone from /tmp"
	@echo "  make help            Show this help"
	@echo ""
	@echo "Tests are discovered automatically (any *_spec.lua under tests/)."
