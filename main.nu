#!/usr/bin/env nu

def main [] {
  print -e "commands: [sync] <PROJECT> [<VERSION>] [--rev <REVISION>]"
  print -e $'(char newline)'
  print -e "REVISION: Any sha1 or references"
  print -e "          e.g. 'refs/tags/v1.0.0' | 'refs/heads/main' | rev_hash"
  print -e $'(char newline)'
  print -e "VERSIONS: List of versions to be updated."
  print -e "          e.g. release unstable"
  print -e $'(char newline)'
  print -e "PROJECT:  Project to be update. Current only support dae."
  print -e "          e.g. dae"
  print -e $'(char newline)'
  print -e 'example:'
  print -e "  updating unstable"
  print -e "          ./main.nu sync dae unstable"
  print -e "  updating unstable and release"
  print -e "          ./main.nu sync dae unstable release"
  print -e "  adding a new version"
  print -e "          ./main.nu sync dae sth-new --rev 'rev_hash'"
}

# ./main.nu sync dae release unstable
def "main sync" [
                project: string,
                ...versions,
                --rev (-r): string = ""
                ] {
  use std log;
  let get_branch_info = {|rev| (nix run nixpkgs#nix-prefetch-git
                    -- --url $'https://github.com/daeuniverse/($project).git'
                       --rev $rev
                       --fetch-submodules
                       --quiet | from json) };
  let get_rev_short_hash = {|| $in.rev | str substring 0..6 };

  let get_vendor_hash = {|v|
    let res = nix --log-format raw build $'.#($project)-($v)' | complete;
    if ($res.exit_code == 0) {
      log info "build success. remain vendorHash unchange"
      return;
    }
    let stderr = $res.stderr;
    let vendor_hash = $stderr | lines | find --regex "got:" | str trim | split row " " | last
    $vendor_hash
  }
  mut metadata = open ./metadata.json
  let version_to_sync = if (($versions | length) == 0) {
    ["release" "unstable"]
  } else {
    $versions
  }

  for v in $version_to_sync {
    match $v {
      "release" => {
        log info "updating release"
        let tag = http get $'https://api.github.com/repos/daeuniverse/($project)/releases/latest' | $in.tag_name;
        let branch_info = do $get_branch_info $tag;
        let hash = $branch_info | $in.hash;
        if ($hash == $metadata.dae.release.hash) { 
          log info "latest release hash identical. skip"
          # consider the vendorHash already exist
          continue
        }
        for pair in [[key,value];
                     [version $tag]
                     [rev $tag]
                     [hash $hash]
                     ] {
          $metadata = $metadata | update $project { update release { update $pair.key $pair.value } };
        }
      }
      "unstable" => {
        log info "updating unstable"
        let rev = 'refs/heads/main';
        let branch_info = do $get_branch_info $rev;
        let short_hash = $branch_info | do $get_rev_short_hash;
        let date = $branch_info | $in.date | format date "%Y-%m-%d"
        let version = $'unstable-($date).($short_hash)'

        if ($branch_info.hash == $metadata.dae.unstable.hash) { 
          log info "rev identical. skip"
          continue
        }
        for pair in [[key,value];
                     [version $version]
                     [rev $branch_info.rev]
                     [hash $branch_info.hash]
                     ] {
          $metadata = $metadata | update $project { update unstable { update $pair.key $pair.value } };
        }
      }
      # new version
      _ => {
        log info "adding new version";
        if ($rev | is-empty) {
          log error "must provide rev. skip";
          continue
        }
        if (($version_to_sync | length) > 1) { 
          log error "syncing new version must specify only one. exiting"
          return
        }
        if ($v in $metadata) { 
          log error "version already exist. skip"
          continue
        }

        let branch_info = do $get_branch_info $rev;
        let short_hash = $branch_info | do $get_rev_short_hash;
        let date = $branch_info | $in.date | format date "%Y-%m-%d"
        let version = $'unstable-($date).($short_hash)'

        
        $metadata = $metadata | update $project { insert $v {
            version:$version,
            rev:$branch_info.rev,
            hash:$branch_info.hash,
            vendorHash:""
          }
        }
      }
    }

    log info "save file for calc vendorHash"
    $metadata | save ./metadata.json -f
    let new_vendor_hash = do $get_vendor_hash $v;
    if ($new_vendor_hash == null) {
      log info "skip modify vendorHash"
      return;
    }
    $metadata = $metadata | update $project { update $v { update vendorHash $new_vendor_hash } };
  }

  log info "save final file"
  $metadata | save ./metadata.json -f
}
