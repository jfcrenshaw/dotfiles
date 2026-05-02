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

.PHONY: install dotfiles update uninstall

install: dotfiles
	@echo ""
	@echo "Done installing! You must restart the terminal for changes to take effect." | tee -a make.log

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
	@echo "- Updating Submodules..." | tee -a make.log
	@git submodule update --init --remote 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log
	@echo -e "\nDone updating!" | tee -a make.log
	@echo "For changes to the git submodules to persist, you must commit the changes to the repo." | tee -a make.log
	@echo "Afterwards, you must restart the terminal for changes to take effect." | tee -a make.log

# uninstall everything
uninstall:
	@echo "- Uninstalling dotfiles..." | tee -a make.log
	@./dotbot_uninstall.py 2>&1 >> make.log | tee -a make.log
	@echo "" >> make.log
	@echo "Done uninstalling! You must restart the terminal for changes to take effect." | tee -a make.log