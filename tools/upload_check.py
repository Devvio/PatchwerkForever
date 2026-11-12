"""Try upload.py against a pretend CurseForge on this machine. Nothing is sent anywhere else.

    python upload_check.py

Starts a small web server on 127.0.0.1 that answers as CurseForge's upload API does, points upload.py
at it with made-up project ids and a made-up token, and looks at what arrives: the token's header, the
description of the file, the zip itself. Also: no token, no id, a game version CurseForge does not
list, a tag that does not match, an address that is not https, and a dry run that must send nothing.

It needs the addons to be committed (upload.py will not send a zip built from uncommitted files).
"""
import email
import io
import json
import os
import subprocess
import sys
import tempfile
import threading
import zipfile
from http.server import BaseHTTPRequestHandler, HTTPServer

from release import PROJECTS, toc

HERE = os.path.dirname(os.path.abspath(__file__))
TOKEN = "made-up-token-for-the-check"
SEEN = []
VERSIONS = [{"id": 501, "gameVersionTypeID": 1, "name": "1.60.0", "slug": "1-60-0"},
            {"id": 502, "gameVersionTypeID": 1, "name": "1.60.1", "slug": "1-60-1"},
            {"id": 77, "gameVersionTypeID": 9, "name": "11.2.0", "slug": "11-2-0"}]


class Pretend(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, code, value):
        body = json.dumps(value).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        SEEN.append(("GET", self.path, self.headers.get("X-Api-Token"), None, None))
        if self.headers.get("X-Api-Token") != TOKEN:
            return self.answer(403, {"errorMessage": "bad token"})
        if self.path == "/api/game/versions":
            return self.answer(200, self.server.versions)
        self.answer(404, {})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        # the form's parts, read as a mail message's are
        message = email.message_from_bytes(b"Content-Type: " + self.headers.get("Content-Type").encode() + b"\r\n\r\n" + raw)
        parts = {p.get_param("name", header="content-disposition"): p for p in message.get_payload()}
        metadata = json.loads(parts["metadata"].get_payload(decode=True))
        SEEN.append(("POST", self.path, self.headers.get("X-Api-Token"), metadata,
                     (parts["file"].get_filename(), parts["file"].get_payload(decode=True))))
        if self.headers.get("X-Api-Token") != TOKEN:
            return self.answer(403, {"errorMessage": "bad token"})
        self.answer(200, {"id": 424242})


def run(args, env, expect=0):
    r = subprocess.run([sys.executable, "upload.py"] + args, cwd=HERE, capture_output=True, text=True, env=env)
    print(">>> upload.py " + " ".join(args))
    for line in (r.stdout + r.stderr).rstrip().splitlines():
        if "zipped" not in line and "release" + os.sep not in line and "checklist" not in line:
            print("    " + line)
    assert TOKEN not in r.stdout + r.stderr, "the token was printed"
    assert (r.returncode == 0) == (expect == 0), (r.returncode, expect)
    return r.stdout + r.stderr


