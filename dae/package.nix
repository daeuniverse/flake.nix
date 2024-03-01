{ lib
, clang
, fetchFromGitHub
, buildGoModule
}:
buildGoModule rec {
  pname = "dae";
  version = "unstable-2024-03-01.r665.6f1db5";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = pname;
    rev = "6f1db5ee1fa46f867893124d6cd41604a0c561d7";
    hash = "sha256-1PJ+Y9MVEP9VRCnFMKf6QmXK84so22+ol4LiRbQJVr4=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-/r118MbfHxXHt7sKN8DOGj+SmBqSZ+ttjYywnqOIPuY=";

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
