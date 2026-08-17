{
  lib,
  pkgs,
  stdenv,
  craneLib,
  src,
  version,
}:

let
  rustToolchain = pkgs.rust-bin.nightly."2025-10-01".default.override {
    extensions = [ "rust-src" ];
  };

  craneLibNightly = craneLib.overrideToolchain rustToolchain;


  ebpfArgs = {
    inherit src version;
    pname = "honk-ebpf";
    nativeBuildInputs = [ pkgs.bpf-linker ];
    cargoExtraArgs = "--manifest-path crates/honk-ebpf/Cargo.toml -Zbuild-std=core --target bpfel-unknown-none --config profile.release.debug=2";
    cargoToml = "${src}/crates/honk-ebpf/Cargo.toml";
    cargoLock = "${src}/crates/honk-ebpf/Cargo.lock";
    cargoVendorDir = craneLibNightly.vendorMultipleCargoDeps {
      cargoConfigs = [];
      cargoLockList = [
        "${src}/crates/honk-ebpf/Cargo.lock"
        "${rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library/Cargo.lock"
      ];
    };
    doCheck = false;
    dontStrip = true;
  };

  ebpfArtifacts = craneLibNightly.buildDepsOnly ebpfArgs;

  ebpfPackage = craneLibNightly.buildPackage (ebpfArgs // {
    cargoArtifacts = ebpfArtifacts;
    doNotPostBuildInstallCargoBinaries = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      binPath="target/bpfel-unknown-none/release/honk-ebpf"
      if [ ! -f "$binPath" ]; then
        binPath="crates/honk-ebpf/target/bpfel-unknown-none/release/honk-ebpf"
      fi
      if [ ! -f "$binPath" ]; then
        echo "Could not find honk-ebpf binary in target directories."
        find . -type f -name "honk-ebpf"
        exit 1
      fi
      cp $binPath $out/bin/honk-ebpf
      runHook postInstall
    '';
  });

  commonArgs = {
    inherit src version;
    pname = "honk";
    
    strictDeps = true;

    nativeBuildInputs = with pkgs; [
      pkg-config
      llvmPackages.bintools
      git
      cmake
      clang
      rustPlatform.bindgenHook
    ];

    buildInputs = with pkgs; [
      openssl
    ];

    # Empty out build.rs so it doesn't try to build the eBPF object
    postPatch = ''
      if [ -f crates/honk-core/build.rs ]; then
        echo "fn main() {}" > crates/honk-core/build.rs
      fi
    '';
  };

  rustToolchainStable = pkgs.rust-bin.stable.latest.default;
  craneLibStable = craneLib.overrideToolchain rustToolchainStable;

  cargoArtifacts = craneLibStable.buildDepsOnly commonArgs;

  package = craneLibStable.buildPackage (commonArgs // {
    cargoArtifacts = cargoArtifacts;
    HONK_EBPF_OBJECT = "${ebpfPackage}/bin/honk-ebpf";
    cargoExtraArgs = "-p honk-core --features ebpf";
    doCheck = false; # Skip tests for now as they might require networking

    postInstall = ''
      if [ -f $out/bin/honk-core ]; then
        mv $out/bin/honk-core $out/bin/honk
      fi
    '';

    meta = with lib; {
      description = "A Linux high-performance transparent proxy solution based on eBPF (honk)";
      homepage = "https://github.com/daeuniverse/honk";
      license = licenses.gpl3Only;
      platforms = platforms.linux;
      mainProgram = "honk";
    };
  });
in
package
