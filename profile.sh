# setup homebrew
if [ -e /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# path to local binaries
LOCAL_BIN="$HOME/.local/bin"
if [ -d "$LOCAL_BIN" ]; then
    export PATH="$LOCAL_BIN:$PATH"
fi

# cuda path
CUDA_PATH="/usr/local/cuda"
if [ -d "$CUDA_PATH" ]; then
    export LD_LIBRARY_PATH="$CUDA_PATH/lib64:$LD_LIBRARY_PATH"
    export PATH="$CUDA_PATH:$PATH"
fi

# if running a different shell, switch to zsh (if it exists)
if [ -z "$ZSH_VERSION" ]; then # if not running zsh
    if type zsh > /dev/null; then # check if zsh exists
        export SHELL=`which zsh` # set the shell to the zsh in path
        exec $SHELL # execute zsh
    fi
fi