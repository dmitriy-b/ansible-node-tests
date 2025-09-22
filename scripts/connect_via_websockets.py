import asyncio
from web3 import AsyncWeb3
from web3.providers import WebSocketProvider    # v7+ provider

WS_URL = "ws://localhost:8545"                  # your local node

async def main():
    # AsyncWeb3 is itself an async-context-manager when given a
    # PersistentConnectionProvider such as WebSocketProvider.
    async with AsyncWeb3(WebSocketProvider(WS_URL)) as w3:
        sub_id = await w3.eth.subscribe("newHeads")      # real-time blocks
        print("subscription id:", sub_id)

        # In v7 the stream lives under w3.socket.*
        async for msg in w3.socket.process_subscriptions():
            print("new block header →", msg)

asyncio.run(main())