#!/usr/bin/env python3
"""Downloads the effect recordings already published on the docs site, so the site can be rebuilt
(new web demos, new page code) without re-recording every effect in the simulator.

Usage: scripts/mirror_media.py catalog.json media/ [base-url]
Fetches media/<id>.<lang>.mp4 and .jpg for every effect in the catalog. A file the site does not have
(404) is skipped: the page falls back to posters or placeholders. Any other failure (throttling,
network) is retried and, if it persists, fails the script, so a deploy never drops published media.
"""
import concurrent.futures
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://alanfeiyuchang.github.io/motionary-ios-animations/media"


def fetch(url, path):
    """Returns "cached", "ok", "missing" (the site answered 404) or "failed …" (anything else, after retries)."""
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return "cached"
    error = None
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=60) as response:
                data = response.read()
            with open(path, "wb") as f:
                f.write(data)
            return "ok"
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return "missing (404)"
            error = e  # 429 / 5xx: the host is throttling or flaky, so wait and try again
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            error = e
        time.sleep(1.5 * (attempt + 1))
    return f"failed ({error})"


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        sys.exit(2)
    catalog_path, media_dir = sys.argv[1:3]
    base = sys.argv[3] if len(sys.argv) == 4 else BASE
    with open(catalog_path, encoding="utf-8") as f:
        catalog = json.load(f)
    os.makedirs(media_dir, exist_ok=True)
    jobs = []
    for effect in catalog["effects"]:
        for lang in ("zh", "en"):
            for ext in (".mp4", ".jpg"):
                name = f"{effect['id']}.{lang}{ext}"
                jobs.append((f"{base}/{name}", os.path.join(media_dir, name)))
    counts = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for status in pool.map(lambda job: fetch(*job), jobs):
            key = status.split(" ")[0]
            counts[key] = counts.get(key, 0) + 1
    print(f"Media mirror: {len(jobs)} files — " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    # A file that exists on the site but could not be fetched must not be dropped from the next deploy:
    # fail, so the workflow stops before publishing a site without it.
    if counts.get("failed"):
        print(f"error: {counts['failed']} published files could not be downloaded", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
