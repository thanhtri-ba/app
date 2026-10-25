# Photo Cleaner

Review, cull and clean up your photo library. Everything runs on the device.

## Features
- **Review**: groups near-identical photos (64-bit dHash + time window), keeps the sharpest of each group, and deletes the rest in one go.
- **Cleanup**: blurry photos (Laplacian variance), screenshots, large videos.
- **Library**: calendar heat-map of shooting days, day view (stats, hourly histogram, culling progress), full-screen culling with 1-5 stars, pick / reject flags and colour labels, batch actions, "delete rejected".
- **Storage**: library breakdown and an activity log of what you freed.
- **Settings**: theme, language (EN / VI), scan size, blur and similarity sensitivity.

Deleted photos go to *Recently Deleted* (iOS) or the system trash (Android 11+), so they can be restored.

Ratings, flags and labels are stored inside the app (`photo_cleaner_meta.json`), not in the photo files.

## Setup (macOS)
```bash
cd ~/development/photo_cleaner
./setup.sh          # creates android/ ios/, adds photo permissions, pub get, analyze, test
flutter run         # with a phone connected / simulator running
```
`setup.sh` backs up `lib/`, `test/` and `pubspec.yaml`, runs `flutter create .`, and restores them.

## Not included (needs a backend)
Cloud backup, client galleries, AI services, accounts and subscriptions. These exist only in the UI prototype.

## Tuning
- `SettingsProvider.blurThreshold` (35 / 60 / 100) was not calibrated on real photos. If too many or too few photos show as blurry, change these numbers.
- `SettingsProvider.hashThreshold` (4 / 7 / 11 of 64 bits) controls how similar photos must be to share a group.
