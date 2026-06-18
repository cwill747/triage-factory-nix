{
  description = "Triage Factory — AI-powered issue triage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        version = "1.12.1";

        src = pkgs.fetchFromGitHub {
          owner = "sky-ai-eng";
          repo = "triage-factory";
          tag = "v${version}";
          hash = "sha256-wARBk1cVQOwqEDyLY8oHRSCsjQBIOEiNEfzngMxx/Hk=";
        };

        frontend = pkgs.buildNpmPackage {
          pname = "triage-factory-frontend";
          inherit version;
          src = "${src}/frontend";
          npmDepsHash = "sha256-Jl+3dIOQDsm+ZTze3Rv8+udGPCInQTQmMm6hZGAur+0=";
          NODE_OPTIONS = "--max-old-space-size=4096";
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r dist/* $out/
            runHook postInstall
          '';
        };
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "triagefactory";
          inherit version src;
          vendorHash = "sha256-17MiDYIwqbXa1GWe2ksNMkYhhs2SIw5QfLWV9IyYl4E=";

          ldflags = [
            "-s"
            "-w"
            "-X main.Version=v${version}"
          ];

          nativeCheckInputs = [ pkgs.git ];

          checkFlags =
            let
              skippedTests = [
                "TestImport_RoundTripSessionTreeAndCompactions"
              ];
            in
            [ "-run" "^(?!${builtins.concatStringsSep "|" skippedTests}$)" ];

          preCheck = ''
            export HOME=$(mktemp -d)
            git config --global user.email "test@test.com"
            git config --global user.name "Test"
          '';

          preBuild = ''
            mkdir -p frontend/dist
            cp -r ${frontend}/* frontend/dist/
          '';

          postInstall = ''
            mv $out/bin/triage-factory $out/bin/triagefactory
          '';

          meta = {
            description = "AI-powered issue triage";
            mainProgram = "triagefactory";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            go
            nodejs
            gopls
            gotools
          ];
        };
      }
    );
}
