# Dotfile Repo

Repo that contains my dotfiles.
Note there used to be more complicated functionality that I removed.
At this point I could probably remove the makefile?
Deferring this for later though.

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

Note there are some json files in the jsons directory that are not programmatically placed anywhere.
These files are just saved here as a backup, but would need manual deployment.

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
