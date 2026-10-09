#!/usr/bin/env python3
"""v5d automated local network test: one headless server + 2–3 headless clients (rooms + heartbeat).

Checks: both connect; positions replicate; legit movement needs no correction
and a speed hack is corrected by the server; chat is delivered (and rate
limited); a module pushed to the server reaches the clients and swaps in; a
poisoned module is rejected by the client (previous version kept); a client
disconnect leaves an avatar that walks to the cafe/home and townspeople visit
it; reconnecting restores the save from the server with a welcome-back; with
the server killed the client keeps playing and syncs when the server returns.

  python3 tools/net_test.py [--port 8931] [--keep]
Exit 0 = pass. Prints "NET TEST: N checks, F failed".
"""
from __future__ import annotations
import json, math, os, shutil, signal, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")
WORK = Path("/tmp/v7b1-net")
PORT = int(sys.argv[sys.argv.index("--port") + 1]) if "--port" in sys.argv else 8931
URL = "ws://127.0.0.1:%d" % PORT

checks: list[tuple[bool, str]] = []
procs: dict[str, subprocess.Popen] = {}
cmd_n = {"A": 0, "B": 0, "C": 0, "D": 0, "V": 0}
cmds = {"A": [], "B": [], "C": [], "D": [], "V": []}
HB_TIMEOUT = 20  # server drops a silent peer after 20 s (live clients send input at tick rate + pings)
MAX_PER_ROOM = 3  # server started with --max-per-room=3 so the "room full" path is exercised


def log(m: str) -> None:
    print(m, flush=True)


def check(ok: bool, msg: str) -> bool:
    checks.append((bool(ok), msg))
    log(("  [ok]   " if ok else "  [FAIL] ") + msg)
    return bool(ok)


def start_server() -> None:
    env = dict(os.environ, XDG_DATA_HOME=str(WORK / "home_srv"))
    f = open(WORK / "server.log", "a")
    procs["S"] = subprocess.Popen([GODOT, "--headless", "--path", str(ROOT), "res://scenes/server/Server.tscn", "--",
                                   "--server", "--port=%d" % PORT, "--bind=127.0.0.1", "--content=%s" % (WORK / "content"),
                                   "--data=%s" % (WORK / "srvdata"), "--health-port=%d" % (PORT + 1), "--max-per-room=%d" % MAX_PER_ROOM, "--heartbeat-timeout=%d" % HB_TIMEOUT], stdout=f, stderr=subprocess.STDOUT, env=env)
    wait(lambda: "SERVER READY" in (WORK / "server.log").read_text(errors="ignore"), 30, "server ready")


def start_client(cid: str, extra: list | None = None) -> None:
    env = dict(os.environ, XDG_DATA_HOME=str(WORK / ("home_" + cid)))
    f = open(WORK / ("client_%s.log" % cid), "a")
    st = WORK / ("status_%s.json" % cid)
    if st.exists():
        st.unlink()
    cmds[cid] = []
    write_ctl(cid)
    procs[cid] = subprocess.Popen([GODOT, "--headless", "--path", str(ROOT), "--", "--server-url=" + URL,
                                   "--net-test=" + cid, "--net-dir=" + str(WORK)] + (extra or []), stdout=f, stderr=subprocess.STDOUT, env=env)


def kill(name: str) -> None:
    p = procs.pop(name, None)
    if p and p.poll() is None:
        p.send_signal(signal.SIGKILL)
        p.wait(timeout=10)


def status(cid: str) -> dict:
    p = WORK / ("status_%s.json" % cid)
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}


def write_ctl(cid: str) -> None:
    tmp = WORK / ("ctl_%s.json.tmp" % cid)
    tmp.write_text(json.dumps({"cmds": cmds[cid]}))
    os.replace(tmp, WORK / ("ctl_%s.json" % cid))


def send(cid: str, op: str, **kw) -> None:
    cmd_n[cid] += 1
    cmds[cid].append(dict(n=cmd_n[cid], op=op, **kw))
    write_ctl(cid)


def wait(cond, timeout: float, what: str) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            if cond():
                return True
        except Exception:
            pass
        time.sleep(0.25)
    log("  (timed out after %.0fs waiting for %s)" % (timeout, what))
    return False


