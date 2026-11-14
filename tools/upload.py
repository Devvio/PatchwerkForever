"""Upload a project's zip to CurseForge, through CurseForge's upload API.

    python upload.py routes                    build Thread (Routes) and upload it
    python upload.py consoleport melloui       several, one after the other
    python upload.py all                       every project, in the order of release/UPLOAD.md
    python upload.py --tag thread-routes-0.11.0   the project that tag is for (this is what CI runs)
    python upload.py --dry-run routes          everything but the sending: says what would be sent
    python upload.py --test patchwerk          the same upload, sent to your test project instead
    python upload.py --as alpha all            every project as an alpha file, to be promoted by hand
    python upload.py versions [text]           the game versions CurseForge knows, to find Forever's

What it needs:

    the token   Your CurseForge API token. You make one in your CurseForge author settings (API Tokens)
                and put it in the file .env at the top of this repository, as CF_API_TOKEN=... (copy
                .env.example; git ignores .env), or in the environment variable CF_API_TOKEN, which wins
                when both are there. It is never printed and never committed. In CI it is a secret of
                the same name.
    the ids     tools/curseforge.json: each project's number (shown on its CurseForge page as Project ID)
                and its slug (the last part of its page's address). A project has to be made by hand on
                CurseForge first: the API only adds files to a project that is there. "test_project"
                there is the number of a project of yours kept for trying uploads: with --test a
                project's file goes to it and not to the project's own page, and nothing else differs
                (the zip is the one that would go to the real project, its own number in its TOC).

What it sends for a project: the zip release.py builds; the changelog entry for that version; a
display name ("Patchwerk Forever: Thread (Routes) 0.11.0"); beta for a version beginning 0., else
release; the game version; and Patchwerk Forever as a required dependency where the addon needs it.
--as alpha (or beta, or release) sets the release type for everything in that run, whatever the
version: a file held back as alpha is not offered to people on the release channel, and its type is
changed on its CurseForge page when it is to go out.

It will not upload a zip built from files that are not committed, a project with no id, or to an
address that is not https. Nothing here is run by itself: an upload happens only when this is asked for.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid

from release import ADDONS, ORDER, OUT, PROJECTS, TAGS, build, commit, toc

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.environ.get("CF_CONFIG") or os.path.join(HERE, "curseforge.json")
ENV_FILE = os.environ.get("CF_ENV_FILE") or os.path.join(HERE, "..", ".env")
DEFAULT_API = "https://wow.curseforge.com"


def config():
    with open(CONFIG, encoding="utf-8") as f:
        return json.load(f)


def api_base(cfg):
    base = (os.environ.get("CF_API_BASE") or cfg.get("api") or DEFAULT_API).rstrip("/")
    local = re.match(r"^http://(127\.0\.0\.1|localhost)(:\d+)?$", base)
    if not (base.startswith("https://") or local):
        sys.exit("the address %s is not https: the token is not sent to it" % base)
    return base


def filed_token():
    """The token as the .env file gives it, or "". Only the CF_API_TOKEN line is read: nothing else in
    the file is used, and nothing from it is put into the environment of what this runs."""
    try:
        with open(ENV_FILE, encoding="utf-8-sig") as f:      # (-sig: Notepad may put a mark before the first line)
            lines = f.read().splitlines()
    except OSError:
        return ""
    for line in lines:
        line = line.strip()
        if line.startswith("export "):
            line = line[7:].lstrip()
        name, sep, value = line.partition("=")
        if sep and name.strip() == "CF_API_TOKEN":
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1].strip()
            return value
    return ""


def token():
    value = os.environ.get("CF_API_TOKEN", "").strip() or filed_token()
    if not value:
        sys.exit("no token: put your CurseForge API token (author settings, API Tokens) in %s as "
                 "CF_API_TOKEN=..., or in the environment variable CF_API_TOKEN." % os.path.normpath(ENV_FILE))
    return value


def call(base, path, data=None, content_type=None):
    """One request to the API. Returns what it answers, read as JSON."""
    request = urllib.request.Request(base + path, data=data, method="POST" if data is not None else "GET")
    request.add_header("X-Api-Token", token())
    request.add_header("User-Agent", "addon-upload-script")
    request.add_header("Accept", "application/json")
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=120) as answer:
            body = answer.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        sys.exit("CurseForge said no to %s (%d %s): %s" % (path, e.code, e.reason, body[:600]))
    except urllib.error.URLError as e:
        sys.exit("could not reach %s: %s" % (base, e.reason))
    try:
        return json.loads(body)
    except ValueError:
        sys.exit("CurseForge's answer to %s was not understood: %s" % (path, body[:300]))


def version_name(interface):
    """The game version a TOC's interface number stands for: 16001 is 1.60.1."""
    n = int(interface)
    return "%d.%d.%d" % (n // 10000, n // 100 % 100, n % 100)


def game_versions(base, cfg, interface):
    """The ids of the game version to file the upload under."""
    if cfg.get("game_version_ids"):
        return [int(i) for i in cfg["game_version_ids"]]
    name = cfg.get("game_version") or version_name(interface)
    known = call(base, "/api/game/versions")
    found = [v for v in known if str(v.get("name")) == name]
    if len(found) == 1:
        return [found[0]["id"]]
    print("CurseForge lists %d game versions named \"%s\". Ones like it:" % (len(found), name))
    for v in sorted(known, key=lambda v: str(v.get("name"))):
        if name.rsplit(".", 1)[0] in str(v.get("name")) or v in found:
            print("  id %-7s type %-6s %s" % (v.get("id"), v.get("gameVersionTypeID"), v.get("name")))
    sys.exit("put the right one's id in tools/curseforge.json as \"game_version_ids\": [id], or its name as "
             "\"game_version\". python upload.py versions <text> lists them.")


def changelog(main, version):
    """The entry for a version in an addon's CHANGELOG.md, without its heading."""
    text = open(os.path.join(ADDONS, main, "CHANGELOG.md"), encoding="utf-8").read().replace("\r\n", "\n")
    m = re.search(r"^## %s\b[^\n]*\n(.*?)(?=^## |\Z)" % re.escape(version), text, re.M | re.S)
    if not m:
        sys.exit("%s has no changelog entry for %s" % (main, version))
    return m.group(1).strip() + "\n"


def multipart(fields, file_name, file_bytes):
    boundary = "----upload" + uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (boundary, name, value)).encode("utf-8"))
    parts.append(("--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n"
                  "Content-Type: application/zip\r\n\r\n" % (boundary, file_name)).encode("utf-8"))
    parts.append(file_bytes)
    parts.append(("\r\n--%s--\r\n" % boundary).encode("utf-8"))
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def upload(key, cfg, send, test=False, kind=None):
    project = PROJECTS[key]
    main = project["main"]
    entry = cfg.get("projects", {}).get(key, {})
    target = entry.get("id")
    if test:
        target = cfg.get("test_project")
        if not target:
            sys.exit("--test needs a test project: put its Project ID in %s as \"test_project\"" % CONFIG)
    elif not target:
        sys.exit("%s has no id in %s: make the project on CurseForge, then put its Project ID and slug there" % (key, CONFIG))
    relations = []
    for need in project["requires"]:
        need_key = [k for k, p in PROJECTS.items() if p["main"] == need][0]
        slug = cfg.get("projects", {}).get(need_key, {}).get("slug")
        if not slug:
            sys.exit("%s needs %s, whose slug is not in %s" % (key, need_key, CONFIG))
        relations.append({"slug": slug, "type": "requiredDependency"})
    relations += entry.get("relations", [])              # (others of yours: the addon a Stitch is for)

    if not build(key):
        sys.exit("%s was not built, so it was not uploaded" % key)
    fields = toc(main)[0]
    version = fields["Version"]
    mark = commit([main] + project["more"])
    if not mark or mark.endswith("+"):
        sys.exit("%s was built from files that are not committed: commit first, so what is uploaded is what is kept" % key)
    path = os.path.join(OUT % main, "%s-%s.zip" % (main, version))
    with open(path, "rb") as f:
        data = f.read()

    base = api_base(cfg)
    metadata = {
        "changelog": changelog(main, version),
        "changelogType": "markdown",
        "displayName": "%s %s" % (fields.get("Title", main), version),
        "releaseType": kind or ("beta" if version.startswith("0.") else "release"),
    }
    if relations:
        metadata["relations"] = {"projects": relations}
    print("%s -> %s %s at %s" % (os.path.basename(path), "the TEST project" if test else "project", target, base))
    print("  %s, %s, %d bytes, built from %s" % (metadata["displayName"], metadata["releaseType"], len(data), mark))
    print("  needs: %s" % (", ".join("%s (%s)" % (r["slug"], r["type"]) for r in relations) or "nothing"))
    print("  changelog: %d lines, beginning \"%s\"" % (metadata["changelog"].count("\n"), metadata["changelog"].splitlines()[0][:70]))
    if not send:
        print("  game version: %s (looked up when it is sent)" % (cfg.get("game_version_ids") or cfg.get("game_version")
                                                                   or version_name(fields["Interface"])))
        print("  NOT SENT (--dry-run)")
        return
    metadata["gameVersions"] = game_versions(base, cfg, fields["Interface"])
    print("  game version id(s): %s" % metadata["gameVersions"])
    body, content_type = multipart({"metadata": json.dumps(metadata)}, os.path.basename(path), data)
    answer = call(base, "/api/projects/%s/upload-file" % target, body, content_type)
    print("  uploaded: CurseForge's file id is %s. It shows on the project once CurseForge has approved it." % answer.get("id"))


