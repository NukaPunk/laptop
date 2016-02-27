#!/bin/sh

# This will install my common developnent tools.

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

append_to_zshrc() {
  local text="$1" zshrc
  local skip_new_line="${2:-0}"

  if [ -w "$HOME/.zshrc.local" ]; then
    zshrc="$HOME/.zshrc.local"
  else
    zshrc="$HOME/.zshrc"
  fi

  if ! grep -Fqs "$text" "$zshrc"; then
    if [ "$skip_new_line" -eq 1 ]; then
      printf "%s\n" "$text" >> "$zshrc"
    else
      printf "\n%s\n" "$text" >> "$zshrc"
    fi
  fi
}

# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

if [ ! -d "$HOME/.bin/" ]; then
  mkdir "$HOME/.bin"
fi

if [ ! -f "$HOME/.zshrc" ]; then
  touch "$HOME/.zshrc"
fi

# shellcheck disable=SC2016
append_to_zshrc 'export PATH="$HOME/.bin:$PATH"'

HOMEBREW_PREFIX="/usr/local"

if [ -d "$HOMEBREW_PREFIX" ]; then
  if ! [ -r "$HOMEBREW_PREFIX" ]; then
    sudo chown -R "$LOGNAME:admin" /usr/local
  fi
else
  sudo mkdir "$HOMEBREW_PREFIX"
  sudo chflags norestricted "$HOMEBREW_PREFIX"
  sudo chown -R "$LOGNAME:admin" "$HOMEBREW_PREFIX"
fi

case "$SHELL" in
  */zsh) : ;;
  *)
    fancy_echo "Changing your shell to zsh ..."
      chsh -s "$(which zsh)"
    ;;
esac

brew_install_or_upgrade() {
  if brew_is_installed "$1"; then
    if brew_is_upgradable "$1"; then
      brew upgrade "$@"
    fi
  else
    brew install "$@"
  fi
}

brew_cask_install_or_upgrade() {
  if brew_cask_is_installed "$1"; then
    brew cask update "$@"
  else
    brew cask install "$@"
  fi
}

brew_is_installed() {
  local name
  name="$(brew_expand_alias "$1")"

  brew list -1 | grep -Fqx "$name"
}


brew_cask_is_installed() {
  local name
  name="$(brew_expand_alias "$1")"

  brew cask list -1 | grep -Fqx "$name"
}


brew_is_upgradable() {
  local name
  name="$(brew_expand_alias "$1")"

  ! brew outdated --quiet "$name" >/dev/null
}

brew_tap() {
  brew tap "$1" --repair 2> /dev/null
}

brew_expand_alias() {
  brew info "$1" 2>/dev/null | head -1 | awk '{gsub(/.*\//, ""); gsub(/:/, ""); print $1}'
}

brew_launchctl_restart() {
  local name
  name="$(brew_expand_alias "$1")"
  local domain="homebrew.mxcl.$name"
  local plist="$domain.plist"

  mkdir -p "$HOME/Library/LaunchAgents"
  ln -sfv "/usr/local/opt/$name/$plist" "$HOME/Library/LaunchAgents"

  if launchctl list | grep -Fq "$domain"; then
    launchctl unload "$HOME/Library/LaunchAgents/$plist" >/dev/null
  fi
  launchctl load "$HOME/Library/LaunchAgents/$plist" >/dev/null
}

gem_install_or_update() {
  if gem list "$1" --installed > /dev/null; then
    gem update "$@"
  else
    gem install "$@"
    rbenv rehash
  fi
}

if ! command -v brew >/dev/null; then
  fancy_echo "Installing Homebrew ..."
    curl -fsS \
      'https://raw.githubusercontent.com/Homebrew/install/master/install' | ruby

    append_to_zshrc '# recommended by brew doctor'

    # shellcheck disable=SC2016
    append_to_zshrc 'export PATH="/usr/local/bin:$PATH"' 1

    export PATH="/usr/local/bin:$PATH"
fi

if brew list | grep -Fq brew-cask; then
  fancy_echo "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

fancy_echo "Updating Homebrew formulae ..."
brew_tap 'thoughtbot/formulae'

brew update

fancy_echo "Updating Unix tools ..."
brew_install_or_upgrade 'git'
brew_install_or_upgrade 'openssl'
brew_install_or_upgrade 'vim'
brew_install_or_upgrade 'wget'
brew_install_or_upgrade 'zsh'
brew_install_or_upgrade 'zsh-completions'

fancy_echo "Updating Heroku tools ..."
brew_install_or_upgrade 'heroku-toolbelt'

fancy_echo "Updating programming languages ..."
brew_install_or_upgrade 'node'
brew_install_or_upgrade 'mono'
brew_install_or_upgrade 'dnvm'

fancy_echo "Using DNVM to install DNX for Mono ..."
dnvm upgrade -r mono

fancy_echo "Updating databases ..."
brew_install_or_upgrade 'postgres'
brew_install_or_upgrade 'neo4j'
brew_install_or_upgrade 'mongodb'
brew_launchctl_restart 'postgresql'
brew_launchctl_restart 'neo4j'
brew_launchctl_restart 'mongodb'

fancy_echo "Updating development tools ..."
brew_cask_install_or_upgrade 'cocoarestclient'
brew_cask_install_or_upgrade 'flux'
brew_cask_install_or_upgrade 'caffeine'
brew_cask_install_or_upgrade 'spotify'
brew_cask_install_or_upgrade 'visual-studio-code'
brew_cask_install_or_upgrade 'atom'
brew_cask_install_or_upgrade 'firefox'
brew_cask_install_or_upgrade 'firefoxdeveloperedition'
brew_cask_install_or_upgrade 'slack'
brew_cask_install_or_upgrade 'postico'
brew_cask_install_or_upgrade 'robomongo'
brew_cask_install_or_upgrade 'gimp'

if [ -z "zsh --version" ]; then
  fancy_echo "Installing oh-my-zsh on top of zsh ..."
  curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
fi
