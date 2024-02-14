{ lib
, clang
, fetchFromGitHub
, buildGoModule
}:
buildGoModule rec {
  pname = "dae";
  version = "unstable-2023-09-04";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = pname;
    rev = "8334868905096abc4a2e94d39f831f6bae8e86d3";
    hash = "sha256-aOL0rwjRES0V3PFmBiHJcNiyOcGKGNY78Wqgnbk2cG0=";
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
    make CFLAGS="-D__REMOVE_BPF_PRINTK -fno-stack-protector -Wno-unused-command-line-argument" \
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

  meta = with lib; {
    description = "A Linux high-performance transparent proxy solution based on eBPF";
    homepage = "https://github.com/daeuniverse/dae";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    mainProgram = "dae";
  };
}
