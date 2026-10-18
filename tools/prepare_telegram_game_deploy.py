"""ResumeBackup-compatible local preparation from a verified dated game snapshot.

Remote operations are read-only metadata/identity checks. No upload, deletion,
directory creation or old-file download occurs here. The caller runs deployment.
"""
from datetime import datetime, timezone
import ftplib
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import ssl
import urllib.request
import zipfile

WORKSPACE = Path(__file__).resolve().parents[1]
ORIGIN = "https://untouch.ballaball.xyz/"
ROOT_FILES = {"index.html", ".htaccess", "release.json", "version.json", "manifest.json", "favicon.png", "i.php"}
APIS = {"api/scores.php", "api/tg_common.php", "api/mobile_store.php"}

def _hash(file):
    return hashlib.sha256(Path(file).read_bytes()).hexdigest()

def _load(file):
    return json.loads(Path(file).read_text(encoding="utf-8-sig"))

def _safe_name(name):
    if not isinstance(name, str) or not name or "\\" in name or "\x00" in name or "\r" in name or "\n" in name:
        raise ValueError("Unsafe release/snapshot path")
    p = PurePosixPath(name)
    if p.is_absolute() or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError("Unsafe release/snapshot path")
    return name

def _candidate_allowed(name):
    _safe_name(name)
    return name in ROOT_FILES or name in APIS or (PurePosixPath(name).parts[0] in {"js", "css", "config", "icons", "assets"} and name != "assets/branding/landing" and not name.startswith("assets/branding/landing/"))

def _rows(manifest, directory, allow_identical_case_aliases=False):
    result = {}
    for row in manifest["files"]:
        name = _safe_name(row["path"])
        if name in result or not isinstance(row["bytes"], int) or row["bytes"] < 0 or not re.fullmatch(r"[a-f0-9]{64}", row["sha256"]):
            raise ValueError("Invalid file manifest: " + name)
        file = directory / name
        if file.is_symlink() or not file.resolve().is_relative_to(directory.resolve()) or not file.is_file() or file.stat().st_size != row["bytes"] or _hash(file) != row["sha256"]:
            raise ValueError("Local manifest integrity failure: " + name)
        result[name] = row
    actual = {file.relative_to(directory).as_posix() for file in directory.rglob("*") if file.is_file()}
    if allow_identical_case_aliases:
        groups = {}
        for name, row in result.items():
            groups.setdefault(name.casefold(), []).append(row)
        aliases = [rows for rows in groups.values() if len(rows) > 1]
        for rows in aliases:
            if len({(row["bytes"], row["sha256"]) for row in rows}) != 1:
                raise ValueError("Snapshot case aliases have different bytes/SHA")
        expected_aliases = sorted(tuple(sorted(row["path"] for row in rows)) for rows in aliases)
        declared = manifest.get("identicalCaseAliases", [])
        if not isinstance(declared, list) or any(not isinstance(group, list) or len(group) < 2 for group in declared):
            raise ValueError("Snapshot case alias declaration invalid")
        declared_aliases = sorted(tuple(sorted(_safe_name(name) for name in group)) for group in declared)
        if declared_aliases != expected_aliases:
            raise ValueError("Snapshot case alias groups do not match manifest")
        if {name.casefold() for name in actual} != set(groups) or len(actual) != len(groups):
            raise ValueError("Snapshot physical case-folded inventory differs")
    elif actual != set(result):
        raise ValueError("Site contains files outside its manifest")
    return result

def _connect(credentials, root):
    context = ssl.create_default_context()
    context.minimum_version = context.maximum_version = ssl.TLSVersion.TLSv1_2
    client = ftplib.FTP_TLS(context=context, timeout=30)
    try:
        client.connect(credentials["host"], int(credentials.get("port", 21)))
        client.auth()
        client.login(credentials["user"], credentials["password"])
        client.prot_p()
        client.cwd(root)
        client.voidcmd("TYPE I")
        return client
    except Exception:
        client.close()
        raise

def _public_identity(nonce):
    request = urllib.request.Request(ORIGIN + "release.json?predeploy=" + nonce,
        headers={"Cache-Control": "no-cache", "Accept-Encoding": "identity"})
    with urllib.request.urlopen(request, timeout=25) as response:
        raw = response.read(16385)
    if len(raw) > 16384:
        raise ValueError("Unexpected public identity length")
    return json.loads(raw.decode("utf-8-sig"))

