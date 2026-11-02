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

        version = "1.15.0";

        src = pkgs.fetchFromGitHub {
          owner = "sky-ai-eng";
          repo = "triage-factory";
          tag = "v${version}";
          hash = "sha256-k2tm4bxG6Jv4IuMB/TNSGwz9p1YMRs1z8YqPiY5KgxA=";
        };

        pnpmDepsHash = "sha256-NMY55An5wVQ43FbaFaB0cqzAQIW2Wskti3NELs4REdE=";

        frontend = pkgs.stdenvNoCC.mkDerivation {
          pname = "triage-factory-frontend";
          inherit version;
          inherit src;
          sourceRoot = "${src.name}/frontend";

          pnpmDeps = pkgs.fetchPnpmDeps {
            pname = "triage-factory-frontend";
            inherit version src;
            sourceRoot = "${src.name}/frontend";
            hash = pnpmDepsHash;
            fetcherVersion = 4;
          };

          nativeBuildInputs = [
            pkgs.nodejs
            pkgs.pnpm
            pkgs.pnpmConfigHook
          ];

          NODE_OPTIONS = "--max-old-space-size=4096";

          buildPhase = ''
            runHook preBuild
            pnpm build
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r dist/* $out/
            runHook postInstall
          '';
        };
      in
      {
        packages = {
          inherit frontend;

          default = pkgs.buildGoModule {
            pname = "triagefactory";
            inherit version src;
            vendorHash = "sha256-AQOqRe5Duh85yu3+J/jQjf9cET7YAxPHBwvb9fGJMXE=";

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
