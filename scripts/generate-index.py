#!/usr/bin/env python3
"""Generate a PEP 503 compliant simple package index.

Reads packages.json for the package list and scans wheel files
(from a local directory or GitHub release assets) to generate
a static simple/ directory structure suitable for use with
pip --extra-index-url.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def sha256_file(filepath: str) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def normalize_name(name: str) -> str:
    """PEP 503 normalization."""
    return re.sub(r"[-_.]+", "-", name).lower()


def get_release_assets(repo: str) -> list[dict]:
    """Fetch release assets from GitHub using gh CLI."""
    try:
        result = subprocess.run(
            ["gh", "release", "list", "--repo", repo, "--json", "tagName"],
            capture_output=True, text=True, check=True,
        )
        releases = json.loads(result.stdout)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    assets = []
    for release in releases:
        tag = release["tagName"]
        try:
            result = subprocess.run(
                ["gh", "release", "view", tag, "--repo", repo,
                 "--json", "assets"],
                capture_output=True, text=True, check=True,
            )
            release_data = json.loads(result.stdout)
            for asset in release_data.get("assets", []):
                if asset["name"].endswith(".whl"):
                    assets.append({
                        "name": asset["name"],
                        "url": asset["url"],
                        "tag": tag,
                    })
        except subprocess.CalledProcessError:
            continue

    return assets


def generate_index(wheels_dir: str | None, output_dir: str,
                   repo: str = "gounthar/riscv64-python-wheels") -> None:
    packages_file = Path(__file__).parent.parent / "packages.json"
    with open(packages_file) as f:
        config = json.load(f)

    package_names = {normalize_name(p["name"]) for p in config["packages"]}

    # Collect wheels from local directory or GitHub releases
    wheels: dict[str, list[dict]] = {name: [] for name in package_names}

    if wheels_dir and os.path.isdir(wheels_dir):
        for whl_file in Path(wheels_dir).glob("*.whl"):
            name = normalize_name(whl_file.name.split("-")[0])
            if name in wheels:
                sha = sha256_file(str(whl_file))
                wheels[name].append({
                    "filename": whl_file.name,
                    "url": whl_file.name,
                    "sha256": sha,
                })
    else:
        for asset in get_release_assets(repo):
            name = normalize_name(asset["name"].split("-")[0])
            if name in wheels:
                download_url = (
                    f"https://github.com/{repo}/releases/download/"
                    f"{asset['tag']}/{asset['name']}"
                )
                wheels[name].append({
                    "filename": asset["name"],
                    "url": download_url,
                    "sha256": "",
                })

    # Generate simple/ directory
    simple_dir = Path(output_dir) / "simple"
    simple_dir.mkdir(parents=True, exist_ok=True)

    # Root index
    index_links = []
    for name in sorted(package_names):
        pkg_dir = simple_dir / name
        pkg_dir.mkdir(exist_ok=True)
        index_links.append(f'    <a href="{name}/">{name}</a>')

        # Package index
        wheel_links = []
        for w in wheels[name]:
            href = w["url"]
            if w["sha256"]:
                href += f"#sha256={w['sha256']}"
            wheel_links.append(
                f'    <a href="{href}">{w["filename"]}</a>'
            )

        pkg_index = (
            "<!DOCTYPE html>\n<html><body>\n"
            + "\n".join(wheel_links)
            + "\n</body></html>\n"
        )
        (pkg_dir / "index.html").write_text(pkg_index)

    root_index = (
        "<!DOCTYPE html>\n<html><body>\n"
        + "\n".join(index_links)
        + "\n</body></html>\n"
    )
    (simple_dir / "index.html").write_text(root_index)

    print(f"Generated PEP 503 index at {simple_dir}")
    print(f"Packages: {len(package_names)}")
    total_wheels = sum(len(v) for v in wheels.values())
    print(f"Wheels indexed: {total_wheels}")


if __name__ == "__main__":
    local_dir = sys.argv[1] if len(sys.argv) > 1 else None
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    generate_index(local_dir, out_dir)
