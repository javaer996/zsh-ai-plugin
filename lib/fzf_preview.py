#!/usr/bin/env python3
"""Decode encoded commands for fzf preview."""

import base64
import sys


def main() -> int:
    if len(sys.argv) < 3:
        return 0

    file_path = sys.argv[1]
    selection = sys.argv[2]
    idx = selection.split('.', 1)[0].strip()
    if not idx.isdigit():
        return 0

    encoded = None
    try:
        with open(file_path, 'r', encoding='utf-8') as handle:
            for line in handle:
                parts = line.rstrip('\n').split('\t', 1)
                if len(parts) == 2 and parts[0] == idx:
                    encoded = parts[1]
                    break
    except OSError:
        return 0

    if not encoded:
        return 0

    try:
        decoded = base64.b64decode(encoded).decode('utf-8')
    except Exception:
        return 0

    sys.stdout.write(decoded)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
