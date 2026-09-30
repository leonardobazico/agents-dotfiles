SHARED_DIR  := $(CURDIR)/shared
HARNESS_DIR := $(CURDIR)/harnesses

AGENTS_MD_TARGETS := $(HOME)/.agents $(HOME)/.claude $(HOME)/.codex
SKILLS_TARGETS    := $(HOME)/.agents/skills $(HOME)/.claude/skills

HARNESSES       := claude opencode
TARGET_claude   := $(HOME)/.claude
TARGET_opencode := $(HOME)/.config/opencode

TOOLS_DIR        := $(CURDIR)/tools
TOOLS            := rtk
TOOL_TARGETS_rtk := codex
TARGET_rtk_codex := $(HOME)/.codex

STOW_PACKAGE         := $(CURDIR)/scripts/stow-package.sh
INSTALL_DEPENDENCIES := $(CURDIR)/scripts/install-dependencies.sh

# Each tool stows once per harness it targets. Flattening the two axes into
# <tool>/<harness> pairs lets one foreach drive every tool recipe, and names the
# pair so $(subst /,_,...) reaches its TARGET_<tool>_<harness> variable.
TOOL_PAIRS = $(foreach t,$(TOOLS),$(if $(TOOL_TARGETS_$(t)),,$(error no TOOL_TARGETS_$(t) declared for tool '$(t)'))$(foreach h,$(TOOL_TARGETS_$(t)),$(t)/$(h)))

.DEFAULT_GOAL := help
.PHONY: \
	link-skills unlink-skills relink-skills \
	link-agents-md unlink-agents-md relink-agents-md \
	link-harnesses unlink-harnesses relink-harnesses \
	link-tools unlink-tools relink-tools \
	link-all unlink-all relink-all \
	setup-rtk teardown-rtk \
	install-dependencies \
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
	@$(foreach h,$(HARNESSES), $(STOW_PACKAGE) link $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && ) true

unlink-harnesses: ##@harness Unlink every per-harness config package and restore backups
	@$(foreach h,$(HARNESSES), $(STOW_PACKAGE) unlink $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && ) true

relink-harnesses: ##@harness Relink every per-harness config package
	@$(foreach h,$(HARNESSES), $(STOW_PACKAGE) relink $(HARNESS_DIR)/$(h) $(TARGET_$(h)) && ) true

link-tools: ##@tools Link every tool package to its harness targets
	@$(foreach p,$(TOOL_PAIRS), $(STOW_PACKAGE) link $(TOOLS_DIR)/$(p) $(TARGET_$(subst /,_,$(p))) && ) true

unlink-tools: ##@tools Unlink every tool package and restore backups
	@$(foreach p,$(TOOL_PAIRS), $(STOW_PACKAGE) unlink $(TOOLS_DIR)/$(p) $(TARGET_$(subst /,_,$(p))) && ) true

relink-tools: ##@tools Relink every tool package (update after changes)
	@$(foreach p,$(TOOL_PAIRS), $(STOW_PACKAGE) relink $(TOOLS_DIR)/$(p) $(TARGET_$(subst /,_,$(p))) && ) true

setup-rtk: ##@rtk Install rtk integrations and link its tool package
	$(TOOLS_DIR)/rtk/setup-rtk.sh
	@$(MAKE) link-tools TOOLS=rtk TARGET_rtk_codex="$(TARGET_rtk_codex)" || { \
		status=$$?; echo "setup-rtk: partial setup; rtk configured but tool linking failed" >&2; exit $$status; }

teardown-rtk: ##@rtk Remove rtk integrations and restore adopted files
	$(TOOLS_DIR)/rtk/setup-rtk.sh --uninstall
	@$(MAKE) unlink-tools TOOLS=rtk TARGET_rtk_codex="$(TARGET_rtk_codex)" || { \
		status=$$?; echo "teardown-rtk: partial teardown; rtk removed but tool unlinking failed" >&2; exit $$status; }

install-dependencies: ##@setup Install harness CLIs and repo tooling via Homebrew
	$(INSTALL_DEPENDENCIES)

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
