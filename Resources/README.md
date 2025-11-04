# App Icon Resources

This folder contains the app icon file used in the .app bundle.

## Setup (First Time Only)

If `AppIcon.icns` doesn't exist yet, generate it:

```bash
./Scripts/generate-icon.sh
```

This will:
1. Take the source PNG from `tmp/` folder
2. Generate all required icon sizes
3. Create `Resources/AppIcon.icns`

## Icon File

- **AppIcon.icns** - macOS icon file (includes all sizes from 16x16 to 1024x1024)

This file is automatically copied to the .app bundle during build.
