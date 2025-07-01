# 🎥 SilkPlayer — A Free, Focused YouTube Experience

**SilkPlayer** is an Android app built for people who seek **wisdom**, **truth**, and **knowledge** — not just endless scrolling.

No ads. 
No distractions why you ask? explore... 
This is YouTube the way it *should* feel & be — minimal, powerful & FFA.


> ### 🧠 I stand by:  
> **"You cannot bottle the truth.  
> Wisdom flows free — not behind the dams of greed."**

---

## 🚀 Features

✅ Already Working:

- ~~🔊 **Background (BF) Playback** – Continue audio while app is minimized or while the screen is off~~ (Has bugs still Fixing)
- 🎨 **3 Themes** – Light, ~~Dark~~, AMOLED  
- 🔍 **Search**, **Trending**, and Random Video Feeds  (future channel based videos options) 
- 💡 **Auto Update Checker** – Notifies when a new version is available  
- 📥 **Saved Videos** (future offline support)  
- 🔒 **No Ads**, **No Tracking**, **No Account Required**

---

## 🛠️ What's Used & Why

| Tool / Library      | Purpose                                                                 |
|---------------------|-------------------------------------------------------------------------|
| **Flutter**         | Build fast and beautiful native apps with one codebase (Android/iOS)    |
| **YouTube Explode** | Fetch metadata (title, duration, channel, etc.) from YouTube            |
| **Piped API**       | Search & stream videos using privacy-respecting proxy frontend          |
| **Invidious API**   | Backup proxy-based search & feed access (some features limited)         |
| **yt-dlp** *(planned)*   | Advanced stream fetching, supports HQ video/audio + better fallback |
| **FFmpeg** *(planned)*   | Merge separate video/audio streams, subtitles, and format conversion |
| **Custom Updater**  | Checks GitHub release version silently and alerts the user              |

---

## 🔮 Planned Features (Inspired by YouTube Premium)
- 🤏 **Mini-Player** - implemented but turned off to save constrains/app the is doing to much work at its thread if off.

- 📤 **Picture-in-Picture (PiP)** Mode  
- 📌 **Continue Watching** – Resume where you left off  
- 📝 **Subtitles** – Auto-fetch and support multiple languages  
- 📈 **Quality Selector** – Choose 144p–1080p (and audio only)  
- 🎧 **Audio Only Mode** – Save bandwidth and just listen  
- 📂 **Offline Download Support**  
- 🎭 **Smart Recommendations** – Based on what you watch and save  
- 🎞️ **Playlist & Queue System**  
- 📚 **Topic-based exploration** – Science, history, philosophy, etc.
---

## 🪫 Technical Limitations

- 🔄 **APIs may break** – Piped/Invidious/Explode are not official; they can stop working if YouTube changes things
- 🚫 **No Google Account Integration at a certain level** – No history sync, likes, comments
- 🌍 **Geo & Trending Data** may be inaccurate
- ⏳ **Stream Quality Control** is limited (until `yt-dlp` is integrated)
- 🧩 **Subtitle & Playlist Support** coming soon
**Risk of Geo-IpArea Ban** - Doesn't have a proxy, as proxies are not free and are slow (researching workarounds)
---

## 📸 Screenshots

> *(Replace with real images in your `/screenshots` folder)*

- ![Home](screenshots/home.png)
- ![Trending](screenshots/trending.png)
- ![Saved](screenshots/saved.png)
- ![Settings](screenshots/settings.png)

---

## 📦 Installation

### ⚠️ Pick the Right APK for Your Phone:

| Device Type        | Use This APK          |
|--------------------|------------------------|
| Snapdragon / Modern phones (64-bit) | `silkplayer-app-arm64-v8a-release.apk` |
| Older / MediaTek / Legacy devices   | `silkplayer-app-armeabi-v7a-release.apk` |
| Universal App / May break for non androids |
`silkplayer-app-x86-release.apk` |

---

### Run Locally (Dev Setup)

```bash
git clone https://github.com/golanpiyush/SilkPlayer.git
cd SilkPlayer
flutter pub get
flutter run