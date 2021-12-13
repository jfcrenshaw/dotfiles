# Dotfile Repo

Repo that contains my dotfiles and scripts to setup my computer the way I like it.

## Installation

Prerequisites: git, zsh

Run the following commands:
```zsh
cd $HOME
git clone git@github.com:jfcrenshaw/dotfiles.git .dotfiles
cd .dotfiles
make install
```

then restart the terminal for changes to take effect.

## Updating

If you have changed your dotfiles and would like to use dotbot to update them across your system, just run `make dotfiles`.

If you would like to update all of the software, first make sure that your repo is clean and up to date with the remote, then run `make update`.

Note that if `make update` updated any of the git submodules, you will also have to commit those changes: `git commit -am "Updated submodules."`

At the end, restart the terminal for changes to take effect.

## Uninstalling

If you have already installed and would like to uninstall run `make uninstall`, then restart the terminal for changes to take effect. Note this will remove all of the dotfiles from your system, as well as uninstall all of the software installed by `make install`.

If you only want to uninstall certain pieces, you should look in the Makefile for the relevant bash commands. Or you could google how to uninstall the relevant pieces.

If you have uninstalled everything, you can optionally delete the dotfiles directory altogether:
```zsh
cd $HOME
rm -rf .dotfiles 
```

## Notes

### Done

- setup zshell using oh-my-zsh, powerlevel10k, and associated plugins/themes
- setup zprofile to source `profile.sh`
- setup profile to add homebrew, local binaries, and cuda to the path
- setup profile to run zsh if not currently running
- automated poetry install
- created update and uninstall scripts
- gitconfig

## To do

- poetry config
- ssh config
- switch all mac apps to homebrew installs
- include configs for all of these installs in this repo
- figure out how to include mac os settings in this repo. Maybe look at [this repo](https://github.com/denolfe/dotfiles/tree/master/macos).

I previously added pyenv to the install script so that I could controll python versioning with it. I like this workflow, but I couldn't get pyenv to work on Baldur/Epyc, because they don't have all the devtools installed that are required to compile python. I might try to get something like that working later, or at least have it set up on my laptop. However, for now I will use conda for managing python versions in different environments.