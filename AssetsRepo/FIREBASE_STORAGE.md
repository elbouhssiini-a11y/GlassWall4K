# Firebase Storage

GlassWall4K loads the wallpaper catalog from Firebase Storage first:

```text
gs://glasswall4k.firebasestorage.app/manifest.json
```

Public download URL used by the app:

```text
https://firebasestorage.googleapis.com/v0/b/glasswall4k.firebasestorage.app/o/manifest.json?alt=media
```

## Upload steps

1. Open Firebase Console → **Storage**
2. Upload `AssetsRepo/manifest.json` to the bucket root as `manifest.json`
3. Set Storage rules for public read (catalog + images):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

4. Optionally host your own image files in Storage and put their download URLs in `manifest.json`.

## Fallback order

1. Firebase Storage
2. GitHub `glasswall4k-assets`
3. Local mock data
