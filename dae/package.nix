{ clang
, fetchFromGitHub
, buildGoModule
, lib
}:
buildGoModule (
  let hashes = lib.strings.splitString "\n" (builtins.readFile ./HASH); in rec {
    pname = "dae";
    version = "0.2.2";

    src = fetchFromGitHub {
      owner = "daeuniverse";
      repo = pname;
      rev = "v${version}";
      hash = lib.elemAt hashes 0;
      fetchSubmodules = true;
    };

    vendorHash = lib.elemAt hashes 1;

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
