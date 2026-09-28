#!/usr/bin/env python3
import hashlib
import json
import sys
from pathlib import Path

ALLOWED_DEVICES = {"dre", "DE2117"}
ALLOWED_ROLES = {"boot", "vendor_boot", "recovery", "firmware", "rom"}


def validate_record(record: dict, project_root: Path) -> list[str]:
    errors: list[str] = []
    required = {"name", "path", "sha256", "device", "role", "source_url"}
    missing = sorted(required - record.keys())
    if missing:
        errors.append("missing fields: " + ", ".join(missing))
        return errors

    if record["device"] not in ALLOWED_DEVICES:
        errors.append("device must be dre or DE2117")
    if record["role"] not in ALLOWED_ROLES:
        errors.append("role is not allowed")
    if not isinstance(record["source_url"], str) or not record["source_url"].startswith("https://"):
        errors.append("source_url must use https")

    root = project_root.resolve()
    path = (root / str(record["path"])).resolve()
    try:
        path.relative_to(root)
    except ValueError:
        errors.append("path leaves project root")
        return errors

    if not path.is_file():
        errors.append("artifact is missing")
        return errors

    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != record["sha256"]:
        errors.append("sha256 mismatch")
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: verify_artifact.py METADATA.json", file=sys.stderr)
        return 2
    metadata_path = Path(argv[1]).resolve()
    data = json.loads(metadata_path.read_text())
    records = data["artifacts"] if isinstance(data, dict) else data
    failed = False
    for record in records:
        name = str(record.get("name", "<unnamed>"))
        errors = validate_record(record, metadata_path.parent.parent)
        if errors:
            failed = True
            for error in errors:
                print(f"{name}: {error}", file=sys.stderr)
        else:
            print(f"{name}: verified")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
