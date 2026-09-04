#!/usr/bin/env python3
"""Receive byte-identical web artifacts into one explicitly allowed directory."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8771)
    args = parser.parse_args()

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    class Handler(BaseHTTPRequestHandler):
        server_version = "ExactWebAssetReceiver/1.0"

        def do_OPTIONS(self) -> None:  # noqa: N802
            self.send_response(204)
            self._cors_headers()
            self.end_headers()

        def do_POST(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            prefix = "/upload/"
            if not parsed.path.startswith(prefix):
                self._reply(404, {"ok": False, "error": "unknown endpoint"})
                return

            filename = unquote(parsed.path[len(prefix) :])
            if not filename or filename != Path(filename).name:
                self._reply(400, {"ok": False, "error": "invalid filename"})
                return

            try:
                length = int(self.headers.get("Content-Length", ""))
            except ValueError:
                self._reply(411, {"ok": False, "error": "invalid content length"})
                return
            if length < 1 or length > 64 * 1024 * 1024:
                self._reply(413, {"ok": False, "error": "invalid payload size"})
                return

            expected = self.headers.get("X-Expected-Sha256", "").strip().upper()
            if len(expected) != 64 or any(c not in "0123456789ABCDEF" for c in expected):
                self._reply(400, {"ok": False, "error": "missing expected SHA-256"})
                return

            payload = self.rfile.read(length)
            actual = hashlib.sha256(payload).hexdigest().upper()
            if actual != expected:
                self._reply(
                    422,
                    {"ok": False, "error": "SHA-256 mismatch", "actual": actual},
                )
                return

            target = (output_dir / filename).resolve()
            if target.parent != output_dir:
                self._reply(400, {"ok": False, "error": "target escapes output dir"})
                return

            fd, temp_name = tempfile.mkstemp(prefix=f".{filename}.", dir=output_dir)
            try:
                with os.fdopen(fd, "wb") as handle:
                    handle.write(payload)
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(temp_name, target)
            finally:
                if os.path.exists(temp_name):
                    os.unlink(temp_name)

            self._reply(
                201,
                {
                    "ok": True,
                    "name": filename,
                    "bytes": len(payload),
                    "sha256": actual,
                    "path": str(target),
                },
            )

        def log_message(self, format: str, *args: object) -> None:
            print(format % args, flush=True)

        def _cors_headers(self) -> None:
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Expected-Sha256")
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")

        def _reply(self, status: int, payload: dict[str, object]) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self._cors_headers()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(
        json.dumps(
            {"host": args.host, "port": args.port, "output_dir": str(output_dir)},
            ensure_ascii=False,
        ),
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
