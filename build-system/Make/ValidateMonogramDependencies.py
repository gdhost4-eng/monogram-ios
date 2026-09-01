#!/usr/bin/env python3
"""Checks direct Bazel dependencies for Monogram Swift modules before a build."""

from pathlib import Path
import sys


MODULES = {
    "MonogramCore": "//submodules/MonogramCore:MonogramCore",
    "MonogramUI": "//submodules/MonogramUI:MonogramUI",
}


def enclosing_build_file(source: Path, root: Path) -> Path | None:
    directory = source.parent
    while directory != root:
        build_file = directory / "BUILD"
        if build_file.is_file():
            return build_file
        directory = directory.parent
    return None


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    errors: list[str] = []

    for source in root.rglob("*.swift"):
        source_parts = source.relative_to(root).parts
        if any(part.startswith(".") or part == "Tests" for part in source_parts):
            continue
        text = source.read_text(encoding="utf-8")
        imported = {
            line.removeprefix("import ").strip()
            for line in text.splitlines()
            if line.startswith("import ")
        }
        required = imported.intersection(MODULES)
        if not required:
            continue

        build_file = enclosing_build_file(source, root)
        if build_file is None:
            errors.append(f"{source.relative_to(root)}: no enclosing BUILD file")
            continue
        build_text = build_file.read_text(encoding="utf-8")
        for module in sorted(required):
            if MODULES[module] not in build_text:
                errors.append(
                    f"{source.relative_to(root)} imports {module}, but "
                    f"{build_file.relative_to(root)} lacks {MODULES[module]}"
                )

    if errors:
        print("Monogram Bazel dependency validation failed:", file=sys.stderr)
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Monogram Bazel dependency validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