def main():
    server = HTTPServer(("127.0.0.1", 0), Pretend)
    server.versions = VERSIONS
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % server.server_port

    scratch = tempfile.mkdtemp(prefix="patchwerk-upload-check-")
    cfg_path = os.path.join(scratch, "curseforge.json")

    def write_config(**change):
        cfg = {"api": base, "game_version": "", "game_version_ids": [],
               "projects": {"patchwerk": {"id": 1001, "slug": "patchwerk-forever"},
                            "consoleport": {"id": 1002, "slug": "pf-stitch-console-port",
                                            "relations": [{"slug": "console-port", "type": "requiredDependency"}]},
                            "routes": {"id": 1005, "slug": "pf-thread-routes"},
                            "sparkle": {"id": 0, "slug": ""}}}
        cfg.update(change)
        json.dump(cfg, open(cfg_path, "w"))

    write_config()
    env = dict(os.environ, CF_CONFIG=cfg_path, CF_API_TOKEN=TOKEN)
    env.pop("CF_API_BASE", None)

    print("a dry run: says what would go, sends nothing")
    out = run(["--dry-run", "routes"], dict(env, CF_API_TOKEN=""))
    assert "NOT SENT" in out and not SEEN, SEEN

    print("no token: refused before anything is built or sent")
    out = run(["routes"], dict(env, CF_API_TOKEN=""), expect=1)
    assert "no token" in out and not SEEN

    print("the route planner: its zip, its changelog entry, beta, Forever's version, the base as a dependency")
    out = run(["routes"], env)
    assert "uploaded: CurseForge's file id is 424242" in out, out
    get, post = SEEN[-2], SEEN[-1]
    assert get[:3] == ("GET", "/api/game/versions", TOKEN)
    assert post[1] == "/api/projects/1005/upload-file" and post[2] == TOKEN
    meta, (name, data) = post[3], post[4]
    version = toc("PatchwerkForever_Thread_Routes")[0]["Version"]
    assert meta["displayName"] == "Patchwerk Forever: Thread (Routes) " + version, meta["displayName"]
    assert meta["releaseType"] == "beta" and meta["changelogType"] == "markdown" and meta["gameVersions"] == [502], meta
    assert meta["relations"] == {"projects": [{"slug": "patchwerk-forever", "type": "requiredDependency"}]}, meta
    assert meta["changelog"].strip() and "## " not in meta["changelog"], "the changelog is not one entry"
    assert name == "PatchwerkForever_Thread_Routes-%s.zip" % version
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        assert z.testzip() is None
        tops = sorted({n.split("/")[0] for n in z.namelist()})
        assert tops == sorted(["PatchwerkForever_Thread_Routes"] + PROJECTS["routes"]["more"]), tops
        main_toc = z.read("PatchwerkForever_Thread_Routes/PatchwerkForever_Thread_Routes.toc").decode()
        assert "## X-Curse-Project-ID: 1005" in main_toc and "## X-Build:" in main_toc, main_toc[:400]
        data_toc = z.read("PatchwerkForever_Thread_Routes_Kalimdor/PatchwerkForever_Thread_Routes_Kalimdor.toc").decode()
        assert "X-Curse-Project-ID" not in data_toc, "a map data folder was given a project number"
    print("    the zip arrived whole: %d bytes, %d folders, project number in its TOC" % (len(data), len(tops)))

    print("a Stitch, by its tag: a release, with the base and the addon it is for as dependencies")
    tag = "stitch-consoleport-" + toc("PatchwerkForever_Stitch_ConsolePort")[0]["Version"]
    run(["--tag", tag], env)
    meta = SEEN[-1][3]
    assert SEEN[-1][1] == "/api/projects/1002/upload-file" and meta["releaseType"] == "release"
    assert [r["slug"] for r in meta["relations"]["projects"]] == ["patchwerk-forever", "console-port"], meta["relations"]

    before = len(SEEN)
    print("a tag that does not match the version, and a project with no id: refused")
    assert "does not match" in run(["--tag", "thread-routes-9.9.9"], env, expect=1)
    assert "has no id" in run(["sparkle"], env, expect=1)
    assert len(SEEN) == before

    print("a game version CurseForge does not list: stops and shows the ones like it")
    server.versions = [v for v in VERSIONS if v["name"] != "1.60.1"]
    out = run(["routes"], env, expect=1)
    assert "game_version_ids" in out and "1.60.0" in out and SEEN[-1][0] == "GET"
    write_config(game_version_ids=[501])
    run(["routes"], env)
    assert SEEN[-1][3]["gameVersions"] == [501]
    server.versions = VERSIONS

    print("an address that is not https: the token is not sent")
    before = len(SEEN)
    out = run(["routes"], dict(env, CF_API_BASE="http://example.invalid"), expect=1)
    assert "not https" in out and len(SEEN) == before

    print("the wrong token: CurseForge's refusal is passed on")
    out = run(["routes"], dict(env, CF_API_TOKEN="another-made-up-one"), expect=1)
    assert "said no" in out and "403" in out

    print("listing the game versions")
    out = run(["versions", "1.60"], env)
    assert "1.60.1" in out and "11.2.0" not in out

    server.shutdown()
    os.remove(cfg_path)
    os.rmdir(scratch)
    # The zips built above carry the made-up project numbers: build them again with the real settings.
    clean = dict(os.environ)
    clean.pop("CF_CONFIG", None)
    subprocess.run([sys.executable, "release.py", "routes", "consoleport"], cwd=HERE, check=True, capture_output=True, env=clean)
    for key in ("routes", "consoleport"):
        main_folder = PROJECTS[key]["main"]
        path = os.path.join(HERE, "..", "release", main_folder, "%s-%s.zip" % (main_folder, toc(main_folder)[0]["Version"]))
        with zipfile.ZipFile(path) as z:
            text = z.read("%s/%s.toc" % (main_folder, main_folder)).decode()
        assert "X-Curse-Project-ID: 100" not in text, "a made-up project number was left in " + path
    # the real settings file was not touched, and has no ids yet or only numbers
    real = json.load(open(os.path.join(HERE, "curseforge.json"), encoding="utf-8"))
    assert set(real["projects"]) == set(PROJECTS), "tools/curseforge.json does not list every project"
    print("all upload checks passed")


if __name__ == "__main__":
    main()
