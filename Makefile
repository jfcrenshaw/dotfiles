# Makefile advice here: https://tech.davis-hansson.com/p/make/
SHELL := bash
ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# start the log file
$(info )
$(info Appending stdout to ./make.log)
$(info )
$(shell echo "" >> make.log)
$(shell echo "--------------------------------------------------------" >> make.log)
$(shell date >> make.log)
$(shell echo "--------------------------------------------------------" >> make.log)
$(shell echo "" >> make.log)

LOCAL_BIN := $$HOME/.local/bin
POETRY := $(LOCAL_BIN)/poetry

.PHONY: install dotfiles update uninstall

install: $(POETRY) dotfiles
	@echo ""
	@echo "Done installing! You must restart the terminal for changes to take effect." | tee -a make.log

# install poetry
# NOTE I NEED TO ADD POETRY CONFIG TO THE DOBOT FILES
# IN PARTICULAR, I NEED TO SET IT TO USE CONDA ENVS
$(POETRY):
	@if [ ! -f "$(POETRY)" ]; then\
		echo -e "- Installing Poetry..." | tee -a make.log;\
		echo "" >> make.log;\
		curl -sSL https://install.python-poetry.org | python3 - 2>&1 >> make.log | tee -a make.log;\
	else \
		echo "- Poetry already installed. To update, run 'make update'." | tee -a make.log;\
	fi;\

# install homebrew

# install mac apps via homebrew

# Run dotbot install script
dotfiles:
	@echo -e "- Running dotbot..." | tee -a make.log
	@echo "" >> make.log
	@./dotbot_install.sh 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log

# set MacOS settings

# update everything
update:
	@echo "- Updating Poetry..." | tee -a make.log
	@poetry self update 2>&1 >> make.log | tee -a make.log
	@poetry completions zsh > zsh/plugins/poetry/_poetry
	@echo "" >> make.log
	@echo "- Updating Submodules..." | tee -a make.log
	@git submodule update --init --remote 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log
	@echo -e "\nDone updating!" | tee -a make.log
	@echo "For changes to the git submodules to persist, you must commit the changes to the repo." | tee -a make.log
	@echo "Afterwards, you must restart the terminal for changes to take effect." | tee -a make.log

# uninstall everything
uninstall:
	@echo "- Uninstalling Poetry..." | tee -a make.log
	@curl -sSL https://install.python-poetry.org | python3 - --uninstall 2>&1 >> make.log | tee -a make.log
	@rm $(POETRY) 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log
	@echo "- Uninstalling dotfiles..." | tee -a make.log
	@./dotbot_uninstall.py 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log
	@echo "Done uninstalling! You must restart the terminal for changes to take effect." | tee -a make.log