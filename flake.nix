{
  description = "rocket-chip";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Add a new input specifically for newer packages
    newerNixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small"; # More up-to-date
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, newerNixpkgs, flake-utils }@inputs:
    let
      overlay = import ./overlay.nix;
    in
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
        newerPkgs = import newerNixpkgs { inherit system; };
        
        clang19 = newerPkgs.llvmPackages_19.clang;
        libcxx19 = newerPkgs.llvmPackages_19.libcxx;
        
        clang19Wrapper = pkgs.writeShellScriptBin "clang-19" ''
          exec "${clang19}/bin/clang" "$@"
        '';
        clangpp19Wrapper = pkgs.writeShellScriptBin "clang++-19" ''
          exec "${clang19}/bin/clang++" "$@"
        '';
        
        deps = with pkgs; [
          git
          gnumake autoconf automake
          mill
          dtc
          verilator cmake ninja
          python3
          python3Packages.pip
          pkgsCross.riscv64-embedded.buildPackages.gcc
          pkgsCross.riscv64-embedded.buildPackages.gdb
          pkgs.pkgsCross.riscv64-embedded.riscv-pk
          openocd
          circt
          spike riscvTests
        ];
      in
        {
          legacyPackages = pkgs;
          devShell = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
            buildInputs = deps ++ [ clang19 clang19Wrapper clangpp19Wrapper ];
            SPIKE_ROOT = "${pkgs.spike}";
            RISCV_TESTS_ROOT = "${pkgs.riscvTests}";
            RV64_TOOLCHAIN_ROOT = "${pkgs.pkgsCross.riscv64-embedded.buildPackages.gcc}";
            shellHook = ''
              # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
              # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
              export PIP_PREFIX=$(pwd)/venv/pip_packages
              export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
              export PATH="$PIP_PREFIX/bin:$PATH"
              unset SOURCE_DATE_EPOCH
              pip3 install importlib-metadata typing-extensions riscof==1.25.2 pexpect
              export ROCKETCHIP=$(pwd)
            '';
          };
        }
      )
    // { inherit inputs; overlays.default = overlay; };
}