def _verify_source(snapshot, record):
    if record.get("state") != "local-and-FTP-complete" or record.get("artifact") != "telegram-rollback" or record.get("ftpArchiveVerified") is not True or record.get("httpAccessDenied") is not True:
        raise ValueError("Snapshot is not an independently verified local/private-FTP backup")
    label = record.get("requestedDate", "")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", label):
        raise ValueError("Snapshot requested-date label missing")
    datetime.strptime(label, "%Y-%m-%d")
    stamps = []
    for field in ["startedAt", "completedAt", "finishedAt"]:
        stamp = datetime.fromisoformat(record[field])
        if stamp.tzinfo is None:
            raise ValueError("Snapshot timezone missing")
        stamps.append(stamp)
    if stamps != sorted(stamps) or record.get("timezone") != "Europe/Minsk":
        raise ValueError("Snapshot chronology/timezone mismatch")
    archive_name = record.get("archive", "")
    archive_match = re.fullmatch(re.escape(f"telegram-before-neon-{label}") + r"(?:-verified-(\d{8}_\d{6}_\d{6}))?\.zip", archive_name)
    remote_dir = record.get("remoteDirectory", "")
    if not archive_match or not remote_dir.startswith(f"/.backups/telegram-before-neon-{label}_") or record.get("ftpArchive") != remote_dir + "/" + archive_name or (archive_match.group(1) and not remote_dir.endswith("_" + archive_match.group(1))):
        raise ValueError("Snapshot dated archive/private FTP label mismatch")
    identity = _load(snapshot / "site" / "release.json")
    if identity != record["oldIdentity"] or identity.get("buildId") != record.get("buildId") or identity.get("version") != record.get("version"):
        raise ValueError("Snapshot original game identity mismatch")
    records = _rows(record, snapshot / "site", allow_identical_case_aliases=True)
    if not {"index.html", "release.json", *APIS}.issubset(records):
        raise ValueError("Snapshot lacks original client/profile files")
    archive = snapshot / _safe_name(record["archive"])
    if not archive.is_file() or archive.stat().st_size != record["archiveBytes"] or _hash(archive) != record["archiveSha256"]:
        raise ValueError("Snapshot ZIP SHA/length failure")
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None:
            raise ValueError("Snapshot ZIP CRC failure")
        site_entries = [name for name in zipped.namelist() if name.startswith("site/") and not name.endswith("/")]
        if len(site_entries) != len(records) or set(site_entries) != {"site/" + name for name in records}:
            raise ValueError("Snapshot ZIP must preserve every logical path exactly once")
        for name, row in records.items():
            if hashlib.sha256(zipped.read("site/" + name)).hexdigest() != row["sha256"]:
                raise ValueError("Snapshot ZIP original file mismatch: " + name)
    return records, identity, archive

