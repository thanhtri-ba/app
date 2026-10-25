# AGENTS.md — Photo Cleaner (Flutter, Android + iOS)

## Project
App dọn ảnh trùng/mờ trên thiết bị. Stack: Flutter/Dart, provider (ChangeNotifier), photo_manager, shared_preferences, path_provider. Không có backend.

## Commands
- Setup lần đầu: `./setup.sh` (flutter create + vá quyền + pub get + analyze + test)
- Deps: `flutter pub get`
- Lint: `flutter analyze`
- Test: `flutter test`
- Chạy: `flutter run -d <device>` (dùng `--release` khi test quét ảnh)

## Structure
- `lib/core` theme, i18n (`context.tr(en, vi)`), format
- `lib/providers` state (settings, meta, activity, library, scan)
- `lib/scanner` dHash, Laplacian, clustering (logic thuần, có unit test)
- `lib/services` thumb cache
- `lib/widgets` component dùng chung, `delete_flow.dart`
- `lib/screens` 5 tab + day/cull screens
- `android/` và `ios/` do `flutter create` sinh ra; chỉnh quyền qua `patch_platforms.py`

## Rules
- Thay đổi tối thiểu; giữ kiến trúc provider và naming hiện có. Không thêm dependency nếu chưa cần.
- Không hardcode secrets. Không xoá ảnh nếu chưa qua `confirmAndDelete`.
- Logic mới ở `lib/scanner` phải có test trong `test/logic_test.dart`.
- UI: dùng `context.pal` và `AppColors`, xử lý đủ loading/empty/error/success.
- Chạy `flutter analyze` và `flutter test` trước khi báo hoàn thành; không khẳng định pass nếu chưa chạy.
- Trả lời bằng tiếng Việt, giữ thuật ngữ kỹ thuật tiếng Anh.