def main():
    args = sys.argv[1:]
    send = True
    test = False
    kind = None
    keys = []
    if not args:
        sys.exit(__doc__)
    cfg = config()
    if args[0] == "versions":
        text = " ".join(args[1:]).lower()
        for v in sorted(call(api_base(cfg), "/api/game/versions"), key=lambda v: (v.get("gameVersionTypeID") or 0, str(v.get("name")))):
            if text in str(v.get("name")).lower() or text in str(v.get("slug", "")).lower():
                print("id %-7s type %-6s %-14s %s" % (v.get("id"), v.get("gameVersionTypeID"), v.get("name"), v.get("slug", "")))
        return
    while args:
        a = args.pop(0)
        if a == "--dry-run":
            send = False
        elif a == "--test":
            test = True
        elif a == "--as":
            if not args or args[0] not in ("alpha", "beta", "release"):
                sys.exit("--as needs a release type: alpha, beta or release")
            kind = args.pop(0)
        elif a == "--tag":
            if not args:
                sys.exit("--tag needs a tag")
            tag = args.pop(0)
            found = [k for k, prefix in TAGS.items() if tag.startswith(prefix + "-")]
            if not found:
                sys.exit("%s is not a release tag (they begin: %s)" % (tag, ", ".join(sorted(TAGS.values()))))
            key = max(found, key=lambda k: len(TAGS[k]))
            version = toc(PROJECTS[key]["main"])[0]["Version"]
            if tag != "%s-%s" % (TAGS[key], version):
                sys.exit("the tag %s does not match %s's version, %s" % (tag, key, version))
            keys.append(key)
        elif a == "all":
            keys += ORDER
        elif a in PROJECTS:
            keys.append(a)
        else:
            sys.exit("not understood: %s (projects: %s; also all, versions, --tag <tag>, --dry-run, --test, --as <type>)" % (a, ", ".join(sorted(PROJECTS))))
    if send:
        token()                                           # (say so before any building, when it is missing)
    for key in keys:
        upload(key, cfg, send, test, kind)


if __name__ == "__main__":
    main()
