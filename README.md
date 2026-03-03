# Steam Publisher — Godot Editor Plugin

A Godot 4.5 editor plugin that generates Valve Data Format (VDF) build scripts and uploads your game to Steam via `steamcmd`, all without leaving the Godot editor. Supports multiple named build profiles so you can manage different App IDs, depot layouts, or working directories from a single place.

---

## Requirements

- **Godot 4.4 or later** (uses `OS.execute_with_pipe` for live log output)
- **steamcmd** — download from [Valve's developer site](https://developer.valvesoftware.com/wiki/SteamCMD)
- A **Steam partner account** with at least one app configured in the [Steamworks dashboard](https://partner.steamgames.com/)

---

## Installation

1. Copy the `addons/steam_build/` folder into the root of your Godot project, so the path looks like:
   ```
   your_project/
     addons/
       steam_build/
         plugin.cfg
         plugin.gd
         steam_build_panel.gd
   ```

2. Open your project in the Godot editor.

3. Go to **Project → Project Settings → Plugins**.

4. Find **Steam Publisher** in the list and set its status to **Enable**.

5. A **Steam Publisher** tab will appear at the bottom of the editor, next to the Output and Debugger panels.

---

## Panel overview

The panel is split into two columns:

| Left | Right |
|---|---|
| Settings sections + action buttons | Live build log + Clear button |

The left column scrolls if the content is taller than the panel. The action buttons and the Clear Log button are always pinned at the bottom of their respective columns.

---

## Configuration

All settings are saved automatically to a global config file (`user://steam_build.cfg`) whenever you make a change. They persist across editor restarts and are shared between Godot projects on the same machine.

### SteamCmd Settings

These are global and shared across all profiles.

| Field | Description |
|---|---|
| **SteamCmd Path** | Full path to `steamcmd.exe` (Windows) or `steamcmd.sh` (Linux/macOS). Use the **Browse…** button to locate it. |
| **Username** | Your Steam account username. This account must have publishing rights for the app. |
| **Password** | Your Steam account password. Stored locally in plain text — use a dedicated publishing account rather than your personal one. |

### Build Profiles

A profile groups together an App ID, Working Directory, Description, and Depot list. You can have as many profiles as you need — useful for managing a base game and its DLC, multiple branches, or separate staging and production environments.

| Control | Description |
|---|---|
| **Dropdown** | Switch between saved profiles. The panel reloads all per-profile fields instantly. |
| **Name field** | The display name of the current profile. Edit it directly — the dropdown label updates as you type. |
| **New** | Saves the current profile and creates a new blank one. |
| **Delete** | Deletes the current profile. The last remaining profile cannot be deleted. |

> **Note:** Switching profiles saves the current one automatically, so no data is lost.

### App Settings

These fields belong to the currently selected profile.

| Field | Description |
|---|---|
| **Working Dir** | The folder where VDF files will be written and where your exported game builds should be placed. Use the **Browse…** button to select it. |
| **App ID** | Your game's App ID from the Steamworks dashboard (e.g. `3291440`). |
| **Description** | A short label for this build, such as a version number (e.g. `1.0.2`). Appears in the Steamworks build history. |

### Depots

A depot represents one platform build (e.g. Windows, Linux, macOS). Most games have one depot per platform. Depots belong to the currently selected profile.

Click **+ Add Depot** to add a row. Each row has three fields:

| Field | Description |
|---|---|
| **ID** | The Depot ID from the Steamworks dashboard (e.g. `3291441`). |
| **Label** | A human-readable name for your own reference (e.g. `Windows`). Not written to any VDF file. |
| **Subdir** | The name of the subfolder inside the Working Dir that contains the exported game for this depot (e.g. `windows`). |

Click **X** on any row to remove that depot.

**Example depot setup for a two-platform game:**

| ID | Label | Subdir |
|---|---|---|
| `3291441` | Windows | `windows` |
| `3291442` | Linux | `linux` |

This expects your Working Dir to contain:
```
working_dir/
  windows/   ← export your Windows build here
  linux/     ← export your Linux build here
```

---

## Multiple profiles — example setups

**Base game + DLC:**

| Profile | App ID | Working Dir | Depots |
|---|---|---|---|
| Main Game | `3291440` | `C:/builds/game` | `3291441` windows, `3291442` linux |
| My DLC | `3291450` | `C:/builds/dlc` | `3291451` windows |

**Staging vs. production (same app, different descriptions):**

| Profile | App ID | Description | Working Dir |
|---|---|---|---|
| Production | `3291440` | `1.2.0` | `C:/builds/release` |
| Staging | `3291440` | `1.2.0-beta` | `C:/builds/staging` |

---

## Workflow

### Step 1 — Select or create a profile

Pick the profile you want to upload from the **Build Profile** dropdown, or click **New** to create one. Fill in the App ID, Working Dir, and add your depots.

### Step 2 — Export your game

Export each platform build from **Project → Export** into the appropriate subfolder inside the Working Dir. Do this before uploading — the plugin does not trigger game exports automatically.

```
working_dir/
  windows/
    MyGame.exe
    MyGame.pck
    ...
  linux/
    MyGame.x86_64
    MyGame.pck
    ...
```

### Step 3 — Generate VDF files

Click **Generate VDF Files**.

The plugin will:
- Validate that all required fields are filled in
- Create the `output/` folder inside the Working Dir (steamcmd writes build logs there)
- Create any missing depot subfolders
- Write one app VDF file: `app_{AppID}.vdf`
- Write one depot VDF file per depot: `depot_{DepotID}.vdf`

You can inspect the generated files in the Working Dir to verify the paths are correct before uploading.

### Step 4 — Upload to Steam

Click **Generate & Upload to Steam**.

This regenerates the VDF files and then runs steamcmd in a background thread, so the editor stays responsive. steamcmd output is streamed live into the Build Log on the right.

The full command that runs is:
```
steamcmd.exe +login <username> <password> +run_app_build <path/to/app_XXXXX.vdf> +quit
```

Watch the Build Log for progress. A successful upload ends with a line similar to:
```
Successfully finished appID XXXXXXX build
```

---

## Steam Guard

If your Steam account has **Steam Guard Mobile Authenticator** enabled, steamcmd will pause after logging in and wait for you to approve the sign-in on your phone. **This is normal** — the build log may appear to stall for 30–60 seconds while it waits. Approve the notification in your Steam mobile app and steamcmd will continue automatically.

> **Tip:** Using a dedicated Steam publishing account without mobile Steam Guard avoids this wait in automated workflows.

---

## Notes

- **Output buffering on Windows:** steamcmd's output may arrive in batches rather than line by line because Windows fully buffers pipe output. This is a system limitation — the log is still complete, just potentially delayed.

- **Password security:** The password is stored in plain text in `user://steam_build.cfg`. It is strongly recommended to use a separate Steam account with limited permissions (publisher role only) rather than your personal account.

- **No automatic publishing to a branch:** The generated VDF sets `"setlive"` to empty, meaning the build is uploaded but not pushed live to any branch. Set a branch live manually in the Steamworks dashboard under **Build Management**, or edit the generated VDF before uploading.

- **VDF files are not deleted between runs.** Re-clicking Generate will overwrite them in place, which is safe.