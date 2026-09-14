#!/usr/bin/env python3
"""
Terminal Release Automation Script for SoundWave (Music App)

Usage:
  python3 scripts/release.py                  # Release current version from pubspec.yaml
  python3 scripts/release.py 2.0.2            # Bump to 2.0.2, build APK, and release to GitHub
  python3 scripts/release.py patch            # Auto-bump patch (e.g. 2.0.1 -> 2.0.2)
  python3 scripts/release.py minor            # Auto-bump minor (e.g. 2.0.1 -> 2.1.0)
"""

import sys
import os
import re
import subprocess
import json
import urllib.request
import urllib.error

REPO = "charanteja-k/music_app"
PUBSPEC_PATH = "pubspec.yaml"
APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"

def log(msg, symbol="🚀"):
    print(f"\033[1;36m{symbol} {msg}\033[0m")

def get_github_token():
    try:
        proc = subprocess.run(
            ["git", "credential", "fill"],
            input="protocol=https\nhost=github.com\n",
            text=True,
            capture_output=True,
            check=True
        )
        for line in proc.stdout.splitlines():
            if line.startswith("password="):
                return line.split("=", 1)[1].strip()
    except Exception:
        pass
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        return token
    raise RuntimeError("Could not find GitHub token in git credentials or GITHUB_TOKEN environment variable.")

def read_version():
    with open(PUBSPEC_PATH, "r") as f:
        content = f.read()
    match = re.search(r"^version:\s*([0-9\.]+)\+([0-9]+)", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not find version line in pubspec.yaml")
    return match.group(1), int(match.group(2))

def update_version(new_version, new_build):
    with open(PUBSPEC_PATH, "r") as f:
        content = f.read()
    new_content = re.sub(
        r"^version:\s*[0-9\.]+\+[0-9]+",
        f"version: {new_version}+{new_build}",
        content,
        flags=re.MULTILINE
    )
    with open(PUBSPEC_PATH, "w") as f:
        f.write(new_content)
    log(f"Updated pubspec.yaml to {new_version}+{new_build}", "📝")

def compute_bump(version_str, bump_type):
    parts = [int(p) for p in version_str.split(".")]
    while len(parts) < 3:
        parts.append(0)
    if bump_type == "patch":
        parts[2] += 1
    elif bump_type == "minor":
        parts[1] += 1
        parts[2] = 0
    elif bump_type == "major":
        parts[0] += 1
        parts[1] = 0
        parts[2] = 0
    return ".".join(map(str, parts))

def main():
    current_ver, current_build = read_version()
    
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in ["patch", "minor", "major"]:
            new_ver = compute_bump(current_ver, arg)
            new_build = current_build + 1
            update_version(new_ver, new_build)
            version_to_release = new_ver
        else:
            version_to_release = sys.argv[1].lstrip("v")
            new_build = current_build + 1
            update_version(version_to_release, new_build)
    else:
        version_to_release = current_ver

    tag_name = f"v{version_to_release}"
    log(f"Preparing release for tag: {tag_name}", "📌")

    # Build APK
    log("Building release APK (flutter build apk --release)...", "🔨")
    build_res = subprocess.run(["flutter", "build", "apk", "--release"])
    if build_res.returncode != 0:
        print("\033[1;31m❌ Build failed! Aborting release.\033[0m")
        sys.exit(1)

    if not os.path.exists(APK_PATH):
        print(f"\033[1;31m❌ APK not found at {APK_PATH}!\033[0m")
        sys.exit(1)

    # Git commit and push if there are uncommitted version changes
    status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout
    if "pubspec.yaml" in status:
        log("Committing version bump to git...", "📦")
        subprocess.run(["git", "add", "pubspec.yaml"])
        subprocess.run(["git", "commit", "-m", f"chore(release): bump version to {tag_name}"])
        subprocess.run(["git", "push", "origin", "main"])

    # Create GitHub Release
    token = get_github_token()
    release_url = f"https://api.github.com/repos/{REPO}/releases"

    release_body = f"### SoundWave {tag_name}\n\nAutomated release build for SoundWave {tag_name}.\nDownload the attached `app-release.apk` to install or trigger in-app updates."

    payload = json.dumps({
        "tag_name": tag_name,
        "target_commitish": "main",
        "name": f"SoundWave {tag_name}",
        "body": release_body,
        "draft": False,
        "prerelease": False
    }).encode("utf-8")

    req = urllib.request.Request(
        release_url,
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "Release-CLI"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as resp:
            release_data = json.loads(resp.read().decode("utf-8"))
            log(f"Created release: {release_data.get('html_url')}", "✨")
    except urllib.error.HTTPError as e:
        # Fetch existing release if already created
        req_tag = urllib.request.Request(
            f"{release_url}/tags/{tag_name}",
            headers={
                "Authorization": f"Bearer {token}",
                "Accept": "application/vnd.github+json",
                "User-Agent": "Release-CLI"
            }
        )
        with urllib.request.urlopen(req_tag) as resp:
            release_data = json.loads(resp.read().decode("utf-8"))
            log(f"Found existing release: {release_data.get('html_url')}", "ℹ️")

    upload_url = release_data["upload_url"].split("{")[0]

    # Delete existing asset with same name if it exists
    for asset in release_data.get("assets", []):
        if asset["name"] == "app-release.apk":
            log(f"Removing old asset: {asset['name']}", "🗑️")
            del_req = urllib.request.Request(
                f"https://api.github.com/repos/{REPO}/releases/assets/{asset['id']}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "Release-CLI"
                },
                method="DELETE"
            )
            with urllib.request.urlopen(del_req):
                pass

    log(f"Uploading APK asset to GitHub ({os.path.getsize(APK_PATH) / (1024*1024):.1f} MB)...", "☁️")
    upload_cmd = [
        "curl", "-L",
        "-X", "POST",
        "-H", f"Authorization: Bearer {token}",
        "-H", "Accept: application/vnd.github+json",
        "-H", "Content-Type: application/vnd.android.package-archive",
        "--data-binary", f"@{APK_PATH}",
        f"{upload_url}?name=app-release.apk"
    ]
    res = subprocess.run(upload_cmd, capture_output=True, text=True)
    if res.returncode == 0:
        res_json = json.loads(res.stdout)
        download_url = res_json.get("browser_download_url")
        print(f"\n\033[1;32m🎉 Success! SoundWave {tag_name} is released and live on GitHub!\033[0m")
        print(f"📦 Release URL:  {release_data.get('html_url')}")
        print(f"⬇️ Download APK: {download_url}\n")
    else:
        print(f"\033[1;31m❌ Upload error: {res.stderr}\033[0m")

if __name__ == "__main__":
    main()
