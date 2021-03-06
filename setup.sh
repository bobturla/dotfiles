#!/bin/bash
# setup.sh
# sets up dotfiles.sh to auto-load with the terminal
# TODO: better description


# Install packages
packages="$(cat ~/dotfiles/packages.txt)"
if apt-cache policy $packages | grep 'Installed: (none)' > /dev/null
then
    echo "Installing:"
    echo "$packages"
    sudo apt-get update
    sudo apt-get install -y $packages
fi

# Configure Git
if [ -z "$(git config --global user.name)" ]
then
    echo -n "Git user name (The name to appear on your commits): "
    read git_user_name
    git config --global user.name "$git_user_name"
fi

if [ -z "$(git config --global user.email)" ]
then
    echo -n "Git user email (The email to appear on your commits): "
    read git_user_email
    git config --global user.email "$git_user_email"
fi
git config --global include.path ~/dotfiles/git.conf


# Symlink config files
echo "Symlinking config files"
source ~/dotfiles/functions.sh
backup_remove ~/.tigrc      && ln -s ~/dotfiles/tig.conf  ~/.tigrc
backup_remove ~/.vimrc      && ln -s ~/dotfiles/vim.conf  ~/.vimrc
backup_remove ~/.tmux.conf  && ln -s ~/dotfiles/tmux.conf ~/.tmux.conf

# Setup & symlink autoloads
echo "Making ~/.dotfiles-autolod dir, symlinking aliases and functions"
[ -d ~/dotfiles-autoload ] || mkdir ~/dotfiles-autoload
[ -e ~/dotfiles-autoload/functions.sh ] || ln -s ~/dotfiles/functions.sh ~/dotfiles-autoload/functions.sh
[ -e ~/dotfiles-autoload/aliases.sh ]   || ln -s ~/dotfiles/aliases.sh   ~/dotfiles-autoload/aliases.sh
[ -e ~/dotfiles-autoload/prompt.sh ]   || ln -s ~/dotfiles/prompt.sh   ~/dotfiles-autoload/prompt.sh
[ -e ~/dotfiles-autoload/banner.sh ]   || ln -s ~/dotfiles/banner.sh   ~/dotfiles-autoload/banner.sh

# Setup dotfiles to autoload
echo "Configuring Profile"
grep -q "dotfiles.sh" ~/.bashrc || echo -e "\n[ -f ~/dotfiles/dotfiles.sh ] && . ~/dotfiles/dotfiles.sh" >> ~/.bashrc

# Done!
echo "$(git config --global user.name) configured"
echo -en "see:\n\tdotfiles help\n\n"

# Reload profile
source ~/.profile