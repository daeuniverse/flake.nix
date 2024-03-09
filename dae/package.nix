{ lib
, clang
, fetchFromGitHub
, buildGoModule
}:
buildGoModule rec {
  pname = "dae";
  version = "unstable-2024-03-01.r667.49f576e";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = pname;
    rev = "49f576e37d2178c9631bd44415c5618a8b38b1a3";
    hash = "sha256-ESYWcsP1Px1ki3H0GIjbmYk4mYblFlid+EgdHa/1BeI=";
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
