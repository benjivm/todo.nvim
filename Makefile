NVIM ?= nvim
STYLUA ?= stylua
TESTS_DIR := .tests
MINI_DIR := $(TESTS_DIR)/mini.nvim

# Keep test runs away from the user's own Neovim state
export XDG_CONFIG_HOME := $(CURDIR)/$(TESTS_DIR)/xdg/config
export XDG_DATA_HOME := $(CURDIR)/$(TESTS_DIR)/xdg/data
export XDG_STATE_HOME := $(CURDIR)/$(TESTS_DIR)/xdg/state
export XDG_CACHE_HOME := $(CURDIR)/$(TESTS_DIR)/xdg/cache

.PHONY: test lint format deps

test: deps
	$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "lua MiniTest.run()"

lint:
	$(STYLUA) --check lua plugin tests

format:
	$(STYLUA) lua plugin tests

deps: $(MINI_DIR)

$(MINI_DIR):
	git clone --depth 1 https://github.com/echasnovski/mini.nvim $(MINI_DIR)
