
import asyncio
import aiohttp
import time

REQUESTS = 8192
URL = "http://localhost:8080/"

EXPECTED_BODY = "<html><body><h1>CORE CHALLENGE</h1></body></html>"

async def fetch(session, i):
    try:
        async with session.get(URL) as response:
            text = await response.text()
            if response.status == 200 and EXPECTED_BODY in text:
                return True
            else:
                print(text)
                return False
    except Exception as e:
        return False

async def main():
    async with aiohttp.ClientSession() as session:
        tasks = [fetch(session, i) for i in range(REQUESTS)]
        start = time.time()
        results = await asyncio.gather(*tasks)
        duration = time.time() - start

        success = sum(results)
        print(f"Completed {REQUESTS} requests in {duration:.3f} seconds")
        print(f"Successful responses (status 200 and body matched): {success}")

if __name__ == "__main__":
    asyncio.run(main())
