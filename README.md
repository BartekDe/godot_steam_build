# Steam Publisher — Godot Editor Plugin

A Godot 4.5 editor plugin that generates VDF build scripts and uploads your game to Steam via `steamcmd`, without leaving the editor. Supports multiple named build profiles.
<img width="1607" height="525" alt="image" src="https://github.com/user-attachments/assets/272206fd-29e8-42d7-afef-4ec3b3cc06b1" />


## Requirements

- Godot 4.4 or later
- [steamcmd](https://developer.valvesoftware.com/wiki/SteamCMD)
- A Steam partner account with at least one app configured in the [Steamworks dashboard](https://partner.steamgames.com/)

## Installation

1. Copy `addons/steam_build/` into your project root.
2. Go to **Project → Project Settings → Plugins** and enable **Steam Publisher**.
3. A **Steam Publisher** tab appears at the bottom of the editor.

## Configuration

All settings are saved automatically to `user://steam_build.cfg` and persist across restarts.

### SteamCmd Settings (global)

| Field | Description |
|---|---|
| **SteamCmd Path** | Full path to `steamcmd.exe` / `steamcmd.sh`. |
| **Username** | Steam account username with publishing rights. |
| **Password** | Steam account password. Stored in plain text — use a dedicated publishing account. |

### Build Profiles

Profiles group an App ID, Working Dir, Description, and Depot list. Switch profiles via the dropdown; create or delete them with **New** / **Delete**.

### App Settings (per profile)

| Field | Description |
|---|---|
| **Working Dir** | Folder where VDF files are written and game builds are placed. |
| **App ID** | Your game's App ID from Steamworks (e.g. `3291440`). |
| **Description** | Short build label, e.g. a version number. Appears in build history. |

### Depots (per profile)

Click **+ Add Depot** to add a platform build. Each row has:

| Field | Description |
|---|---|
| **ID** | Depot ID from Steamworks (e.g. `3291441`). |
| **Label** | Display name for your reference only. |
| **Subdir** | Subfolder inside Working Dir containing the exported build (e.g. `windows`). |

## Workflow

1. **Select or create a profile** — fill in App ID, Working Dir, and depots.
2. **Export your game** via **Project → Export** into the appropriate subfolders inside Working Dir.
3. **Generate VDF Files** — validates fields, creates folders, writes `app_{AppID}.vdf` and `depot_{DepotID}.vdf`.
4. **Generate & Upload to Steam** — regenerates VDFs and runs:
   ```
   steamcmd.exe +login <username> <password> +run_app_build <app_XXXXX.vdf> +quit
   ```
   Output streams live into the Build Log. Success ends with `Successfully finished appID XXXXXXX build`.

## Notes

- **Steam Guard:** If enabled, steamcmd will pause waiting for mobile approval. Approve the notification and it continues automatically.
- **Password security:** Stored in plain text. Use a dedicated publishing account with publisher role only.
- **No auto-publish:** Builds are uploaded but not set live. Push to a branch manually in the Steamworks dashboard under **Build Management**.
- **Windows output buffering:** steamcmd output may arrive in batches — this is a system limitation, the log is complete.
