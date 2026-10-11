import asyncio, base64, time, sys, shutil
from pathlib import Path
from playwright.async_api import async_playwright
URL = sys.argv[1]; OUT = sys.argv[2]; WAIT = int(sys.argv[3]) if len(sys.argv) > 3 else 22000
async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which("chromium") or shutil.which("google-chrome"), headless=True, args=[
            "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
            "--enable-webgl", "--use-gl=angle", "--no-sandbox", "--autoplay-policy=user-gesture-required"])
        logs = []
        page = await browser.new_page(viewport={"width": 834, "height": 1194}, has_touch=True, is_mobile=True, user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15")
        t0 = time.time()
        page.on("console", lambda m: logs.append((round(time.time()-t0,1), m.type, m.text)))
        page.on("pageerror", lambda e: logs.append((round(time.time()-t0,1), "pageerror", str(e))))
        sockets = []
        foreign = []
        pack_requests = []
        page.on("request", lambda r: pack_requests.append(r.url) if "/asset-packs/" in r.url and ".pck" in r.url else None)
        page.on("websocket", lambda w: sockets.append(w.url))
        page.on("request", lambda r: foreign.append(r.url) if not r.url.startswith(URL.rstrip("/")) and not r.url.startswith("data:") and not r.url.startswith("blob:") else None)
        await page.goto(URL, wait_until="load")
        await page.wait_for_timeout(WAIT)
        menu_packs = len(pack_requests)
        print("asset pack downloads before Play (must be 0):", menu_packs)
        async def enter_game():
            # v7b.1 entry flow (splash -> menu -> Play -> Single-player -> loading):
            # Enter skips the splash / presses the default button until the game logs it is in.
            await page.mouse.click(5, 5)  # focus the canvas on an empty corner
            await page.wait_for_timeout(400)
            for _ in range(8):
                if any("ENTRY: in game" in l[2] for l in logs[mark[0]:]):
                    return True
                await page.keyboard.press("Enter")
                await page.wait_for_timeout(900)
            deadline = time.time() + 90
            while time.time() < deadline and not any("ENTRY: in game" in l[2] for l in logs[mark[0]:]):
                await page.wait_for_timeout(500)
            return any("ENTRY: in game" in l[2] for l in logs[mark[0]:])
        mark = [0]
        async def wait_player_model():
            deadline = time.time() + 90
            while time.time() < deadline and not any("CHARACTER MODEL: player ready" in l[2] for l in logs[mark[0]:]):
                await page.wait_for_timeout(500)
            return any("CHARACTER MODEL: player ready" in l[2] for l in logs[mark[0]:])
        entered1 = await enter_game()
        model1 = await wait_player_model()
        print("entry flow -> single-player:", entered1, "player model ready:", model1)
        session = await page.context.new_cdp_session(page)
        async def touch(points, kind):
            await session.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": points})
        await touch([{"x":150,"y":994,"id":0},{"x":525,"y":994,"id":1}], "touchStart")
        await touch([{"x":150,"y":1090,"id":0},{"x":625,"y":930,"id":1}], "touchMove")
        await page.wait_for_timeout(2000)
        # Stop camera rotation while both fingers remain held: continued look
        # produces a circular path, making net displacement misleading.
        await touch([{"x":150,"y":1090,"id":0},{"x":525,"y":994,"id":1}], "touchMove")
        await page.wait_for_timeout(5000)
        await touch([], "touchEnd")
        await page.wait_for_timeout(1000)
        moves = [l[2] for l in logs if "TouchControls: left stick released, player moved" in l[2]]
        touch_ok = any(float(m.split("player moved ")[1].split(" m")[0]) > 0.5 for m in moves)
        print("iPad desktop identity, two-finger movement:", touch_ok, moves)
        await session.detach()
        await page.set_viewport_size({"width":1194,"height":834})
        deadline = time.time() + 30
        while time.time() < deadline and not any("TOUCH VIEWPORT: 1280x720" in l[2] for l in logs):
            await page.wait_for_timeout(500)
        print("touch render diagnostics:", [l[2] for l in logs if "TOUCH " in l[2]])
        rotation_ok = any("TOUCH VIEWPORT: 1280x720" in l[2] for l in logs) and any("TOUCH VIEWPORT: 720x1280" in l[2] for l in logs)
        print("portrait and landscape rendering bounds:", rotation_ok)
        await page.set_viewport_size({"width":834,"height":1194})
        await page.wait_for_timeout(1500)
        await page.mouse.click(320, 180)
        await page.keyboard.down("KeyW"); await page.wait_for_timeout(1200); await page.keyboard.up("KeyW")
        await page.wait_for_timeout(5000)
        async def capture(path):
            # Snapshot the current compositor surface without waiting for a new
            # WebGL frame, which can starve on software-only rendering hosts.
            session = await page.context.new_cdp_session(page)
            result = await asyncio.wait_for(session.send("Page.captureScreenshot", {
                "format": "png", "fromSurface": False, "captureBeyondViewport": False}), 45)
            Path(path).write_bytes(base64.b64decode(result["data"]))
            await session.detach()
        await capture(OUT)
        errs = [l for l in logs if l[1] in ("error", "pageerror")
                and "AudioWorklet" not in l[2] and "AudioContext" not in l[2]
                and "ALSA" not in l[2]]
        print("console errors:", len(errs), "| messages:", len(logs))
        for l in errs: print("   ", l)
        for l in logs[:12]: print("    log:", l)
        pack_keys = {l[2].split("mounted ", 1)[1].strip() for l in logs if "ASSET PACK: mounted " in l[2]}
        packs_ok = {"world", "male", "hair", "animations"}.issubset(pack_keys)
        print("demand-loaded packs mounted:", sorted(pack_keys))
        print("touch frame cap 30:", any("TOUCH FRAME CAP: 30" in l[2] for l in logs))
        await browser.close()
        ok = menu_packs == 0 and packs_ok and entered1 and model1 and touch_ok and rotation_ok and any("TOUCH FRAME CAP: 30" in l[2] for l in logs) and not errs and not sockets and not foreign
        print("IPAD BROWSER:", "PASS" if ok else "FAIL")
        sys.exit(0 if ok else 1)
asyncio.run(main())
