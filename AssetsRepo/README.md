# glasswall4k-assets

Remote wallpaper catalog for the **GlassWall4K** iOS app.

## Layout

```text
manifest.json   ← source of truth (categories + wallpapers)
README.md
```

## Manifest fields

Each wallpaper entry:

| Field | Type | Required |
|---|---|---|
| `id` | string | yes |
| `title` | string | yes |
| `imageURL` | absolute HTTPS URL | yes |
| `thumbnailURL` | absolute HTTPS URL | yes |
| `category` | string | yes |
| `resolution` | string | yes |
| `isPremium` | bool | yes |
| `featured` | bool | yes |
| `createdAt` | ISO-8601 date | yes |

## App endpoint

```text
https://raw.githubusercontent.com/elbouhssiini-a11y/glasswall4k-assets/main/manifest.json
```

Public read only. No token is required for the iOS client.
