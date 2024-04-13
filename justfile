# justfile
# cheatsheet: https://cheatography.com/linux-china/cheat-sheets/justfile/

# define alias

# set options
set positional-arguments := true

# default recipe to display help information
default:
  @just --list

# update all flake inputs
up:
  @nix flake update

# update a particular flake input
upp input:
  @nix flake lock --update-input {{ input }}

# build pkg
build pkg:
  @nix build .#{{ pkg }}

# check version
version pkg:
  @./result/bin/{{ pkg }} --version

# nix-prefetch-url
prefetch-url url:
  @nix-prefetch-url --type sha256 '{{ url }}' | xargs nix hash to-sri --type sha256

# nix-prefetch-git
prefetch-git repo rev:
  @nix-prefetch-git --url 'git@github.com:{{ repo }}' --rev '{{ rev }}' --fetch-submodules --quiet

# stage all files
add:
  @git add .
