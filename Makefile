STOW_DIR := $(CURDIR)
AGENTS_TARGET := $(HOME)/.agents
CLAUDE_TARGET := $(HOME)/.claude
CODEX_TARGET := $(HOME)/.codex
AGENTS_SKILLS_TARGET := $(AGENTS_TARGET)/skills
CLAUDE_SKILLS_TARGET := $(CLAUDE_TARGET)/skills

.DEFAULT_GOAL := help
.PHONY: \
	link-skills unlink-skills relink-skills \
	link-agents-md unlink-agents-md relink-agents-md \
	link-all unlink-all relink-all \
	help

link-skills: ##@skills Link skills to agent discovery paths
	@mkdir -p $(AGENTS_SKILLS_TARGET) $(CLAUDE_SKILLS_TARGET)
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_SKILLS_TARGET) --stow skills
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_SKILLS_TARGET) --stow skills

unlink-skills: ##@skills Unlink skills from agent discovery paths
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_SKILLS_TARGET) --delete skills
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_SKILLS_TARGET) --delete skills

relink-skills: ##@skills Relink skills (update after changes)
	@mkdir -p $(AGENTS_SKILLS_TARGET) $(CLAUDE_SKILLS_TARGET)
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_SKILLS_TARGET) --restow skills
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_SKILLS_TARGET) --restow skills

link-agents-md: ##@agents Link agents markdown to agent discovery paths
	@mkdir -p $(AGENTS_TARGET) $(CLAUDE_TARGET) $(CODEX_TARGET)
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_TARGET) --stow agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_TARGET) --stow agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CODEX_TARGET) --stow agents-md

unlink-agents-md: ##@agents Unlink agents markdown from agent discovery paths
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_TARGET) --delete agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_TARGET) --delete agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CODEX_TARGET) --delete agents-md

relink-agents-md: ##@agents Relink agents markdown (update after changes)
	@mkdir -p $(AGENTS_TARGET) $(CLAUDE_TARGET) $(CODEX_TARGET)
	stow --verbose --dir=$(STOW_DIR) --target=$(AGENTS_TARGET) --restow agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CLAUDE_TARGET) --restow agents-md
	stow --verbose --dir=$(STOW_DIR) --target=$(CODEX_TARGET) --restow agents-md

link-all: link-skills ##@setup Link everything
	@make link-agents-md
unlink-all: unlink-skills ##@setup Unlink everything
	@make unlink-agents-md
relink-all: relink-skills ##@setup Relink everything (update after changes)
	@make relink-agents-md

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
