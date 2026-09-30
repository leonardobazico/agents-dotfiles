SHARED_DIR  := $(CURDIR)/shared
HARNESS_DIR := $(CURDIR)/harnesses
HARNESS_STOW_IGNORE := --ignore='(^|/)(tests(/|$$)|run_tests\.sh$$)'

AGENTS_MD_TARGETS := $(HOME)/.agents $(HOME)/.claude $(HOME)/.codex
SKILLS_TARGETS    := $(HOME)/.agents/skills $(HOME)/.claude/skills

HARNESSES       := claude opencode codex
TARGET_claude   := $(HOME)/.claude
TARGET_opencode := $(HOME)/.config/opencode
TARGET_codex    := $(HOME)/.codex

.DEFAULT_GOAL := help
.PHONY: \
	link-skills unlink-skills relink-skills \
	link-agents-md unlink-agents-md relink-agents-md \
	link-harnesses unlink-harnesses relink-harnesses \
	link-all unlink-all relink-all \
	setup-rtk teardown-rtk \
	cache-tokenizers \
	help

link-skills: ##@skills Link skills to agent discovery paths
	@$(foreach t,$(SKILLS_TARGETS), \
		mkdir -p $(t) && \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --stow skills && ) true

unlink-skills: ##@skills Unlink skills from agent discovery paths
	@$(foreach t,$(SKILLS_TARGETS), \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --delete skills && ) true

relink-skills: ##@skills Relink skills (update after changes)
	@$(foreach t,$(SKILLS_TARGETS), \
		mkdir -p $(t) && \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --restow skills && ) true

link-agents-md: ##@agents Link agents markdown to agent discovery paths
	@$(foreach t,$(AGENTS_MD_TARGETS), \
		mkdir -p $(t) && \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --stow agents-md && ) true

unlink-agents-md: ##@agents Unlink agents markdown from agent discovery paths
	@$(foreach t,$(AGENTS_MD_TARGETS), \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --delete agents-md && ) true

relink-agents-md: ##@agents Relink agents markdown (update after changes)
	@$(foreach t,$(AGENTS_MD_TARGETS), \
		mkdir -p $(t) && \
		stow --verbose --dir=$(SHARED_DIR) --target=$(t) --restow agents-md && ) true

link-harnesses: ##@harness Link every per-harness config package
	@$(foreach h,$(HARNESSES), \
		mkdir -p $(TARGET_$(h)) && \
		$(CURDIR)/scripts/adopt-harness.sh $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && \
		stow --verbose --no-folding $(HARNESS_STOW_IGNORE) --dir=$(HARNESS_DIR) --target=$(TARGET_$(h)) --stow $(h) && ) true

unlink-harnesses: ##@harness Unlink every per-harness config package and restore backups
	@$(foreach h,$(HARNESSES), \
		stow --verbose $(HARNESS_STOW_IGNORE) --dir=$(HARNESS_DIR) --target=$(TARGET_$(h)) --delete $(h) && \
		$(CURDIR)/scripts/restore-harness.sh $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && ) true

relink-harnesses: ##@harness Relink every per-harness config package
	@$(foreach h,$(HARNESSES), \
		mkdir -p $(TARGET_$(h)) && \
		$(CURDIR)/scripts/adopt-harness.sh $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && \
		stow --verbose --no-folding $(HARNESS_STOW_IGNORE) --dir=$(HARNESS_DIR) --target=$(TARGET_$(h)) --restow $(h) && ) true

setup-rtk: ##@rtk Install rtk integrations and link the Codex hook
	$(CURDIR)/scripts/setup-rtk.sh
	@$(MAKE) link-harnesses HARNESSES=codex TARGET_codex="$(TARGET_codex)" || { \
		status=$$?; echo "setup-rtk: partial setup; rtk configured but Codex linking failed" >&2; exit $$status; }

teardown-rtk: ##@rtk Remove rtk integrations and restore adopted Codex files
	$(CURDIR)/scripts/setup-rtk.sh --uninstall
	@$(MAKE) unlink-harnesses HARNESSES=codex TARGET_codex="$(TARGET_codex)" || { \
		status=$$?; echo "setup-rtk: partial teardown; rtk removed but Codex unlinking failed" >&2; exit $$status; }

cache-tokenizers: ##@tokens Pre-download tokenizers used by the count-tokens skill
	$(SHARED_DIR)/skills/count-tokens/scripts/cache_tokenizers.py

link-all: link-skills ##@setup Link everything
	@$(MAKE) link-agents-md
	@$(MAKE) link-harnesses
unlink-all: unlink-skills ##@setup Unlink everything
	@$(MAKE) unlink-harnesses
	@$(MAKE) unlink-agents-md
relink-all: relink-skills ##@setup Relink everything (update after changes)
	@$(MAKE) relink-agents-md
	@$(MAKE) relink-harnesses

######################################################
################### help generator ###################
######################################################

#COLORS
GREEN  := $(shell tput -Txterm setaf 2)
WHITE  := $(shell tput -Txterm setaf 7)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

HELP_DOCS = \
	%help; \
	while(<>) { push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
	print "usage: make [target]\n\n"; \
	for (sort keys %help) { \
	print "${WHITE}$$_:${RESET}\n"; \
	for (@{$$help{$$_}}) { \
	$$sep = " " x (48 - length $$_->[0]); \
	print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
	}; \
	print "\n"; }

help: ##@other Show this help
	@perl -e '$(HELP_DOCS)' $(MAKEFILE_LIST)
