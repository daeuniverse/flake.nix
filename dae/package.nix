{ clang
, fetchFromGitHub
, buildGoModule
}:
buildGoModule rec {
  pname = "dae";
  version = "0.4.0rc1";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = pname;
    rev = "v0.4.0rc1";
    hash = "sha256-54Co7kd/t2rARa+efgesNjBGmVCPBj0B640odHy6KFY=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-rZwK+mYWJqgLFhzwZTfCC4tIg2gtNtx7Lu/fyOL3ozA=";

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
