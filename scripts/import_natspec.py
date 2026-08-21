#!/usr/bin/env python3
"""Copy forge-doc NatSpec pages into docs/api/ for HonKit."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / ".natspec" / "src"
DEST = ROOT / "docs" / "api"

LINK_RE = re.compile(
    r"\]\((?:/?[^)\s]*?/)?(?:contract|interface)\.([^)/]+)\.md\)"
)
FENCE_RE = re.compile(r"^```solidity\s*$", re.MULTILINE)

CONTRACTS = [
    ("CcaLaunchFactory", "Create UERC20 + CCA/LBP launch"),
    ("InviteRegistry", "Invite codes and participation"),
    ("InviteValidationHook", "CCA bid gate (hookData)"),
    ("ReferrerNFT", "Transferable distributor claim NFT"),
    ("LaunchFeeHook", "Post-migrate swap hook fee"),
    ("FeeDistributor", "Claimable 20/75/5 fee split"),
    ("IReferralSource", "NFT tier-weight interface"),
]


def flatten_name(path: Path) -> str | None:
    name = path.name
    if name.startswith("contract.") or name.startswith("interface."):
        return name.split(".", 1)[1]
    return None


def rewrite(text: str) -> str:
    text = LINK_RE.sub(r"](\1.md)", text)
    return FENCE_RE.sub("```", text)


def main() -> int:
    if not SRC.is_dir():
        print(f"Missing {SRC} — run forge doc first", file=sys.stderr)
        return 1

    DEST.mkdir(parents=True, exist_ok=True)
    copied = 0
    for path in SRC.rglob("*.md"):
        dest_name = flatten_name(path)
        if dest_name is None:
            continue
        (DEST / dest_name).write_text(rewrite(path.read_text()), encoding="utf-8")
        copied += 1

    rows = "\n".join(
        f"| [{name}]({name}.md) | {blurb} |" for name, blurb in CONTRACTS
    )
    (DEST / "README.md").write_text(
        f"""# API Reference

NatSpec generated from `src/` via `forge doc`.

| Contract | Role |
|---|---|
{rows}
""",
        encoding="utf-8",
    )

    missing = [name for name, _ in CONTRACTS if not (DEST / f"{name}.md").exists()]
    if missing:
        print(f"Missing NatSpec pages: {', '.join(missing)}", file=sys.stderr)
        return 1

    print(f"==> Imported {copied} NatSpec pages into docs/api/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