def dist(a, b) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[2] - b[2]) ** 2)


def server_save(guest_hint: str = "") -> list[dict]:
    out = []
    for p in sorted((WORK / "srvdata" / "saves").glob("*.json")):
        try:
            out.append(json.loads(p.read_text()))
        except Exception:
            pass
    return out


def money_on_server(guest: str) -> int:
    p = WORK / "srvdata" / "saves" / ("%s.json" % guest)
    try:
        return int(json.loads(p.read_text())["data"]["economy"]["money"])
    except Exception:
        return -1


def guest_of(cid: str) -> str:
    cfg = WORK / ("home_" + cid) / "godot" / "app_userdata"
    for p in cfg.rglob("settings.cfg"):
        for line in p.read_text().splitlines():
            if line.startswith("guest_id="):
                return line.split("=", 1)[1].strip().strip('"')
    return ""


def remote_of(viewer: str, other: str) -> dict:
    pid = str(status(other).get("pid", ""))
    return status(viewer).get("remotes", {}).get(pid, {})


def main() -> int:
    if WORK.exists():
        shutil.rmtree(WORK)
    (WORK / "content").mkdir(parents=True)
    t_start = time.time()
    try:
        log("== start server + two clients")
        start_server()
        start_client("A")
        start_client("B")
        ok = wait(lambda: status("A").get("state") == "online" and status("B").get("state") == "online", 90, "both online")
        check(ok, "both clients connect (A=%s, B=%s)" % (status("A").get("state"), status("B").get("state")))
        if not ok:
            return finish()
        check(wait(lambda: status("A").get("roster") == 2 and status("B").get("roster") == 2, 15, "rosters"), "both rosters list 2 players")
        check(wait(lambda: len(status("A").get("remotes", {})) == 1 and len(status("B").get("remotes", {})) == 1, 15, "avatars"),
              "each client draws the other player (with a name tag)")

        log("== positions replicate (A walks 2 s)")
        a0 = status("A")["pos"]
        send("A", "walk", dir=[1, 0], secs=2.0, speed=2.6)
        time.sleep(3.5)
        a1 = status("A")["pos"]
        seen = remote_of("B", "A").get("pos", [0, 0, 0])
        check(dist(a0, a1) > 3.0, "A moved %.1f m" % dist(a0, a1))
        check(dist(seen, a1) < 0.6, "B sees A where A is (error %.2f m)" % dist(seen, a1))
        check(status("A").get("corrections", 0) == 0, "legit walking needs no server correction (prediction ok)")
        b0 = status("B")["pos"]
        send("B", "walk", dir=[0, 1], secs=1.5, speed=2.6)
        time.sleep(3.0)
        check(dist(remote_of("A", "B").get("pos", [0, 0, 0]), status("B")["pos"]) < 0.6, "A sees B's new position")

        log("== server-authoritative movement (A speed hack 14 m/s)")
        c0 = status("A").get("corrections", 0)
        send("A", "walk", dir=[-1, 0], secs=1.2, speed=14.0)
        time.sleep(3.0)
        check(status("A").get("corrections", 0) > c0, "server clamps the speed hack and A is corrected (%d corrections)" % (status("A").get("corrections", 0) - c0))
        check(dist(remote_of("B", "A").get("pos", [0, 0, 0]), status("A")["pos"]) < 1.0, "after reconciliation B and A agree on A's position")

        log("== chat")
        send("A", "chat", text="سلام از A! hello")
        check(wait(lambda: any("سلام از A" in c[2] for c in status("B").get("chat", [])), 10, "chat at B"), "B receives A's chat (Persian text intact)")
        # The echo reaches A asynchronously (A's status file may lag B's by a frame or two): wait for it too.
        check(wait(lambda: any("سلام از A" in c[2] for c in status("A").get("chat", [])), 10, "echo at A"), "A sees its own message echoed by the server")
        for i in range(6):
            send("B", "chat", text="spam %d" % i)
        check(wait(lambda: any(c[0] == 0 for c in status("B").get("chat", [])), 10, "rate limit"), "server rate-limits a 6th message in 10 s")

        log("== live module push (wages: default wage 60 -> 99)")
        src = (ROOT / "modules/wages/fair_wages.tres").read_text(encoding="utf-8")
        new = src.replace("default_wage = 60", "default_wage = 99")
        mod = WORK / "fair_wages.tres"
        mod.write_text(new, encoding="utf-8")
        check(status("A").get("wages_default") == 60 and status("B").get("wages_default") == 60, "both start with wage 60")
        r = subprocess.run([sys.executable, str(ROOT / "tools/push_module.py"), "wages", "--file", str(mod), "--variant", "fair_wages",
                            "--content", str(WORK / "content"), "--skip-gate", "--reason", "net-test"], capture_output=True, text=True)
        log("   " + (r.stdout.strip().splitlines() or ["?"])[-1])
        check(r.returncode == 0, "push_module.py published wages")
        check(wait(lambda: status("A").get("wages_default") == 99 and status("B").get("wages_default") == 99, 20, "module swap"),
              "both clients downloaded wages and swapped it in live (wage 99)")
        check("wages" in status("B").get("installed", []), "update persisted on B (user://updates)")
        bad = WORK / "fair_wages_bad.tres"
        bad.write_text(new.replace("[resource]", '[sub_resource type="GDScript" id="x"]\nscript/source = "extends Node"\n\n[resource]'), encoding="utf-8")
        r = subprocess.run([sys.executable, str(ROOT / "tools/push_module.py"), "wages", "--file", str(bad), "--variant", "fair_wages",
                            "--content", str(WORK / "content"), "--skip-gate"], capture_output=True, text=True)
        check(r.returncode != 0 and "REFUSED" in r.stdout, "push_module.py refuses a module with an embedded script")
        r = subprocess.run([sys.executable, str(ROOT / "tools/push_module.py"), "wages", "--file", str(bad), "--variant", "fair_wages",
                            "--content", str(WORK / "content"), "--skip-gate", "--unchecked"], capture_output=True, text=True)
        check(wait(lambda: any(not u[2] for u in status("A").get("updates", [])), 20, "client reject"),
              "a poisoned module forced onto the server is rejected by the client")
        check(status("A").get("wages_default") == 99, "A kept the previous good version (wage 99)")
        # Publish a good version again so later joins don't keep trying the bad one.
        subprocess.run([sys.executable, str(ROOT / "tools/push_module.py"), "wages", "--file", str(mod), "--variant", "fair_wages",
                        "--content", str(WORK / "content"), "--skip-gate"], capture_output=True, text=True)

        log("== save sync + disconnect (B's phone dies)")
        guest_b = guest_of("B")
        send("B", "money", value=2468)
        send("B", "save_now")
        check(wait(lambda: money_on_server(guest_b) == 2468, 15, "B save on server"), "B's save (money 2468) is on the server (%s)" % guest_b)
        b_pid = str(status("B").get("pid"))
        b_last = status("B")["pos"]
        kill("B")
        check(wait(lambda: status("A").get("remotes", {}).get(b_pid, {}).get("status", "").startswith("away"), 15, "away"),
              "after B drops, A still sees B's avatar, now away (%s)" % status("A").get("remotes", {}).get(b_pid, {}).get("status"))
        p1 = status("A").get("remotes", {}).get(b_pid, {}).get("pos", b_last)
        time.sleep(4)
        p2 = status("A").get("remotes", {}).get(b_pid, {}).get("pos", b_last)
        check(dist(p1, p2) > 3.0, "the away avatar walks instead of freezing (%.1f m in 4 s)" % dist(p1, p2))
        dest = status("A").get("remotes", {}).get(b_pid, {}).get("dest", "")
        check(dest in ("cafe", "home"), "it walks to the %s" % dest)
        arrived = wait(lambda: status("A").get("remotes", {}).get(b_pid, {}).get("status", "") in ("away_sit", "away_home"), 70, "arrive")
        check(arrived, "the avatar arrives and sits down (%s)" % status("A").get("remotes", {}).get(b_pid, {}).get("status"))
        check(wait(lambda: len([e for e in status("A").get("events", []) if str(e[0]) == b_pid]) >= 2, 30, "visits"),
              "townspeople visit the away avatar (%s)" % [e[1:] for e in status("A").get("events", [])][:3])
        check(status("A").get("visits_started", 0) >= 1, "a townsperson walks over on A's screen (%d visits)" % status("A").get("visits_started", 0))
        check(wait(lambda: status("A").get("remotes", {}).get(b_pid, {}).get("teas", 0) >= 1, 30, "tea"), "tea is served at the avatar's table")

        log("== reconnect (B starts again with an empty game)")
        start_client("B")
        check(wait(lambda: status("B").get("state") == "online", 90, "B back"), "B reconnects")
        check(wait(lambda: status("B").get("money") == 2468, 15, "save restored"), "B's save is restored from the server (money %s)" % status("B").get("money"))
        w = status("B").get("welcome", {})
        check(float(w.get("seconds", 0)) > 10 and len(w.get("visits", [])) >= 1, "welcome back: away %.0f s, %d visits" % (float(w.get("seconds", 0)), len(w.get("visits", []))))
        check(status("B").get("away_memory") is True, "townspeople remember B was away (AwayMemory)")
        check(wait(lambda: all(r.get("status") == "active" for r in status("A").get("remotes", {}).values()) and len(status("A").get("remotes", {})) == 1, 15, "A roster"),
              "A sees B active again (no leftover away avatar)")
        check(status("B").get("wages_default") == 99, "B still has the pushed wages module after restarting (persisted)")

        
        log("== rooms: host creates code, B joins; positions sync; heartbeat")
        send("A", "create_room")
        ok = wait(lambda: str(status("A").get("room", {}).get("code", "")) not in ("", "MAIN"), 20, "A room code")
        code = str(status("A").get("room", {}).get("code", ""))
        check(ok and len(code) == 6, "A hosts a room and gets a 6-char code (%s)" % code)
        send("B", "join_room", code=code)
        check(wait(lambda: str(status("B").get("room", {}).get("code", "")) == code, 20, "B joined"),
              "B joins A's room by code")
        send("A", "walk", dir=[1, 0], secs=1.5, speed=2.6)
        time.sleep(3.0)
        check(dist(remote_of("B", "A").get("pos", [0, 0, 0]), status("A")["pos"]) < 0.8,
              "in the private room B still sees A's position")
        pings0 = int(status("A").get("pings", 0))
        send("A", "ping")
        check(wait(lambda: int(status("A").get("pings", 0)) > pings0 and float(status("A").get("rtt_ms", -1)) >= 0, 10, "pong"),
              "heartbeat ping/pong works (rtt %.1f ms)" % float(status("A").get("rtt_ms", -1)))
        send("A", "list_rooms")
        check(wait(lambda: any(str(r.get("code", "")) == code for r in status("A").get("room_list", [])), 10, "list"),
              "server list includes the hosted room")

        log("== third client joins the same room by code")
        start_client("C")
        check(wait(lambda: status("C").get("state") == "online", 90, "C online"), "C connects")
        send("C", "join_room", code=code)
        check(wait(lambda: str(status("C").get("room", {}).get("code", "")) == code, 20, "C joined"),
              "C joins the same room by code (3 players)")
        check(wait(lambda: int(status("A").get("room", {}).get("players", 0)) >= 3, 15, "room size"),
              "room reports >= 3 players")
        log("== max players per room (%d): a 4th client is refused but stays online" % MAX_PER_ROOM)
        start_client("D")
        check(wait(lambda: status("D").get("state") == "online", 90, "D online"), "D connects (public room)")
        send("D", "join_room", code=code)
        check(wait(lambda: status("D").get("room_error") == "room full", 20, "room full"),
              "D joining the full room (%d/%d) gets 'room full' (%s)" % (int(status("A").get("room", {}).get("players", 0)), MAX_PER_ROOM, status("D").get("room_error")))
        time.sleep(1.0)
        check(status("D").get("state") == "online" and str(status("D").get("room", {}).get("code", "")) != code,
              "D stays online in its own room (%s, room %s)" % (status("D").get("state"), status("D").get("room", {}).get("code")))
        check(int(status("A").get("room", {}).get("players", 0)) <= MAX_PER_ROOM, "the full room never exceeds %d players" % MAX_PER_ROOM)
        send("D", "join_room", code="ZZZZZ9")
        check(wait(lambda: status("D").get("room_error") == "unknown room" and status("D").get("state") == "online", 20, "unknown"),
              "a wrong code gets 'unknown room' without dropping the connection")
        log("== heartbeat timeout: D freezes (SIGSTOP), server drops it, D resumes and reconnects")
        d_pid = int(status("D").get("pid", 0))
        procs["D"].send_signal(signal.SIGSTOP)
        check(wait(lambda: ("heartbeat timeout pid %d" % d_pid) in (WORK / "server.log").read_text(errors="ignore"), HB_TIMEOUT + 25, "hb drop"),
              "server drops the silent peer after the heartbeat timeout (pid %d)" % d_pid)
        procs["D"].send_signal(signal.SIGCONT)
        check(wait(lambda: status("D").get("state") == "online" and int(status("D").get("pid", 0)) not in (0, d_pid), 90, "D back"),
              "D resumes and reconnects automatically with a new session (pid %s)" % status("D").get("pid"))
        check(status("A").get("state") == "online", "active clients were not dropped by the heartbeat check")
        kill("D")
        kill("C")

        log("== /health endpoint + version mismatch")
        import urllib.request
        try:
            body = urllib.request.urlopen("http://127.0.0.1:%d/health" % (PORT + 1), timeout=5).read().decode()
            hj = json.loads(body)
        except Exception as e:
            hj = {"error": str(e)}
        check(hj.get("ok") is True and int(hj.get("players", 0)) >= 2, "server /health answers 200 JSON (%s)" % hj)
        start_client("V", ["--fake-version=1.0.0"])
        check(wait(lambda: "version mismatch" in (WORK / "server.log").read_text(errors="ignore") or "version mismatch" in (WORK / "client_V.log").read_text(errors="ignore"), 60, "mismatch"),
              "an incompatible old client (1.0.0) is refused with 'version mismatch'")
        check(wait(lambda: status("V").get("state") in ("offline", "unreachable", ""), 20, "V offline"),
              "the refused client keeps playing offline (%s)" % status("V").get("state"))
        kill("V")


        log("== server killed: A keeps playing offline, then syncs")
        guest_a = guest_of("A")
        send("A", "money", value=4321)
        send("A", "save_now")
        check(wait(lambda: money_on_server(guest_a) == 4321, 15, "A save"), "A's money 4321 synced while online")
        kill("S")
        check(wait(lambda: status("A").get("state") == "unreachable", 20, "A unreachable"), "A notices the server is gone (offline indicator)")
        f0 = status("A").get("frames", 0)
        pa = status("A")["pos"]
        send("A", "walk", dir=[0, -1], secs=1.5, speed=2.6)
        send("A", "money", value=5555)
        time.sleep(3.0)
        check(status("A").get("frames", 0) > f0 + 60 and dist(pa, status("A")["pos"]) > 2.0, "A keeps playing locally (walked %.1f m)" % dist(pa, status("A")["pos"]))
        send("A", "save_now")
        check(wait(lambda: status("A").get("has_local_save") is True, 10, "local save"), "offline progress is saved locally")
        check(money_on_server(guest_a) == 4321, "server still has the old copy while it is down")
        start_server()
        check(wait(lambda: status("A").get("state") == "online", 60, "A reconnect"), "A reconnects automatically when the server returns")
        check(wait(lambda: money_on_server(guest_a) == 5555, 20, "sync"), "A's offline progress (money 5555) synced to the server (newest wins)")
        check(status("A").get("money") == 5555, "A kept its newer local money (not overwritten by the older server copy)")
        log("server log tail:")
        for line in (WORK / "server.log").read_text(errors="ignore").splitlines()[-8:]:
            log("   " + line)
    finally:
        for n in list(procs):
            kill(n)
        log("elapsed %.0f s" % (time.time() - t_start))
    return finish()


def finish() -> int:
    failed = [m for ok, m in checks if not ok]
    log("NET TEST: %d checks, %d failed" % (len(checks), len(failed)))
    for m in failed:
        log("  failed: " + m)
    log("NET TEST PASSED" if not failed else "NET TEST FAILED")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
