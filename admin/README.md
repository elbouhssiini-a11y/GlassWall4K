# Wallora Glass Admin Panel

Website panel bach tzid wallpapers l app.

## Stack

- Vite + React + TypeScript
- **Firestore** → metadata
- **GitHub** (`glasswall4k-assets`) → image storage + `manifest.json` sync

## Firebase Auth

Panel kayqbel ghir admin UID:

`4FCRIlDIBdZ0feptCOAuysOMfC32`

Enable f Firebase Console → Authentication:
- Email/Password
- Google (optional)

## Firestore rules

Publish `firestore.rules` (wallpapers + settings):

```
match /wallpapers/{id} { allow read: if true; allow write: if admin; }
match /settings/{id} { allow read: if true; allow write: if admin; }
```

## Setup

```bash
cd admin
cp .env.example .env.local
# 3emmer VITE_GITHUB_TOKEN + VITE_ADMIN_UID
npm install
npm run open
```

## GitHub token

Classic PAT w scopes:

- `repo` (public repo contents write)

## Settings / Ads

Panel → **Settings**:
- Enable ads (Test / Production)
- App Open + Interstitial AdMob unit IDs
- Interstitial every N opens + every N downloads (separate)

Saved f Firestore: `settings/app`

## Catalog order

iOS / 4K tabs → `#1…n`:
- ↑ ↓ or set the number
- **Save order** → Firestore `sortOrder` + `manifest.json`
- Featured / Premium toggles per wallpaper

App tabs match the same catalogs.

## Flow

1. Choose image + metadata
2. Upload to `wallpapers/{id}/full.*` + `thumb.*` on GitHub
3. Save document in Firestore (`sortOrder` included)
4. Reindex + sync `manifest.json` so the iOS app keeps working
