{
  description = "xv6-riscv development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            pkgsCross.riscv64.buildPackages.gcc
            pkgsCross.riscv64.buildPackages.binutils

            qemu
            gnumake

            python3
            gdb
          ];

          shellHook = ''
            echo "xv6-riscv development environment"
            echo "=================================="
            echo ""
            echo "Available commands:"
            echo "  make qemu        - Build and run xv6 in QEMU"
            echo "  make qemu-gdb    - Run xv6 with GDB support"
            echo "  make clean       - Clean build artifacts"
            echo "  ./test-xv6.py    - Run automated tests"
            echo ""
            echo "Toolchain info:"
            echo "  RISC-V GCC: $(riscv64-unknown-linux-gnu-gcc --version | head -n1)"
            echo "  QEMU: $(qemu-system-riscv64 --version | head -n1)"
            echo ""
          '';

          TOOLPREFIX = "riscv64-unknown-linux-gnu-";
        };
      }
    );
}
