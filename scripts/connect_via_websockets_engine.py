import asyncio
from web3 import AsyncWeb3
from web3.providers import WebSocketProvider    # v7+ provider

import base64, hashlib, hmac, json, time, pathlib
import asyncio, json
from websockets import connect

JWT_SECRET = pathlib.Path("local-deployment/jwtsecret").read_text().strip()

def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

def make_engine_jwt(secret_hex: str) -> str:
    secret = bytes.fromhex(secret_hex)
    header  = _b64url(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64url(json.dumps({"iat": int(time.time())}, separators=(",",":")).encode())
    signing_input = f"{header}.{payload}".encode()
    sig = _b64url(hmac.new(secret, signing_input, digestmod=hashlib.sha256).digest())
    return f"{header}.{payload}.{sig}"

WS_URL = "ws://127.0.0.1:8551"
JWT     = make_engine_jwt(JWT_SECRET)

async def main() -> None:
    headers = {"Authorization": f"Bearer {JWT}"}
    async with connect(WS_URL, additional_headers=headers, max_size=None) as ws:
        # Example Engine API call: engine_exchangeCapabilities
        req = {"jsonrpc":"2.0","id":1,
               "method":"engine_exchangeCapabilities",
               "params":[[]]}
        await ws.send(json.dumps(req))
        print("▶ sent", req)

        reply = await ws.recv()
        print("◀ got ", reply)

asyncio.run(main())