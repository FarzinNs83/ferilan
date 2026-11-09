<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="branding/logo/final/feri-horizontal-on-dark.svg">
    <img src="branding/logo/final/feri-horizontal-light.svg" alt="Feri LAN" width="360">
  </picture>
</p>

<p align="center">
  Play LAN games with friends over the internet, through your own server.
  <br>
  <a href="#english">English</a> · <a href="#فارسی">فارسی</a>
</p>

## Server install

On an Ubuntu or Debian server (amd64), as root:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/FarzinNs83/feri-lan/main/server/setup.sh)
```

The script asks for your **domain** (e.g. `lan.example.com`; press Enter to use the server's IP), a **port** (default `9393`) and a **password** (press Enter for a random one), then prints what players need:

```
Server:   lan.example.com
Port:     9393
Password: ••••••••••••
```

If GitHub is blocked on your server, download through a proxy instead: `https://ghfast.top/https://raw.githubusercontent.com/FarzinNs83/feri-lan/main/server/setup.sh`

---

<a id="english"></a>

## English

### The story

We wanted to play LAN games together: Counter-Strike 1.6, Stardew Valley and others. Our friends are on Irancell, MCI and home internet. Radmin VPN worked, but its relays are abroad, so every packet went out of the country and back: about **300 ms** of ping.

Feri LAN takes a different route. Each player's traffic goes to **one server inside the country**, and that server passes it to the other players. Everyone is close to that server, so the ping is roughly *your ping to the server + your friend's ping to the server*. For us that was about 50 ms instead of 300.

To the games, it looks like a real LAN cable. Under the hood:

