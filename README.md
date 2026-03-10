# riscv64 Python Wheels

Prebuilt Python wheels for RISC-V 64-bit (riscv64) Linux, for packages that don't yet publish riscv64 wheels on PyPI.

Many Python packages with native extensions (Rust, C, C++) lack official riscv64 wheels on PyPI, forcing users to compile from source on every install. This repo provides prebuilt wheels and a [PEP 503](https://peps.python.org/pep-0503/) compliant package index to make `pip install` fast on RISC-V.

## Quick Start

Add our index as an extra source and install packages normally:

```bash
pip install PACKAGE --extra-index-url https://gounthar.github.io/riscv64-python-wheels/simple/
```

For example:

```bash
pip install tokenizers pydantic-core safetensors tiktoken torch \
    --extra-index-url https://gounthar.github.io/riscv64-python-wheels/simple/
```

pip will check our index first, and fall back to PyPI for packages we don't cover.

### pip.conf (permanent)

To avoid typing `--extra-index-url` every time, add this to `~/.config/pip/pip.conf`:

```ini
[global]
extra-index-url = https://gounthar.github.io/riscv64-python-wheels/simple/
```

## Supported Packages

### Rust / maturin packages

| Package | Version | Python | Status |
|---------|---------|--------|--------|
| blake3 | 1.0.8 | cp313 | ✅ Built |
| cryptography | 46.0.5 | cp313+ | ✅ Built |
| fastar | 0.8.0 | cp313 | ✅ Built |
| jiter | 0.13.0 | cp313 | ✅ Built |
| openai-harmony | 0.0.8 | cp313 | ✅ Built |
| pydantic-core | 2.42.0 | cp313 | ✅ Built |
| rignore | 0.7.6 | cp313 | ✅ Built |
| safetensors | 0.7.0 | cp38+ | ✅ Built |
| textual-speedups | 0.2.1 | cp313 | ✅ Built |
| tiktoken | 0.12.0 | cp313 | ✅ Built |
| tokenizers | 0.22.2 | cp39+ | ✅ Built |
| watchfiles | 1.1.1 | cp313 | ✅ Built |

### C / C++ / setuptools packages

| Package | Version | Python | Status |
|---------|---------|--------|--------|
| cffi | 2.0.0 | cp313 | ✅ Built |
| httptools | 0.8.0 | cp313 | ✅ Built |
| msgspec | 0.20.1 | cp313 | ✅ Built |
| pillow | 12.1.1 | cp313 | ✅ Built |
| pyyaml | 6.0.3 | cp313 | ✅ Built |
| pyzmq | 27.2.0 | cp313 | ✅ Built |
| sentencepiece | 0.2.1 | cp313 | ✅ Built |
| setproctitle | 1.3.7 | cp313 | ✅ Built |
| tree-sitter | 0.25.2 | cp313 | ✅ Built |
| tree-sitter-bash | 0.25.1 | cp310+ | ✅ Built |
| uvloop | 0.22.1 | cp313 | ✅ Built |
| zstandard | 0.25.0 | cp313 | ✅ Built |

### PyTorch

| Package | Version | Python | Status |
|---------|---------|--------|--------|
| torch | 2.10.0 | cp313 | ✅ Built (CPU-only, distributed + Gloo) |

PyTorch requires system libraries: `sudo apt install libopenblas0 libnuma1`

### ISA Compatibility

All wheels target **baseline rv64gc** — no vector extensions required. They work on any riscv64 Linux system, including boards without RVV support.

## Automation

New upstream versions are detected daily. The pipeline:

1. **detect-and-build.yml** (daily, ubuntu-latest) — checks PyPI for new versions
2. **build-riscv64.yml** (self-hosted BananaPi F3) — builds wheel natively
3. **update-index.yml** (ubuntu-latest) — aggregates wheels, regenerates PEP 503 index, deploys to GitHub Pages

Each upstream package is forked under [github.com/gounthar](https://github.com/gounthar) with a `build-riscv64.yml` workflow.

## Build Hardware

All wheels are built natively (no cross-compilation, no QEMU) on two **BananaPi F3** boards:

- SpacemiT K1 SoC, 8x rv64imafdcv cores @ 1.6 GHz
- RVV 1.0 with vlen=256
- 16 GB RAM
- Debian trixie (testing), GCC 14.2, Python 3.13.5
- Self-hosted GitHub Actions via [github-act-runner](https://github.com/ChristopherHX/github-act-runner)

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/generate-index.py` | Generate PEP 503 compliant package index for GitHub Pages |
| `scripts/check-upstream.sh` | Detect new upstream versions on PyPI |
| `scripts/extract-wheels.sh` | Extract riscv64 wheels from pip cache |
| `scripts/build-from-source.sh` | Build a wheel from a forked source checkout |

## Contributing

Contributions are welcome! If you have access to riscv64 hardware and want to help build wheels:

1. Fork the upstream package repo
2. Add a `build-riscv64.yml` workflow (see any existing fork for a template)
3. Build and test the wheel
4. Open a PR here to add the package to `packages.json`

## License

Apache-2.0. See [LICENSE](LICENSE) for details.
