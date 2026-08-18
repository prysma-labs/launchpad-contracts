#!/usr/bin/env python3
"""Sign fixture X tokens for the Anvil creator (account #0)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB_ENV = ROOT.parent / "launchpad" / "web" / ".env.local"
OUT = ROOT / "deployments" / "anvil-x-extras.json"
CREATOR = os.environ.get(
    "ANVIL_CREATOR",
    "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
)

# handle, user_id, avatar, wallet (None = ANVIL creator)
FIXTURES = {
    "punks": ("uneebagh", "69832154", None, None),
    "megapot": (
        "uneebagh",
        "69832154",
        "https://pbs.twimg.com/profile_images/2081802220605980672/2ERTQR1q_bigger.jpg",
        None,
    ),
    "prysma": ("prysmaHQ", "1962206370071220224", None, None),
    "virtuoso": ("virtuoso_club", "1664456225176670210", None, None),
    "loot": ("lootgenie", "1838988064234020864", None, None),
    "maxmarket": (
        "_maxtalks",
        "1875602263114387456",
        "https://pbs.twimg.com/profile_images/1899943050362970114/bOFt7r-I_bigger.jpg",
        "0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735",
    ),
}


def load_secret() -> str:
    if not WEB_ENV.exists():
        raise SystemExit(f"missing {WEB_ENV}")
    for line in WEB_ENV.read_text().splitlines():
        if line.startswith("X_VERIFICATION_SECRET="):
            return line.split("=", 1)[1].strip().strip("'\"")
    raise SystemExit("X_VERIFICATION_SECRET missing in launchpad/web/.env.local")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def sign_token(secret: str, payload: dict) -> str:
    payload_b64 = b64url(json.dumps(payload, separators=(",", ":")).encode())
    sig = b64url(
        hmac.new(secret.encode(), payload_b64.encode(), hashlib.sha256).digest()
    )
    return f"{payload_b64}.{sig}"


def main() -> None:
    secret = load_secret()
    extras = {}
    for key, (handle, user_id, avatar, wallet) in FIXTURES.items():
        token = sign_token(
            secret,
            {
                "x_handle": handle,
                "x_user_id": user_id,
                "wallet_address": wallet or CREATOR,
                "iat": 1,
            },
        )
        extras[key] = json.dumps(
            {
                "v": 1,
                "xVerificationToken": token,
                "xAvatarUrl": avatar or f"https://unavatar.io/twitter/{handle}",
            },
            separators=(",", ":"),
        )
    OUT.write_text(json.dumps(extras, indent=2) + "\n")
    print("wrote", OUT.relative_to(ROOT), "for", CREATOR)


if __name__ == "__main__":
    main()
