src: { clang
     , fetchFromGitHub
     , buildGoModule
     , lib
     }:
buildGoModule rec {
  pname = "dae";
  version = src.shortRev;

  inherit src;

  vendorHash = "sha256-sqcImm5BYTiUnBmcpWWMR1TuV877VE5gZ8Oth8AxjSg=";

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
