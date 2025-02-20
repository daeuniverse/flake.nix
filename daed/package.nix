{
  pnpm,
  nodejs,
  stdenv,
  clang,
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

let
  pname = "daed";
  version = "0.9.0";
  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = "daed";
    rev = "refs/tags/v${version}";
    hash = "sha256-5olEPaS/6ag69KUwBG8qXpyr1B2qrLK+vf13ZljHH+c=";
    fetchSubmodules = true;
  };

  web = stdenv.mkDerivation {
    inherit pname version src;

    pnpmDeps = pnpm.fetchDeps {
      inherit pname version src;
      hash = "sha256-N85njUxA4iQJCItCG40uroEuCAQiazHm31nrnOiIKZY=";
    };

    nativeBuildInputs = [
      nodejs
      pnpm.configHook
    ];

    buildPhase = ''
      runHook preBuild
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R dist/* $out/
      runHook postInstall
    '';
  };
in
buildGoModule rec {
  inherit pname version src;
  sourceRoot = "${src.name}/wing";

  vendorHash = "sha256-qB2qcJ82mFcVvjlYp/N9sqzwPotTROgymSX5NfEQMuY=";
  proxyVendor = true;

  nativeBuildInputs = [ clang ];

  hardeningDisable = [ "zerocallusedregs" ];

  prePatch = ''
    substituteInPlace Makefile \
      --replace-fail /bin/bash /bin/sh

    # ${web} does not have write permission
    mkdir dist
    cp -r ${web}/* dist
    chmod -R 755 dist
  '';

  buildPhase = ''
    runHook preBuild

    make CFLAGS="-D__REMOVE_BPF_PRINTK -fno-stack-protector -Wno-unused-command-line-argument" \
      NOSTRIP=y \
      WEB_DIST=dist \
      AppName=${pname} \
      VERSION=${version} \
      OUTPUT=$out/bin/daed \
      bundle

    runHook postBuild
  '';

  meta = {
    description = "Modern dashboard with dae";
    homepage = "https://github.com/daeuniverse/daed";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ oluceps ];
    platforms = lib.platforms.linux;
    mainProgram = "daed";
  };
}
