# riscv64 Python Wheels

Prebuilt Python wheels for RISC-V 64-bit (riscv64) Linux, for packages that don't yet publish riscv64 wheels on PyPI.

Many Python packages with native extensions (Rust, C, C++) lack official riscv64 wheels on PyPI, forcing users to compile from source on every install. This repo provides prebuilt wheels to save time and simplify riscv64 Python development.

## Installation

### Direct from GitHub Release

```bash
pip install PACKAGE --find-links https://github.com/gounthar/riscv64-python-wheels/releases/download/RELEASE_TAG/
```

Replace `PACKAGE` with the package name and `RELEASE_TAG` with the release version (e.g., `v2026.03.07-cp313`).

### Install multiple packages at once

```bash
pip install tokenizers pydantic-core safetensors cryptography \
  --find-links https://github.com/gounthar/riscv64-python-wheels/releases/download/v2026.03.07-cp313/
```

### Via PEP 503 index (coming soon)

```bash
pip install PACKAGE --extra-index-url https://gounthar.github.io/riscv64-python-wheels/simple/
```

## Supported Packages

| Package | Version | Python | Source | Status |
|---------|---------|--------|--------|--------|
| pydantic-core | 2.41.5 | cp313 | Rust | Built |
| tokenizers | 0.22.2 | cp39+ | Rust | Built |
| sentencepiece | 0.2.1 | cp313 | C++ | Built |
| cffi | 2.0.0 | cp313 | C | Built |
| cryptography | 46.0.5 | cp313+ | Rust + C | Built |
| watchfiles | 1.1.1 | cp313 | Rust | Built |
| zstandard | 0.25.0 | cp313 | C | Built |
| pyyaml | 6.0.3 | cp313 | C | Built |
| tree-sitter | 0.25.2 | cp313 | C | Built |
| tree-sitter-bash | 0.25.1 | cp310+ | C | Built |
| textual-speedups | 0.2.1 | cp313 | Rust | Built |
| safetensors | 0.7.0 | cp313 | Rust | Building |
| tiktoken | 0.12.0 | cp313 | Rust | Building |
| blake3 | 1.0.8 | cp313 | Rust + C | Building |
| pillow | 12.1.1 | cp313 | C | Building |

## Build Hardware

All wheels are built natively (no cross-compilation, no QEMU) on:

- **BananaPi F3** (SpacemiT K1)
- 8x Spacemit X60 rv64imafdcv cores @ 1.6 GHz
- RVV 1.0 with vlen=256, zvfh extensions
- 16 GB RAM
- Debian trixie (testing), GCC 14.2, Python 3.13.5

## Release Naming

Releases are tagged as `v{YYYY.MM.DD}-cp{python_version}`, for example `v2026.03.07-cp313`.

Each release contains all wheels for that Python version, plus a `SHA256SUMS` file for integrity verification.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/extract-wheels.sh` | Extract riscv64 wheels from pip cache on the build machine |
| `scripts/build-from-source.sh` | Build a package wheel from a forked source checkout |
| `scripts/generate-index.py` | Generate PEP 503 compliant package index for GitHub Pages |
| `scripts/check-upstream.sh` | Detect new upstream versions on PyPI |

## Upstream Forks

Each package is forked under [github.com/gounthar](https://github.com/gounthar) to enable future upstream PRs adding riscv64 to their official CI/wheel builds.

## Contributing

Contributions are welcome! If you have access to riscv64 hardware and want to help build wheels:

1. Fork this repo
2. Build a wheel using `scripts/build-from-source.sh PACKAGE`
3. Open a PR with the wheel file and updated `packages.json`

## License

Apache-2.0. See [LICENSE](LICENSE) for details.
