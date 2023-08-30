{ clang
, fetchFromGitHub
, buildGoModule
}:
buildGoModule rec {
  pname = "dae";
  version = "unstable-2023-08-14";

  src = fetchFromGitHub {
    owner = "daeuniverse";
    repo = pname;
    rev = "8bbfd691a7034b6007600ed65547cb84f446d387";
    hash = "sha256-WiJqhXYehuUCLEuVbsQkmTntuH1srtePtZgYBSTbxiw=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-fb4PEMhV8+5zaRJyl+nYi2BHcOUDUVAwxce2xaRt5JA=";

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
