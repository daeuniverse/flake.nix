{
  lib,
  pkgs,
  craneLib,
  src,
  version,
}:

let
  rustToolchain = pkgs.rust-bin.fromRustupToolchainFile "${src}/crates/honk-ebpf/rust-toolchain.toml";

  bpfLinker = craneLibNightly.buildPackage {
    pname = "bpf-linker";
    version = "0.12.0-unstable-2026-10-23";
    src = pkgs.fetchFromGitHub {
      owner = "aya-rs";
      repo = "bpf-linker";
      rev = "f4a30595b407a9f7dbc1dfa38c4cbdd37a0d9f90";
      hash = "sha256-rvD6xL8ygSNrB5N2qi08S7vKmPrfcc0VzOpOpnjQIAY=";
    };
    cargoExtraArgs = "--no-default-features --features llvm-23";
    nativeBuildInputs = [ pkgs.clang ];
    # Use the same LLVM library as the eBPF Rust compiler.
    LLVM_PREFIX = pkgs.runCommand "honk-bpf-llvm" { } ''
      mkdir -p $out/lib
      ln -s ${rustToolchain}/lib/libLLVM* $out/lib/
      ln -s ${rustToolchain}/lib/libLLVM.so.* $out/lib/libLLVM.so
    '';
    doCheck = false;
  };

  craneLibNightly = craneLib.overrideToolchain rustToolchain;

  ebpfArgs = {
    inherit src version;
    pname = "honk-ebpf";
    nativeBuildInputs = [ bpfLinker ];
    cargoExtraArgs = "--manifest-path crates/honk-ebpf/Cargo.toml -Zbuild-std=core --target bpfel-unknown-none";
    cargoToml = "${src}/crates/honk-ebpf/Cargo.toml";
    cargoLock = "${src}/crates/honk-ebpf/Cargo.lock";
    CARGO_BUILD_RUSTFLAGS = "-C opt-level=2 -C llvm-args=-inline-threshold=300 -C linker=bpf-linker -C debuginfo=2 -C link-arg=--emit=obj -C link-arg=--llvm-args=-bpf-stack-size=4096 -C link-arg=--btf";
    cargoVendorDir = craneLibNightly.vendorMultipleCargoDeps {
      cargoConfigs = [ ];
      cargoLockList = [
        "${src}/crates/honk-ebpf/Cargo.lock"
        "${rustToolchain.passthru.availableComponents.rust-src}/lib/rustlib/src/rust/library/Cargo.lock"
      ];
    };
    doCheck = false;
    dontStrip = true;
  };

  ebpfArtifacts = craneLibNightly.buildDepsOnly ebpfArgs;

  ebpfPackage = craneLibNightly.buildPackage (
    ebpfArgs
    // {
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
    }
  );

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

    env.GITHUB_REF = "refs/tags/${version}";

    # Nix builds the eBPF object separately.
    postPatch = ''
      if [ -f crates/honk-core/build.rs ]; then
        substituteInPlace crates/honk-core/build.rs \
          --replace-fail '    embed_ebpf_object();' '    {}'
      fi
    '';
  };

  rustToolchainStable = pkgs.rust-bin.fromRustupToolchainFile "${src}/rust-toolchain.toml";
  craneLibStable = craneLib.overrideToolchain rustToolchainStable;

  cargoArtifacts = craneLibStable.buildDepsOnly commonArgs;

  package = craneLibStable.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
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
    }
  );
in
package
