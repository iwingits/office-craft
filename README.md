<p align="center">
  <img src="assets/OfficeCraft_logo.png" width="96" alt="Office Craft logo">
</p>

<h1 align="center">Office Craft</h1>

<p align="center">
  A lightweight, tabbed desktop shell that puts the <b>ArtCraft Craft apps</b>
  (WordCraft, GridCraft, DeckCraft, PdfCraft) into a single ONLYOFFICE-style window on Windows.
</p>

---

## Acknowledgement

**Office Craft does no editing of its own.** All of the actual word-processing, spreadsheet,
presentation and PDF work is done by the **ArtCraft** "Craft" apps — open-source, clean-room
reimplementations of Microsoft Word / Excel / PowerPoint and Adobe Acrobat, written in pure Rust.

Office Craft is only a thin wrapper that hosts those apps as tabs. **Full credit and sincere
thanks to the ArtCraft team (storytold)** for building and sharing these tools.

- ArtCraft: https://getartcraft.com
- ArtCraft source: https://github.com/storytold
- Community: https://discord.gg/artcraft

## What it does

- One window with a **tab bar** — open WordCraft / GridCraft / DeckCraft / PdfCraft as tabs.
- Launch tools from a **Home** page; **open local files** (routed by extension) and a **Recent files** list.
- **Open / close / reorder** tabs; multiple instances allowed.
- Each tool's real window is embedded into the tab via Win32 `SetParent` (a WinEvent hook
  hides the window off-screen the instant it is shown, to avoid a pop-out flash).
- **Settings** with Light / Dark (black) interface themes + themed title bar (DWM immersive dark mode).
- **About** page (this acknowledgement).
- Native `OfficeCraft.exe` host so the taskbar shows the app's own icon (not PowerShell's).

## How it works

`src/host.cs` compiles to `OfficeCraft.exe`, a tiny native host that runs `src/CraftTabs.ps1`
in an in-process STA PowerShell runspace. `CraftTabs.ps1` builds the WinForms shell and embeds
each Craft app's window. The app reads the script at runtime, so tweaks need no recompile.

## Requirements

- Windows 10/11.
- The ArtCraft Craft apps installed locally (portable builds of WordCraft, GridCraft, DeckCraft, PdfCraft)
  — download from https://getartcraft.com/apps or the ArtCraft GitHub releases.

> **Note:** paths in the scripts are currently hard-coded for the author's machine
> (`C:\Users\iwin\...`). Adjust the `$script:catalog` paths in `src/CraftTabs.ps1` and the
> paths in `src/host.cs` / `build.ps1` to your own install locations before building.

## Build & run

```powershell
# compile the native host (embeds the icon)
powershell -ExecutionPolicy Bypass -File build.ps1
# then run
.\OfficeCraft.exe
```

## Files

| File | Purpose |
|------|---------|
| `src/CraftTabs.ps1` | The whole app: tabbed shell, embedding, Home/Settings/About, themes |
| `src/host.cs` | Native `OfficeCraft.exe` host (runs the script in-process) |
| `src/make-icon.ps1` | Generates the four-colour `.ico` / logo with GDI+ |
| `src/set-appid.ps1` | Tags shortcuts with an AppUserModelID (taskbar icon fix) |
| `src/CraftTabs.vbs` | Legacy no-console launcher (superseded by the exe) |
| `src/craft-mcp.json` | MCP server config for the Craft CLIs (AI tools can read/edit files) |
| `src/Revert-CraftOffice.ps1` | Removes shortcuts + file associations |
| `assets/` | Logo and icon |

## License

MIT — see `LICENSE`. The ArtCraft apps are separate projects under their own licenses.
