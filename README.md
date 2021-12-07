# Dotfile Repo

## Done so far

- setup zshell using oh-my-zsh, powerlevel10k, and associated plugins/themes
- setup zprofile to source profile.sh
- setup profile to add homebrew, local binaries, and cuda to the path
- setup profile to run zsh if not currently running

## Need to do

- ssh config
- gitconfig
- switch all mac apps to homebrew installs
- include configs for all of these installs in this repo
- figure out how to include mac os settings in this repo. Maybe look at [this repo](https://github.com/denolfe/dotfiles/tree/master/macos).
- test that all of this actually works!
- write a step-by-step guide of how to actually do all of this

### Notes

To upgrade submodules to their latest versions, run
`git submodule update --init --remote`.

This repo depends on [Dotbot][dotbot] and was created from the Dotbot [template repo][template].

[dotbot]: https://github.com/anishathalye/dotbot
[template]: https://github.com/anishathalye/dotfiles_template/