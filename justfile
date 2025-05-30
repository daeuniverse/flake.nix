# justfile
# cheatsheet: https://cheatography.com/linux-china/cheat-sheets/justfile/

# define alias

# set options
set positional-arguments := true

# default recipe to display help information
default:
  @just --list

# build pkg
build pkg:
  @nix build .#{{ if pkg == "dae-unstable" { "dae-unstable" } else { pkg } }}
  # @nix build .#dae-unstable

# check version
version pkg:
  @./result/bin/{{ pkg }} --version

# update all flake inputs
update:
  @nix flake update

# update a particular flake input
update-input input:
  @nix flake lock --update-input {{ input }}

# nix-prefetch-url
prefetch-url url:
  @nix-prefetch-url --type sha256 '{{ url }}' | xargs nix hash to-sri --type sha256

# nix-prefetch-git
prefetch-git repo rev:
  @nix-prefetch-git --url 'git@github.com:{{ repo }}' --rev '{{ rev }}' --fetch-submodules --quiet

# update metadata for a project based off the latest upstream git commit
update-metadata project:
    #!/usr/bin/env bash
    set -euo pipefail
    # Fetch the metadata for the project
    json_output=$(just prefetch-git daeuniverse/{{ project }} refs/heads/main | jq)
    # Extract the necessary values from the json_output
    version=$(echo "$json_output" | jq -r '.version')
    date=$(echo "$json_output" | jq -r '.date' | awk -F'T' '{print $1}')
    rev=$(echo "$json_output" | jq -r '.rev')
    rev_short=$(echo "$json_output" | jq -r '.rev' | cut -c1-7)
    hash=$(echo "$json_output" | jq -r '.hash')
    # Update the metadata.json file
    jq --arg version "unstable-$date.$rev_short" \
       --arg rev "$rev" \
       --arg hash "$hash" \
       '.version = $version | .rev = $rev | .hash = $hash' \
       ./{{ project }}/metadata.json | tee ./{{ project }}/metadata.json.tmp
    # Replace the original file
    mv ./{{ project }}/{metadata.json.tmp,metadata.json}

# stage all files
add:
  @git add .
