#!/usr/bin/env python3
"""Send test frames to HUD Egg for protocol verification.

Frames (all 1024 bytes, SSD130x page layout):
- checkerboard (8x8 squares)
- left-half-white / right-half-black
- full-white (brownout test — run on USB first, then battery)
- wrong-length (must be ignored, screen unchanged)

Display is mounted VERTICALLY (portrait). Frames are rotated 90 CW
before send so they appear correct on the physical OLED.
Set ROTATE=0 to disable (for landscape mount).

Usage:
    python tools/send_test_frames.py [IP]
    Default IP: 192.168.1.27 (from boot logs) or hud.local
"""
import asyncio
import sys

try:
    import websockets
except ImportError:
    print("Missing dependency: pip install websockets")
    sys.exit(1)

WIDTH, HEIGHT = 128, 64
FRAME_BYTES = 1024
ROTATE = 0  # Hardware rotation (U8G2_R90) handles vertical mount. No software rotation.

def make_frame(pixel_fn):
    """Build 1024-byte frame from pixel function (x,y)->bool."""
    buf = bytearray(FRAME_BYTES)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if pixel_fn(x, y):
                page = y // 8
                bit = y % 8
                buf[page * WIDTH + x] |= (1 << bit)
    return bytes(buf)

def rotate90_cw(data):
    """Rotate 128x64 frame 90 CW within the 128x64 canvas (center-cropped)."""
    # Decode to pixels
    pixels = [[False]*WIDTH for _ in range(HEIGHT)]
    for y in range(HEIGHT):
        for x in range(WIDTH):
            page = y // 8
            bit = y % 8
            pixels[y][x] = (data[page * WIDTH + x] >> bit) & 1 == 1
    # Rotate: (x,y) -> (H-1-y, x)
    out = [[False]*WIDTH for _ in range(HEIGHT)]
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if pixels[y][x]:
                nx = HEIGHT - 1 - y
                ny = x
                if 0 <= nx < WIDTH and 0 <= ny < HEIGHT:
                    out[ny][nx] = True
    # Encode
    buf = bytearray(FRAME_BYTES)
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if out[y][x]:
                page = y // 8
                bit = y % 8
                buf[page * WIDTH + x] |= (1 << bit)
    return bytes(buf)

def maybe_rotate(data):
    if ROTATE == 90:
        return rotate90_cw(data)
    return data

def checkerboard():
    return maybe_rotate(make_frame(lambda x, y: ((x // 8) + (y // 8)) % 2 == 0))

def half():
    return maybe_rotate(make_frame(lambda x, y: x < WIDTH // 2))

def full_white():
    return maybe_rotate(bytes([0xFF] * FRAME_BYTES))

def full_black():
    return maybe_rotate(bytes([0x00] * FRAME_BYTES))

async def send_frame(ws, data, label):
    await ws.send(data)
    print(f"Sent {label}: {len(data)} bytes")

async def main():
    ip = sys.argv[1] if len(sys.argv) > 1 else "192.168.1.27"
    url = f"ws://{ip}:81"
    print(f"Connecting to {url} ... (rotate={ROTATE}°)")
    try:
        async with websockets.connect(url) as ws:
            print("Connected. Sending test frames...")
            await send_frame(ws, checkerboard(), "checkerboard")
            await asyncio.sleep(2)
            await send_frame(ws, half(), "half (left-white)")
            await asyncio.sleep(2)
            await send_frame(ws, full_white(), "full-white")
            await asyncio.sleep(2)
            await send_frame(ws, b"\x00" * 100, "wrong-length (100 bytes, must be ignored)")
            await asyncio.sleep(2)
            await send_frame(ws, full_black(), "full-black")
            print("Done. Verify on OLED: checkerboard correct, half correct, white full, wrong-length ignored, black full.")
            print("Idle test: wait 30s with no frames — screen should sleep. Next frame wakes instantly.")
    except Exception as e:
        print(f"Failed: {e}")
        print(f"Check: HUD Egg powered, on same 2.4GHz WiFi, IP {ip} reachable.")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
