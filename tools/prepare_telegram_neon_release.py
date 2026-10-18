"""Create a new bounded Telegram artifact from a verified immutable full release.

Local packaging only: never edits runtime, source full release, hosting or latest.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import zipfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {"index.html", ".htaccess", "release.json", "version.json", "manifest.json", "favicon.png", "i.php"}
APIS = {"api/scores.php", "api/tg_common.php", "api/mobile_store.php"}
DIRECTORIES = {"js", "css", "config", "icons", "assets"}
PWA_ICONS = {"Icon-192.png", "Icon-512.png", "Icon-maskable-192.png", "Icon-maskable-512.png"}

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def load(file: Path):
    return json.loads(file.read_text(encoding="utf-8-sig"))

def write_json(file: Path, value):
    file.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def allowed(name: str) -> bool:
    p = PurePosixPath(name)
    if p.is_absolute() or ".." in p.parts or "\\" in name:
        raise ValueError(f"Invalid manifest path: {name}")
    if name in ROOT_FILES or name in APIS:
        return True
    return p.parts[0] in DIRECTORIES and not (name == "assets/branding/landing" or name.startswith("assets/branding/landing/"))

def normalized_js(data: bytes) -> str:
    text = data.decode("utf-8-sig").replace("\r\n", "\n")
    return re.sub(r"from '(\./[^']+?\.js)(\?v=[^']*)?'", r"from '\1'", text)

def normalized_html(data: bytes) -> str:
    text = data.decode("utf-8-sig").replace("\r\n", "\n")
    return re.sub(r"((?:src|href)=[\"'][^\"']+\.(?:js|css))(?:\?v=[^\"']*)?([\"'])", r"\1\2", text)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full-release", required=True)
    parser.add_argument("--accepted", default="docs/release-evidence/telegram-final-parity-20261014/source-freeze.json")
    args = parser.parse_args()
    full = Path(args.full_release).resolve()
    releases = (ROOT / "releases").resolve()
    if full.parent != releases or not full.is_dir():
        raise ValueError("Full release must be a direct existing releases/ child")
    manifest = load(full / "manifest.json")
    build_id = manifest["buildId"]
    version = manifest["version"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+_\d{8}_\d{6}_\d{3}", build_id) or full.name != build_id:
        raise ValueError("Unexpected full release identity")
    destination = releases / ("telegram-neon-" + build_id)
    if destination.exists():
        raise FileExistsError("Scoped immutable release already exists; never overwrite")
    accepted_file = (ROOT / args.accepted).resolve()
    accepted = load(accepted_file)
    if accepted.get("allCurrentFullLifecycleFieldAndAggregateMatch") is not True or accepted.get("acceptedCount") != 95:
        raise ValueError("Expected final accepted95 source proof")
    rows = accepted["acceptedHashes"]
    for row in rows:
        if digest((ROOT / row["path"]).read_bytes()) != row["sha256"]:
            raise ValueError("Accepted source drift: " + row["path"])
    full_before = {}
    selected = []
    for entry in manifest["files"]:
        name = entry["path"]
        allowed(name)  # Validate every path before reading.
        raw = (full / "site" / name).read_bytes()
        if len(raw) != entry["bytes"] or digest(raw) != entry["sha256"]:
            raise ValueError("Full manifest mismatch: " + name)
        full_before[name] = digest(raw)
        if allowed(name):
            selected.append(entry)
    if {x["path"] for x in selected if x["path"].startswith("api/")} != APIS:
        raise ValueError("API whitelist must contain exactly three files")
    if not ROOT_FILES <= {x["path"] for x in selected}:
        raise ValueError("Required root files missing")
    actual_full = {p.relative_to(full / "site").as_posix() for p in (full / "site").rglob("*") if p.is_file()}
    if actual_full != set(full_before):
        raise ValueError("Full release contains unmanifested files")
    site = destination / "site"
    site.mkdir(parents=True)
    remaps = []
    for entry in selected:
        name = entry["path"]
        # Standard builder nests web/icons in an existing icons directory. Keep
        # canonical PNGs exact, while restoring the unchanged index/PWA links.
        target_name = "icons/" + PurePosixPath(name).name if name.startswith("icons/icons/") and PurePosixPath(name).name in PWA_ICONS else name
        if target_name != name:
            remaps.append({"source": name, "target": target_name, "sha256": entry["sha256"]})
        target = site / target_name
        if target.exists():
            raise ValueError("Package destination collision: " + target_name)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(full / "site" / name, target)
    identity = load(site / "release.json")
    if identity["buildId"] != build_id or identity["version"] != version:
        raise ValueError("Full identity mismatch")
    identity["artifact"] = "telegram-neon"
    write_json(site / "release.json", identity)
    write_json(site / "version.json", {"version": version, "buildId": build_id, "artifact": "telegram-neon"})
    pwa = load(site / "manifest.json")
    pwa.update(version=version, buildId=build_id, artifact="telegram-neon")
    write_json(site / "manifest.json", pwa)
    comparisons = []
    for row in rows:
        source_name = row["path"]
        candidate_name = source_name.removeprefix("telegram-web/")
        if not source_name.startswith("telegram-web/"):
            candidate_name = source_name
        target = site / candidate_name
        if not target.is_file():
            continue
        source = (ROOT / source_name).read_bytes()
        built = target.read_bytes()
        if source_name == "telegram-web/index.html":
            if normalized_html(source) != normalized_html(built):
                raise ValueError("Stamped HTML differs from accepted source: " + source_name)
            mode = "normalized-html-buildtag"
        elif source_name.endswith(".js") and source_name.startswith("telegram-web/js/"):
            if normalized_js(source) != normalized_js(built):
                raise ValueError("Stamped JS differs from accepted source: " + source_name)
            mode = "normalized-import-buildtag"
        else:
            if source != built:
                raise ValueError("Scoped file differs from accepted source: " + source_name)
            mode = "byte-exact"
        comparisons.append({"source": source_name, "target": candidate_name, "mode": mode, "acceptedSHA256": row["sha256"]})
    for name in APIS:
        if (site / name).read_bytes() != (ROOT / "telegram-web" / name).read_bytes():
            raise ValueError("API differs from current source: " + name)
    public_links = []
    def check_link(origin: str, value: str, require_tag=False):
        if value.startswith(("https:", "http:", "data:", "blob:", "#", "mailto:")):
            return
        file_value, _, query = value.partition("?")
        file_value = file_value.split("#", 1)[0]
        if not file_value:
            return
        local = (site / file_value.lstrip("/")).resolve() if file_value.startswith("/") else (site / PurePosixPath(origin).parent / file_value).resolve()
        if not local.is_relative_to(site) or not local.is_file():
            raise ValueError(f"Missing public link {origin}: {value}")
        if require_tag and query != "v=" + build_id:
            raise ValueError(f"Mixed import/style version {origin}: {value}")
        public_links.append({"origin": origin, "url": value})
    html = (site / "index.html").read_text(encoding="utf-8-sig")
    for value in re.findall(r"(?:src|href)=[\"']([^\"']+)[\"']", html):
        check_link("index.html", value, value.split("?", 1)[0].endswith((".js", ".css")))
    for js in (site / "js").glob("*.js"):
        text = js.read_text(encoding="utf-8-sig")
        origin = js.relative_to(site).as_posix()
        for value in re.findall(r"from ['\"]([^'\"]+)['\"]", text):
            check_link(origin, value, True)
        for value in re.findall(r"import\(['\"]([^'\"]+)['\"]\)", text):
            check_link(origin, value, True)
    for css in (site / "css").glob("*.css"):
        text = css.read_text(encoding="utf-8-sig")
        for value in re.findall(r"url\(['\"]?([^)'\"]+)['\"]?\)", text):
            check_link(css.relative_to(site).as_posix(), value.strip())
    for icon in pwa.get("icons", []):
        check_link("manifest.json", icon["src"])
    files = [{"path": p.relative_to(site).as_posix(), "bytes": p.stat().st_size, "sha256": digest(p.read_bytes())}
             for p in sorted(site.rglob("*")) if p.is_file()]
    if not all(allowed(entry["path"]) for entry in files):
        raise ValueError("Scoped paths escaped whitelist")
    scoped_manifest = {**{k: v for k, v in manifest.items() if k != "files"}, "artifact": "telegram-neon", "sourceFullRelease": full.name,
                       "sourceFullManifestSHA256": digest((full / "manifest.json").read_bytes()), "acceptedSourceProofSHA256": digest(accepted_file.read_bytes()), "files": files}
    write_json(destination / "manifest.json", scoped_manifest)
    archive = destination / ("untouch-telegram-neon-" + build_id + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zipped:
        for entry in files:
            zipped.write(site / entry["path"], entry["path"])
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None or set(zipped.namelist()) != {entry["path"] for entry in files}:
            raise ValueError("ZIP CRC/path mismatch")
        for entry in files:
            if digest(zipped.read(entry["path"])) != entry["sha256"]:
                raise ValueError("ZIP hash mismatch: " + entry["path"])
    if full_before != {name: digest((full / "site" / name).read_bytes()) for name in full_before}:
        raise ValueError("Source full release changed")
    proof = {"createdAt": datetime.now(timezone.utc).isoformat(), "artifact": "telegram-neon", "version": version, "buildId": build_id,
             "sourceRelease": str(full), "releasePath": str(destination), "archive": str(archive), "archiveSHA256": digest(archive.read_bytes()),
             "fileCount": len(files), "fullFileCount": len(full_before), "fullSiteUnchanged": True, "accepted95CurrentUnchanged": True,
             "apiExact": sorted(APIS), "dotfiles": [entry["path"] for entry in files if any(part.startswith(".") for part in PurePosixPath(entry["path"]).parts)],
             "normalizedComparisons": comparisons, "publicLinksChecked": public_links, "zipCRCAndSHA256": True, "excludedCount": len(full_before)-len(selected),
             "packagingRemaps": remaps, "standardBuilderDefect": "web/icons is nested in existing site/icons; four PWA icon links need derived-only path remap. Full release/runtime/builder untouched.",
             "limits": "Local packaging proof. No FTP, production writes, browser/device acceptance or pointer changes after standard builder."}
    write_json(destination / "packaging-verification.json", proof)
    print(json.dumps({k: proof[k] for k in ["releasePath", "buildId", "fileCount", "archive", "archiveSHA256", "fullSiteUnchanged"]}, ensure_ascii=False))

if __name__ == "__main__":
    main()
