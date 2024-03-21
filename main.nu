#!/usr/bin/env nu

# original from https://github.com/nix-community/nixpkgs-wayland/blob/master/main.nu

let system = "x86_64-linux";

def header [ color: string text: string spacer="▒": string ] {
  let text = $"($text) "
  let header = $"("" | fill -c $spacer -w 2) ($text | fill -c $spacer -w 100)"
  print -e $"(ansi $color)($header)(ansi reset)"
}

def main [] {
  print -e "commands: [build]"
}

def "main build" [] {
  buildDrv $"packages.($system)"
  print -e ""
}


def buildDrv [ drvRef: string ] {
  header "white_reverse" $"build ($drvRef)" "░"
  header "blue_reverse" $"eval ($drvRef)"
  let evalJobs = (
    ^nix-eval-jobs
      --flake $".#($drvRef)"
      --check-cache-status
        | from json --objects
  )

  header "green_reverse" $"build ($drvRef)"
  print -e ($evalJobs
    | where isCached == false
    | select name isCached)

  $evalJobs
    | where isCached == false
    | each { |drv| do -c  { ^nix build $'($drv.drvPath)^*' } }

  header "purple_reverse" $"cache: calculate paths: ($drvRef)"
  let pushPaths = ($evalJobs | each { |drv|
    $drv.outputs | each { |outPath|
      if ($outPath.out | path exists) {
        $outPath.out
      }
    }
  })
  print -e $pushPaths

  if ('CACHIX_AUTH_TOKEN' in $env) {
    let cachePathsStr = ($pushPaths | each {|it| $"($it)(char nl)"} | str join)
    let cacheResults = (echo $cachePathsStr | ^cachix push daeuniverse | complete)
    header "purple_reverse" $"cache/push ($drvRef)"
    print -e $cacheResults
  } else {
    print -e "'$CACHIX_AUTH_TOKEN' not set, not pushing to cachix."
  }

}