def prepare(credentials, root, release, snapshot):
    """Return a new predeploy-UTC directory usable by --resume-backup.

    Validation fails before creating predeploy if old server facts/identity drift,
    or an unbacked candidate path now exists. FTP 550 is never proof of absence.
    """
    release, snapshot = Path(release).resolve(), Path(snapshot).resolve()
    releases = (WORKSPACE / "releases").resolve()
    if root != "/" or release.parent != releases or snapshot.parent != releases or release == snapshot:
        raise ValueError("Expected separate scoped release and snapshot under releases/, root /")
    source = _load(snapshot / "manifest.json")
    candidate = _load(release / "manifest.json")
    if source.get("remoteRoot") != root or candidate.get("artifact") != "telegram-neon" or not release.name.startswith("telegram-neon-"):
        raise ValueError("Snapshot remote root/scoped artifact mismatch")
    source_manifest_hash = _hash(snapshot / "manifest.json")
    candidate_manifest_hash = _hash(release / "manifest.json")
    old, old_identity, archive = _verify_source(snapshot, source)
    new = _rows(candidate, release / "site")
    if not all(_candidate_allowed(name) for name in new) or {name for name in new if name.startswith("api/")} != APIS:
        raise ValueError("Scoped release exceeds approved client/three-API paths")
    identity = _load(release / "site" / "release.json")
    if identity.get("buildId") != candidate.get("buildId") or identity.get("version") != candidate.get("version") or identity.get("artifact") != "telegram-neon":
        raise ValueError("Candidate game identity mismatch")
    began = datetime.now(timezone.utc)
    facts_rechecked = []
    listings = {}
    client = None
    def drop_client():
        nonlocal client
        if client is not None:
            try:
                client.close()
            except (OSError, EOFError):
                pass
            client = None

    def read_only(operation, fresh=False):
        nonlocal client
        if fresh:
            drop_client()
        for attempt in range(3):
            try:
                if client is None:
                    client = _connect(credentials, root)
                return operation(client)
            except (OSError, EOFError, ftplib.error_temp):
                drop_client()
                if attempt == 2:
                    raise

    try:
        for name, row in sorted(old.items()):
            if not re.fullmatch(r"\d{14}(?:\.\d+)?", row.get("modify", "")):
                raise ValueError("Snapshot modify timestamp missing: " + name)
            # Retry the complete pair on a fresh verified TLS connection; a
            # successful SIZE followed by dropped MDTM is not a partial proof.
            size, response = read_only(lambda connection: (connection.size(name), connection.sendcmd("MDTM " + name)))
            if not response.startswith("213 "):
                raise ValueError("Unexpected MDTM response: " + name)
            modify = response[4:].strip()
            if size != row["bytes"] or modify != row["modify"]:
                raise ValueError("Published snapshot file changed: " + name)
            facts_rechecked.append({"path": name, "bytes": size, "modify": modify, "checkedAt": datetime.now(timezone.utc).isoformat()})

        def listing(directory):
            if directory not in listings:
                rows = {}
                # Permission/network errors propagate; never convert 550 to [] .
                # This host can drop its control connection after data listings.
                # Start a fresh session and materialize the entire MLSD result
                # before caching it. 550/ValueError are intentionally not retried.
                entries = read_only(lambda connection: list(connection.mlsd(directory)), fresh=True)
                for name, facts in entries:
                    if facts.get("type") in ("cdir", "pdir"):
                        continue
                    _safe_name(name)
                    if "/" in name or name in rows:
                        raise ValueError("Unsafe/duplicate FTP listing entry")
                    rows[name] = facts
                listings[directory] = rows
            return listings[directory]

        absence_facts = []
        for name in sorted(set(new) - set(old)):
            parts = PurePosixPath(name).parts
            directory = ""
            for index, part in enumerate(parts):
                entries = listing(directory)
                if part not in entries:
                    absence_facts.append({"path": name, "missingComponent": part, "verifiedParent": directory or "/", "checkedAt": datetime.now(timezone.utc).isoformat()})
                    break
                if index == len(parts) - 1:
                    raise ValueError("Candidate path appeared without snapshot backup: " + name)
                if entries[part].get("type") != "dir":
                    raise ValueError("Candidate ancestor is not a directory: " + name)
                directory = directory + "/" + part if directory else part
        nonce = began.strftime("%Y%m%d_%H%M%S_%f")
        if _public_identity(nonce) != old_identity:
            raise ValueError("Public old game identity changed")
    finally:
        drop_client()
    verified_at = datetime.now(timezone.utc)
    if _hash(snapshot / "manifest.json") != source_manifest_hash or _hash(release / "manifest.json") != candidate_manifest_hash or _hash(archive) != source["archiveSha256"]:
        raise ValueError("Source snapshot/candidate changed during verification")
    _rows(source, snapshot / "site", allow_identical_case_aliases=True)
    _rows(candidate, release / "site")
    backup = release / ("predeploy-" + verified_at.strftime("%Y%m%d_%H%M%S_%f"))
    backup.mkdir(exist_ok=False)
    existing, absent, unchanged = sorted(set(new) & set(old)), sorted(set(new) - set(old)), []
    for name in existing:
        target = backup / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(snapshot / "site" / name, target)
        if _hash(target) != old[name]["sha256"]:
            raise ValueError("Copied predeploy original differs: " + name)
        if old[name]["sha256"] == new[name]["sha256"]:
            unchanged.append(name)
    record = {"buildId": candidate["buildId"], "remoteRoot": root, "existing": existing, "absent": absent, "unchanged": unchanged,
        "uploaded": [], "state": "backup-complete", "changedOnly": False, "untouchedBaselineFiles": [],
        "sourceSnapshot": str(snapshot), "sourceSnapshotManifestSHA256": source_manifest_hash, "sourceSnapshotArchiveSHA256": source["archiveSha256"],
        "sourceRequestedDate": source["requestedDate"], "sourceOldIdentity": old_identity, "sourceSnapshotState": source["state"],
        "createdAt": verified_at.isoformat(), "recheckStartedAt": began.isoformat(), "recheckCompletedAt": verified_at.isoformat(),
        "snapshotFactsRechecked": facts_rechecked, "absentFactsRechecked": absence_facts, "publicOldIdentityRechecked": True,
        "candidateManifestSHA256": candidate_manifest_hash, "oldSHA256": {name: old[name]["sha256"] for name in existing},
        "notes": "Existing candidate originals copied from verified dated snapshot after SIZE/MDTM-all-files, MLSD-ancestor absence and public identity recheck. No remote writes or redundant old-file downloads."}
    (backup / "deployment.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    zipped_path = backup.with_suffix(".zip")
    with zipfile.ZipFile(zipped_path, "x", zipfile.ZIP_DEFLATED) as zipped:
        for file in sorted(backup.rglob("*")):
            if file.is_file():
                zipped.write(file, file.relative_to(backup).as_posix())
    with zipfile.ZipFile(zipped_path) as zipped:
        if zipped.testzip() is not None or set(zipped.namelist()) != {*existing, "deployment.json"}:
            raise ValueError("Predeploy ZIP CRC/path failure")
        for name in existing:
            if hashlib.sha256(zipped.read(name)).hexdigest() != old[name]["sha256"]:
                raise ValueError("Predeploy ZIP old-file SHA failure")
    if _hash(snapshot / "manifest.json") != source_manifest_hash or _hash(release / "manifest.json") != candidate_manifest_hash:
        raise ValueError("Source metadata changed during preparation")
    print("Resume backup prepared:", backup, flush=True)
    print("Predeploy ZIP SHA256:", _hash(zipped_path), flush=True)
    return backup