- **[n2n](https://github.com/ntop/n2n)** builds a layer-2 virtual network. Broadcasts go through too, so games find each other in their **LAN list**, and joining by IP also works.
- The server runs an n2n **supernode**. The `setup.sh` script installs it, along with a small service that shows who is online.
- On Windows, the **FeriLAN app** runs the n2n edge with a TAP virtual network adapter. It sets the adapter up so games use it, and shows the players, their IPs and your ping.
- The **password** is the n2n community name, so the server turns away anyone without it. It is also the encryption key, and packet headers are encrypted too, so the password never crosses the network in plain text.

```
 player A ──┐                      ┌── player B
            ├──►  your server  ◄───┤
 player C ──┘   (n2n supernode)    └── player D
       everyone on 10.88.88.x, as if on one switch
```

### Server setup

**You need:** a VPS with Ubuntu or Debian (amd64) and root access. Choose a server close to the players: for players in Iran, a server in Iran. A domain is optional but recommended. If you ever move to a new server, only the DNS record changes, and players don't need to do anything.

1. Point your domain (for example `lan.example.com`) to the server's IP with an **A record**.
2. Run the [install command](#server-install) above.
3. Open these ports in your provider's firewall, if it has one:
   - `9393` UDP and TCP: game traffic
   - `9394` TCP: the list of online players

   If you chose another port, open that port and the one after it. The script already opens them in `ufw`.
4. Give your friends three things: the **domain** (or IP), the **port** and the **password**.

**Running it again** is safe. It keeps the current password unless you type a new one. To **change the password**, run it again and type a new one; every player then has to update it in the app.

### Using the app (Windows)

**You need:** Windows 10 or 11 (64-bit).

1. **Install.** Download `FeriLAN-Setup-<version>.exe` from [Releases](https://github.com/FarzinNs83/feri-lan/releases) and run it. It asks for administrator permission and installs a virtual network adapter called **FeriLAN** (TAP-Windows). If Windows asks whether to trust the driver, click **Install**.
2. **Add a server.** The first time the app opens, it shows **Settings**:
   - Under **Servers**, click **Add server** and enter the server, port and password the server owner gave you.
   - Under **Your name**, enter English letters or digits. Friends see you by this name.
   - Click **Save**.
3. **Connect.** Press the big button. Once it turns green, you get a LAN IP like `10.88.88.23`, and the list shows who else is online.
4. **Play:**
   - **Hosting:** start a LAN game as usual. Friends find it in the game's LAN list.
   - **Joining:** open the LAN list in the game. If the game isn't there, click your friend's name in FeriLAN to copy their IP, then join by IP.

**Good to know:**
- **More than one server:** add them all in Settings. To switch, click the server name under the button on the main screen, or click a server in Settings. If you are connected, the app moves the connection to the new server.
- **Tray:** closing the window keeps FeriLAN running in the tray. Right-click the tray icon to connect, disconnect, copy your IP or quit. Windows notifications tell you when you connect, disconnect or lose the connection.
- **Connection** (Settings › Advanced):
  - **Auto** (the default) tries UDP first and switches to TCP if your network blocks UDP.
  - **UDP** gives the lowest ping.
  - **TCP** gets through almost any network, but lags more when packets are lost.
- **Other options** under Advanced:
  - Start with Windows
  - Connect on launch
  - Close to tray
  - Fix LAN discovery: keep this on

### Troubleshooting

| Problem | What to do |
|---|---|
| "Can't reach the server" | **Turn off your VPN or proxy**, or exclude the server from it (split tunneling). A VPN sends your traffic abroad, so it never reaches the server. Then check the address, port and password. |
| Connected, but the game isn't in the LAN list | Make sure **Fix LAN discovery** is on. Join by IP instead: click the friend's name to copy it. Virtual adapters from VMware, Hyper-V or other VPNs can catch the game's broadcast; disable them while you play. |
| Friends can't join my game | Allow the game in Windows Firewall when it asks. FeriLAN already allows all incoming traffic on its own adapter. |
| "The virtual adapter did not install" | Settings › Advanced › **Reinstall**, then connect again. |
| High ping or lag spikes | Use **UDP** mode if your network allows it. The ping shown in the app is your ping to the server. |

**What works:** games that have a LAN mode or a "join by IP" option over normal IP networking, such as Counter-Strike 1.6, Stardew Valley and Minecraft. **What doesn't:**
- Games whose "LAN" actually goes through Steam or another online service
- Very old games that only support IPX (late-90s titles); these need a tool like IPXWrapper

### Build from source

```bash
flutter build windows
```

Then compile `installer/FeriLAN.iss` with [Inno Setup 6](https://jrsoftware.org/isinfo.php); the installer is written to `dist/`. `windows/bin/feri-edge.exe` is n2n 3.1.1, built for Windows.

---

<a id="فارسی"></a>

<div dir="rtl">

## فارسی

### داستان

می‌خواستیم با دوستامون بازی‌های LAN بازی کنیم: کانتر استرایک 1.6، استاردیو ولی و بقیه. هر کدوم یه اینترنتی داشتیم: ایرانسل، همراه اول، اینترنت خونگی. Radmin VPN کار می‌کرد، ولی سرورهاش خارج از ایرانه. یعنی هر بسته‌ی بازی می‌رفت خارج و برمی‌گشت و پینگ می‌شد حدود **۳۰۰ میلی‌ثانیه**.

Feri LAN راه دیگه‌ای می‌ره: ترافیک همه‌ی بازیکن‌ها می‌ره به **یک سرور داخل ایران** و اون سرور بین بازیکن‌ها جابه‌جاش می‌کنه. همه به این سرور نزدیکن، پس پینگ تقریباً می‌شه *پینگ تو تا سرور + پینگ دوستت تا سرور*. برای ما حدود ۵۰ میلی‌ثانیه شد، به‌جای ۳۰۰.

بازی‌ها فکر می‌کنن با کابل LAN به هم وصلید. چطوری کار می‌کنه:

- **[n2n](https://github.com/ntop/n2n)** یک شبکه‌ی مجازی لایه‌ی ۲ می‌سازه. broadcast هم رد می‌شه، پس بازی‌ها همدیگه رو توی **لیست LAN** پیدا می‌کنن. وصل شدن با IP هم کار می‌کنه.
- روی سرور یک **supernode** از n2n اجرا می‌شه. اسکریپت `setup.sh` اون رو نصب می‌کنه، به‌همراه یک سرویس کوچک که نشون می‌ده کی آنلاینه.
- روی ویندوز، **برنامه‌ی FeriLAN** کلاینت n2n رو با یک کارت شبکه‌ی مجازی (TAP) اجرا می‌کنه. کارت شبکه رو طوری تنظیم می‌کنه که بازی‌ها ازش استفاده کنن، و بازیکن‌ها، IPهاشون و پینگ تو رو نشون می‌ده.
- **رمز** همون اسم community در n2n هست، پس سرور کسی رو که رمز نداره راه نمی‌ده. کلید رمزنگاری ترافیک هم همینه و هدر بسته‌ها هم رمزنگاری می‌شن، پس خود رمز هیچ‌وقت ساده روی شبکه نمی‌ره.

### راه‌اندازی سرور

**پیش‌نیاز:** یک VPS با Ubuntu یا Debian (amd64) و دسترسی root. سرور باید به بازیکن‌ها نزدیک باشه؛ برای بازیکن‌های ایران، سرور ایران. دامنه اختیاریه ولی پیشنهاد می‌شه. اگه یه روز سرور رو عوض کنی، فقط رکورد DNS عوض می‌شه و بازیکن‌ها لازم نیست کاری بکنن.

1. دامنه (مثلاً `lan.example.com`) رو با یک **رکورد A** به IP سرور وصل کن.
2. [دستور نصب](#server-install) بالای همین صفحه رو اجرا کن.
3. اگه دیتاسنتر فایروال داره، این پورت‌ها رو باز کن:
   - `9393` UDP و TCP: ترافیک بازی
   - `9394` TCP: لیست بازیکن‌های آنلاین

   اگه پورت دیگه‌ای انتخاب کردی، همون پورت و پورت بعدیش رو باز کن. اسکریپت خودش اون‌ها رو در `ufw` باز می‌کنه.
4. سه چیز رو به دوستات بده: **دامنه** (یا IP)، **پورت** و **رمز**.

**اجرای دوباره‌ی اسکریپت** مشکلی نداره. رمز فعلی رو نگه می‌داره، مگر اینکه رمز جدید وارد کنی. برای **عوض کردن رمز**، اسکریپت رو دوباره اجرا کن و رمز جدید رو بزن. بعدش همه‌ی بازیکن‌ها باید رمز رو توی برنامه عوض کنن.

### استفاده از برنامه (ویندوز)

**پیش‌نیاز:** ویندوز ۱۰ یا ۱۱ (۶۴ بیتی).

1. **نصب.** فایل `FeriLAN-Setup-<version>.exe` رو از [Releases](https://github.com/FarzinNs83/feri-lan/releases) دانلود و اجرا کن. دسترسی ادمین می‌خواد و یک کارت شبکه‌ی مجازی به اسم **FeriLAN** (TAP-Windows) نصب می‌کنه. اگه ویندوز پرسید به درایور اعتماد داری، **Install** رو بزن.
2. **اضافه کردن سرور.** بار اول که برنامه باز می‌شه، **Settings** رو نشون می‌ده:
   - در بخش **Servers** روی **Add server** بزن و آدرس سرور، پورت و رمزی که صاحب سرور بهت داده رو وارد کن.
   - در **Your name** اسمت رو با حروف انگلیسی یا عدد بنویس. دوستات با این اسم می‌بیننت.
   - **Save** رو بزن.
3. **اتصال.** دکمه‌ی بزرگ رو بزن. وقتی سبز شد، یک IP شبکه‌ی LAN مثل `10.88.88.23` می‌گیری و لیست نشون می‌ده چه کسایی آنلاینن.
4. **بازی:**
   - **میزبان:** مثل همیشه بازی LAN بساز. دوستات توی لیست LAN بازی پیداش می‌کنن.
   - **وصل شدن:** لیست LAN بازی رو باز کن. اگه بازی اونجا نبود، توی FeriLAN روی اسم دوستت بزن تا IPش کپی بشه، بعد با IP وصل شو.

**نکته‌ها:**
- **چند سرور:** همه رو در Settings اضافه کن. برای عوض کردن، توی صفحه‌ی اصلی روی اسم سرور زیر دکمه بزن، یا در Settings روی سرور بزن. اگه وصل باشی، برنامه اتصال رو به سرور جدید می‌بره.
- **Tray:** با بستن پنجره، FeriLAN در tray (کنار ساعت ویندوز) روشن می‌مونه. با راست‌کلیک روی آیکونش می‌تونی وصل یا قطع بشی، IPت رو کپی کنی یا از برنامه خارج بشی. نوتیفیکیشن ویندوز خبر می‌ده کی وصل شدی، کی قطع شدی و کی ارتباط از دست رفت.
- **نوع اتصال** (Settings › Advanced):
  - **Auto** (پیش‌فرض) اول UDP رو امتحان می‌کنه و اگه شبکه‌ات UDP رو بسته باشه، می‌ره روی TCP.
  - **UDP** کمترین پینگ رو داره.
  - **TCP** تقریباً از هر شبکه‌ای رد می‌شه، ولی وقتی بسته‌ها گم بشن بیشتر لگ می‌زنه.
- **گزینه‌های دیگه** در Advanced:
  - Start with Windows: اجرا با روشن شدن ویندوز
  - Connect on launch: اتصال خودکار وقتی برنامه باز می‌شه
  - Close to tray: با بستن پنجره، برنامه در tray می‌مونه
  - Fix LAN discovery: روشن بمونه

### رفع مشکل

| مشکل | راه‌حل |
|---|---|
| «Can't reach the server» | **VPN یا پروکسی رو خاموش کن**، یا سرور رو از اون مستثنی کن (split tunneling). VPN ترافیک رو می‌بره خارج و هیچ‌وقت به سرور نمی‌رسه. بعد آدرس، پورت و رمز رو چک کن. |
| وصلم ولی بازی توی لیست LAN نیست | مطمئن شو **Fix LAN discovery** روشنه. با IP وصل شو: روی اسم دوستت بزن تا IPش کپی بشه. کارت شبکه‌های مجازی VMware، Hyper-V یا VPNهای دیگه ممکنه broadcast بازی رو بگیرن؛ موقع بازی غیرفعالشون کن. |
| دوستام نمی‌تونن به بازی من وصل بشن | وقتی ویندوز پرسید، بازی رو در فایروال مجاز کن. FeriLAN خودش ورودی روی کارت شبکه‌ی خودش رو باز می‌کنه. |
| «The virtual adapter did not install» | از Settings › Advanced گزینه‌ی **Reinstall** رو بزن و دوباره وصل شو. |
| پینگ بالا یا لگ | اگه شبکه‌ات اجازه می‌ده، حالت **UDP** رو بزن. پینگی که برنامه نشون می‌ده، پینگ تو تا سروره. |

**چه بازی‌هایی کار می‌کنن:** هر بازی‌ای که حالت LAN یا گزینه‌ی وصل شدن با IP روی شبکه‌ی معمولی (IP) داره، مثل کانتر استرایک 1.6، استاردیو ولی و ماینکرفت. **چه بازی‌هایی نه:**
- بازی‌هایی که «LAN»شون در واقع از Steam یا یک سرویس آنلاین استفاده می‌کنه
- بازی‌های خیلی قدیمی که فقط IPX دارن (اواخر دهه‌ی ۹۰)؛ این‌ها به ابزاری مثل IPXWrapper نیاز دارن

### ساختن از سورس

```bash
flutter build windows
```

بعد `installer/FeriLAN.iss` رو با [Inno Setup 6](https://jrsoftware.org/isinfo.php) کامپایل کن؛ installer در پوشه‌ی `dist/` ساخته می‌شه. `windows/bin/feri-edge.exe` همون n2n 3.1.1 هست که برای ویندوز بیلد شده.

</div>
