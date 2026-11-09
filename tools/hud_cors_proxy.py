#!/usr/bin/env python3
"""
CORS WebSocket proxy for HUD Egg.

Forwards ws://localhost:8081/ws -> ws://192.168.1.27:81 with CORS headers.
Optional helper for the web build. WebSockets are NOT subject to CORS, so a
browser tab served from http://localhost can normally connect straight to
ws://<hud-ip>:81. The real browser limits are: (1) an https:// page cannot open
a ws:// socket (mixed content) and (2) browsers cannot do mDNS (hud.local
discovery), so use the IP. Use this proxy only if the page is served over
https or the direct connection is blocked.

Usage:
    python tools/hud_cors_proxy.py [HUD_IP] [PROXY_PORT]

Defaults:
    HUD_IP = 192.168.1.27
    PROXY_PORT = 8081

The web app connects to ws://localhost:8081/ws (or your PC's LAN IP).
The proxy forwards to ws://<HUD_IP>:81.
"""
import asyncio
import sys
from aiohttp import web

HUD_HOST = sys.argv[1] if len(sys.argv) > 1 else "192.168.1.27"
HUD_PORT = 81
PROXY_PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8081


async def websocket_handler(request):
    """Proxy WebSocket messages between browser and HUD Egg."""
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    import aiohttp

    async with aiohttp.ClientSession() as session:
        async with session.ws_connect(f"ws://{HUD_HOST}:{HUD_PORT}") as hud_ws:
            # Relay messages both ways
            async def client_to_hud():
                async for msg in ws:
                    if msg.type == aiohttp.WSMsgType.BINARY:
                        await hud_ws.send_bytes(msg.data)
                    elif msg.type == aiohttp.WSMsgType.TEXT:
                        await hud_ws.send_str(msg.data)
                    elif msg.type == aiohttp.WSMsgType.CLOSE:
                        await hud_ws.close()
                        break

            async def hud_to_client():
                async for msg in hud_ws:
                    if msg.type == aiohttp.WSMsgType.BINARY:
                        await ws.send_bytes(msg.data)
                    elif msg.type == aiohttp.WSMsgType.TEXT:
                        await ws.send_str(msg.data)
                    elif msg.type == aiohttp.WSMsgType.CLOSE:
                        await ws.close()
                        break

            await asyncio.gather(client_to_hud(), hud_to_client())

    return ws


async def options_handler(request):
    """Handle CORS preflight OPTIONS requests."""
    return web.Response(
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "86400",
        }
    )


async def index_handler(request):
    return web.Response(
        text=f"EDITH HUD CORS Proxy\nProxying ws://localhost:{PROXY_PORT}/ws -> ws://{HUD_HOST}:{HUD_PORT}\n",
        content_type="text/plain",
    )


app = web.Application()
app.router.add_get("/", index_handler)
app.router.add_get("/ws", websocket_handler)
app.router.add_options("/ws", options_handler)

if __name__ == "__main__":
    print(f"EDITH HUD CORS Proxy starting on port {PROXY_PORT}")
    print(f"  Proxy:  ws://localhost:{PROXY_PORT}/ws")
    print(f"  Target: ws://{HUD_HOST}:{HUD_PORT}")
    print()
    print("In the EDITH app, set HUD WebSocket URL to:")
    print(f"  ws://<your-pc-lan-ip>:{PROXY_PORT}/ws")
    print()
    web.run_app(app, host="0.0.0.0", port=PROXY_PORT)
