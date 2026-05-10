# Distortionz Hijack

> Premium vehicle hijack contracts for Qbox/FiveM — tiered rewards, parking-spot vehicle spawning, glassy NUI contract panel, qbx_vehiclekeys integration, configurable police alerts, damage tracking, and bonus loot drops.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_HiJack?style=flat-square&color=d4aa62&label=version)

---

## Overview

Underground hijack contract job. Players accept a contract from the contact ped, the script spawns a target vehicle at a randomized parking spot with a search-zone blip, the player locates and steals the vehicle, then delivers it to a randomized drop-off for tiered payouts.

## Features

- **Tiered vehicle pool** — common / mid / rare with weighted random selection and tier-specific payouts
- **Search zone blip** — large radius marker that switches to a precise target blip on approach
- **NUI contract panel** — live phase tracker, time remaining, vehicle/plate/color readout
- **qbx_vehiclekeys integration** — keys granted on entry, auto-removed on delivery
- **Damage tracking** — engine + body health monitored, payout penalty applied on delivery
- **Police alerts** — configurable chance on steal / crash / delivery, dispatch blip with reason
- **Bonus loot drops** — randomized item bonus on B-tier or higher
- **Protected contact ped** — flagged so distortionz_robped and others skip it

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player data, money, jobs |
| `ox_lib` | yes | Callbacks, notify fallback |
| `ox_target` | yes | Contact ped interaction |
| `ox_inventory` | yes | Bonus loot, dirty money payout |
| `qbx_vehiclekeys` | recommended | Key grant on entry |
| `distortionz_notify` | optional | Branded notifications |

## Installation

```cfg
ensure distortionz_hijack
```

## Configuration

See [`config.lua`](config.lua) for vehicle tiers, parking spot pool, drop-off pool, payout tiers, police alert chances, bonus loot table, and damage penalty rates.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
