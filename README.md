# 🚗💨 Distortionz Hijack

**Premium vehicle hijack contracts for FiveM / Qbox.**
A polished, sellable-quality script where players take contracts from an underground contact, track down a target vehicle parked across the city, hijack it, and deliver it for tiered dirty-money rewards.

---

## ✨ Features

### 🎯 Contract System
- 🤝 Underground contact ped with `ox_target` interaction
- 🗺️ Configurable contact location with map blip
- 🔒 Cooldown tracking per player (success vs failure cooldowns)
- 🚫 Anti-spam protection (one active contract per player)

### 🚙 Vehicle Targeting
- 🎲 Weighted vehicle tiers — Common / Mid / Rare / Premium
- 📍 18 default parking spots across the map (Mirror Park, Vespucci, Strawberry, Vinewood, Sandy, Paleto)
- 🎨 Random color + license plate per contract
- 🔍 Search radius blip until you get close, then precise vehicle blip swaps in
- 🧹 Orphan vehicles auto-cleaned if a contract fails or expires

### 💎 Glassy NUI Panel
- 🟥 Pulsing red dot status indicator
- ⏱️ Live countdown timer with **amber → red blinking** warning states
- 🏷️ Animated stage pill — `SEARCHING` → `TARGET FOUND` → `IN POSSESSION`
- 🎫 Tier-colored badge (gray / blue / purple / gold-glowing)
- 🔢 Plate displayed in monospace pill
- 💰 Live payout estimate

### 🏆 Tiered Reward System
| Tier | Conditions | Multiplier |
|------|------------|------------|
| 🥇 **S — Pristine Pro** | On-time + minimal damage | 1.5× |
| 🥈 **A — Clean Job** | On-time | 1.25× |
| 🥉 **B — Sloppy** | Slightly late but in shape | 1.0× |
| ⏰ **C — Late** | Way over time | 0.6× |
| ❌ **Failed** | Vehicle destroyed / abandoned | $0 |

### 👮 Police Integration
- 🚨 Configurable alert chances at every stage:
  - On vehicle theft (default 35%)
  - On crash / damage spike (default 60%)
  - On delivery (default 15%)
- 📡 Real-time blips on cop maps with flashing effect
- 🚓 Supports `police`, `sheriff`, `sasp` jobs (configurable)

### 🎁 Bonus Loot System
Weighted random drop chance on successful deliveries (B tier or higher):
- 🪛 Lockpicks
- 🔧 Advanced lockpicks
- 💾 Crypto sticks
- 📿 Gold chains
- ⌚ Rolex watches

### 🔑 Key System Integration
- ✅ Player automatically receives keys when entering target vehicle
- ❌ Keys removed on successful delivery
- 🔌 Compatible with `qbx_vehiclekeys` (graceful fallback if missing)

### 🛡️ Anti-Exploit Protection
- 🔒 Server-side validation of delivery distance
- 🆔 Plate verification on delivery
- 🚫 Active job locking (prevents claim spam)
- 💥 Damage tracking server-side
- ⏱️ Time validation against issued contract

### 🧾 Standardized Version Checker
- 📡 GitHub `version.json` polling on resource start
- 🔍 HTML-response detection (catches misconfigured URLs)
- 🆔 Custom User-Agent (avoids GitHub rate limits)
- 🟢 Color-coded console output

---

## 📦 Resource Name

```
distortionz_hijack
```

## 🛠 Installation

1. 📥 Drop the folder into `resources/[distortionz]/distortionz_hijack/`
2. ⚙️ Open `config.lua` and configure:
   - `Config.Contact.coords` — where the underground contact spawns
   - `Config.ParkingSpots` — vehicle spawn locations
   - `Config.DropOffs` — delivery locations
   - `Config.VehicleTiers` — model lists per tier
   - `Config.Police` — alert percentages
3. 📝 Add to `server.cfg`:
   ```cfg
   ensure distortionz_hijack
   ```
4. 🔄 Restart your server

## 🧩 Dependencies

- 🟦 [`qbx_core`](https://github.com/Qbox-project/qbx_core)
- 🛠️ [`ox_lib`](https://github.com/overextended/ox_lib)
- 🎯 [`ox_target`](https://github.com/overextended/ox_target)
- 🎒 [`ox_inventory`](https://github.com/overextended/ox_inventory)
- 🔑 [`qbx_vehiclekeys`](https://github.com/Qbox-project/qbx_vehiclekeys) *(optional but recommended)*
- 🔔 [`distortionz_notify`](https://github.com/Distortionzz/Distortionz_Notify) *(optional — falls back to ox_lib notify)*

## ⚙️ Configuration Highlights

| Setting | Default | What it does |
|---------|---------|--------------|
| `Config.Queue.waitSeconds` | `10` | (n/a — see hijack settings below) |
| `Config.JobTiming.timeLimitSeconds` | `600` | 10 minutes to deliver |
| `Config.JobTiming.pristineDamageMax` | `100.0` | Max damage for S-tier reward |
| `Config.SearchZone.radius` | `120.0` | Search blip radius in meters |
| `Config.Police.alertOnSteal` | `35` | % chance police are alerted on hijack |
| `Config.Rewards.payAccount` | `'cash'` | `'cash'`, `'bank'`, or `'dirty'` |
| `Config.BonusLoot.chance` | `15` | % chance for bonus item on delivery |
| `Config.VersionCheck.enabled` | `true` | Hits GitHub on resource start |

## 🎮 Player Flow

1. 🚶 Walk up to the contact ped
2. 🤝 Use `ox_target` to start a contract
3. 🗺️ Map shows search zone with target details on glassy panel
4. 🔍 Drive to the area
5. 🎯 Get within 80m → precise blip appears
6. 🚗 Hop in the car (auto-receives keys)
7. 🏁 Drive to drop-off (avoid cops, drive clean)
8. 💰 Collect tiered reward + chance of bonus loot

## 📝 Changelog

### v1.0.5
- 🔑 Integrated `qbx_vehiclekeys` — auto-grant on entry, remove on delivery
- 🔓 Vehicles now spawn unlocked for clean hop-in flow

### v1.0.4
- 🔧 Fixed plate generator producing alphabet strings
- 🔧 Fixed `TARGET FOUND` triggering at job start (now 80m proximity)
- 🧹 Orphan vehicle cleanup on contract end

### v1.0.3
- 📍 Updated default contact ped location
- 🎨 Rewrote NUI base CSS to defeat CEF black background bug

### v1.0.2
- 📍 Replaced unreliable NPC scanner with parking-spot spawning
- 🎯 Tightened search radius to 120m
- ➕ Added 18 default parking spots

### v1.0.1
- 💎 Replaced in-world contract text with glassy NUI panel
- ⏱️ Added live timer with warning/critical states
- 🎫 Added tier-colored badges and live payout

### v1.0.0
- 🎉 Initial release

---

## 📜 License

MIT — see `LICENSE`.

---

**Built with 🟡 by Distortionz** · Part of the [Distortionz RP](https://github.com/Distortionzz) script lineup
