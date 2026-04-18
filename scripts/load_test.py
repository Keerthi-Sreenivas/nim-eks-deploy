"""
Load test for NIM — fires concurrent chat completions to trigger GPU autoscaling.
Usage: python load_test.py http://<NIM_URL>:8000 --rps 20 --duration 60
"""
import argparse, asyncio, time, aiohttp

PAYLOAD = {
    "model": "meta/llama-3.1-8b-instruct",
    "messages": [{"role": "user", "content": "Explain KV cache in transformer inference in 2 sentences."}],
    "max_tokens": 100,
}

async def send_request(session, url, stats):
    t0 = time.monotonic()
    try:
        async with session.post(f"{url}/v1/chat/completions", json=PAYLOAD) as r:
            await r.read()
            latency = time.monotonic() - t0
            stats["ok"] += 1
            stats["latencies"].append(latency)
    except Exception:
        stats["err"] += 1

async def main(url, rps, duration):
    stats = {"ok": 0, "err": 0, "latencies": []}
    interval = 1.0 / rps
    end = time.monotonic() + duration

    async with aiohttp.ClientSession() as session:
        tasks = []
        while time.monotonic() < end:
            tasks.append(asyncio.create_task(send_request(session, url, stats)))
            await asyncio.sleep(interval)
        await asyncio.gather(*tasks)

    lats = sorted(stats["latencies"])
    print(f"\n{'='*50}")
    print(f"Requests:  {stats['ok']} ok / {stats['err']} errors")
    if lats:
        print(f"Latency:   p50={lats[len(lats)//2]:.2f}s  p95={lats[int(len(lats)*0.95)]:.2f}s  p99={lats[int(len(lats)*0.99)]:.2f}s")
        print(f"Throughput: {stats['ok']/duration:.1f} req/s")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("url", help="NIM base URL, e.g. http://localhost:8000")
    p.add_argument("--rps", type=int, default=10, help="Requests per second")
    p.add_argument("--duration", type=int, default=60, help="Test duration in seconds")
    args = p.parse_args()
    asyncio.run(main(args.url, args.rps, args.duration))
