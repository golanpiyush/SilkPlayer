import asyncio
import aiohttp
import urllib.parse
from rich.console import Console
from rich.markdown import Markdown

# List of Piped instances
PIPED_INSTANCES = [
    # "https://pipedapi.kavin.rocks",
    "https://piapi.ggtyler.dev"
]

HEADERS = {
    "User-Agent": "AltTubeSearcher/1.0"
}

console = Console()

async def fetch_from_instance(session, instance, query):
    url = f"{instance}/search?q={urllib.parse.quote(query)}&filter=videos"
    try:
        async with session.get(url, timeout=6) as response:
            if response.status == 200:
                data = await response.json()
                return instance, data
            else:
                console.print(f"[yellow]⚠️ {instance} responded with status {response.status}[/yellow]")
    except Exception as e:
        console.print(f"[red]❌ {instance} failed: {e}[/red]")
    return None, None

async def fetch_streams(session, instance, video_id):
    url = f"{instance}/streams/{video_id}"
    try:
        async with session.get(url, timeout=6) as response:
            if response.status == 200:
                return await response.json()
    except Exception as e:
        console.print(f"[red]❌ Failed to fetch streams for {video_id}: {e}[/red]")
    return {}

async def search_piped(query, count=5):
    async with aiohttp.ClientSession(headers=HEADERS) as session:
        tasks = [fetch_from_instance(session, instance, query) for instance in PIPED_INSTANCES]
        for task in asyncio.as_completed(tasks):
            instance, data = await task
            if data:
                console.print(f"\n[bold green]✅ Using instance:[/bold green] {instance}")
                videos = data.get("items", [])[:count]

                for i, item in enumerate(videos):
                    title = item.get("title", "No title")
                    url_path = item.get("url", "")
                    video_id = url_path.split("=")[-1] if "=" in url_path else url_path
                    views = item.get("views", "N/A")
                    duration = item.get("duration", 0)
                    duration_fmt = f"{duration // 60}m {duration % 60}s"

                    console.print(f"\n[bold cyan]{i+1}. {title}[/bold cyan]")
                    console.print(f"[blue]Duration:[/blue] {duration_fmt} | [magenta]Views:[/magenta] {views}")
                    console.print(f"[bold yellow]YouTube Link:[/bold yellow] https://youtube.com/watch?v={video_id}")

                    # Fetch and print streams
                    streams = await fetch_streams(session, instance, video_id)

                    video_streams = streams.get("videoStreams", [])
                    audio_streams = streams.get("audioStreams", [])

                    if video_streams:
                        console.print("\n[green]🎥 Video Streams:[/green]")
                        for v in video_streams[:2]:
                            res = v.get("quality", "unknown")
                            url = v.get("url", "")
                            console.print(f"  • [bold]{res}[/bold] - {url}")

                    if audio_streams:
                        console.print("\n[yellow]🎵 Audio Streams:[/yellow]")
                        for a in audio_streams[:2]:
                            bitrate = a.get("bitrate", 0) // 1000
                            url = a.get("url", "")
                            console.print(f"  • [bold]{bitrate}kbps[/bold] - {url}")
                return
        console.print("[red]❌ All Piped instances failed.[/red]")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        search_term = " ".join(sys.argv[1:])
    else:
        search_term = input("🔍 Enter your search query: ").strip()

    asyncio.run(search_piped(search_term))
