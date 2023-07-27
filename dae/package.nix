{ clang
, fetchFromGitHub
, buildGoModule
, lib
}:
buildGoModule (
  let dyn = lib.strings.splitString "\n" (builtins.readFile ./dynamic_info); in rec {
    pname = "dae";
    version = with lib; substring 0 8 (elemAt dyn 0);

    src = fetchFromGitHub {
      owner = "daeuniverse";
      repo = pname;
      rev = lib.elemAt dyn 0;
      hash = lib.elemAt dyn 1;
      fetchSubmodules = true;
    };

    vendorHash = lib.elemAt dyn 2;

    proxyVendor = true;

    nativeBuildInputs = [ clang ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/daeuniverse/dae/cmd.Version=${version}"
      "-X github.com/daeuniverse/dae/common/consts.MaxMatchSetLen_=64"
    ];

    preBuild = ''
      make CFLAGS="-D__REMOVE_BPF_PRINTK -fno-stack-protector" \
      NOSTRIP=y \
      ebpf
    '';

    # network required
    doCheck = false;

    postInstall = ''
      install -Dm444 install/dae.service $out/lib/systemd/system/dae.service
      substituteInPlace $out/lib/systemd/system/dae.service \
        --replace /usr/bin/dae $out/bin/dae
    '';
  }
)
