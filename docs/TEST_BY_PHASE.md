# Photo Cleaner — Kế hoạch kiểm thử chi tiết theo giai đoạn

Phiên bản kiểm thử: build debug hiện tại (giai đoạn 0–6) · Thiết bị chính: Android SM A217F · Phụ: iOS (nếu có)
Người test: ____________ · Ngày: ____________ · Build/commit: ____________

> **Trạng thái code:** toàn bộ 4 giai đoạn **chưa từng được biên dịch hay chạy** trước bản test này. Vì vậy thứ tự bắt buộc là: Giai đoạn 0 (build) → 0 (giao diện) → 1 → 2 → 3 → 4. Nếu build lỗi, dừng và gửi log, không test tiếp.

## Cách dùng tài liệu

- Mỗi giai đoạn gồm: **mục tiêu → thay đổi cần test → dữ liệu chuẩn bị → ca kiểm thử → hạn chế đã biết → tiêu chí hoàn thành**.
- Mỗi ca kiểm thử có: **mã ca**, **thao tác (đánh số)**, **kết quả mong đợi**, ô **Đạt** (`[ ]` → `[x]` hoặc `[F]` nếu lỗi).
- Khi lỗi: ghi mã ca vào bảng lỗi ở cuối (mục "Mẫu báo lỗi"), kèm ảnh chụp màn hình/log.
- Mức độ lỗi: **Chặn** (không dùng tiếp được / mất dữ liệu) · **Nghiêm trọng** · **Nhẹ** · **Thẩm mỹ**.
- **Quy tắc an toàn dữ liệu:** chỉ test trên ảnh/video thử hoặc đã sao lưu. Các ca có xoá/ẩn/nén đều làm thật trên thư viện máy.

---

# GIAI ĐOẠN 0 — Build, giao diện & animation (nền tảng)

**Mục tiêu:** xác nhận app build được, các tab không còn chồng nhau, animation mượt, giao diện Dọn dẹp gọn.

**Thay đổi cần test:** `TabPage` mới (dùng `Offstage`), hero + lưới 2×2 + danh sách ở Dọn dẹp, animation mờ/trượt, nút co khi nhấn, giới hạn cỡ chữ 0.9–1.15×.

## 0.A Chuẩn bị môi trường

```bash
cd ~/development/photo_cleaner
flutter clean
flutter pub get
python3 patch_platforms.py     # an toàn khi chạy lại
flutter analyze
flutter test
flutter build apk --debug
```

| Mã | Lệnh | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 0.A1 | `flutter pub get` | Không báo xung đột phiên bản. Gói mới: cryptography, flutter_secure_storage, local_auth, share_plus, cross_file, google_mlkit_text_recognition, light_compressor_v2, video_player, supabase_flutter (và dev: flutter_launcher_icons) | [ ] |
| 0.A2 | `python3 patch_platforms.py` | In ra các dòng "patched…", "minSdk raised…" hoặc "already patched"; không có traceback | [ ] |
| 0.A3 | `flutter analyze` | **0 error.** Ghi số warning/info: ____ | [ ] |
| 0.A4 | `flutter test` | Pass toàn bộ 8 file (xem tổng hợp bên dưới). Ghi `All tests passed` hoặc dán test fail | [ ] |
| 0.A5 | `flutter build apk --debug` | `Built build/app/outputs/flutter-apk/app-debug.apk` | [ ] |
| 0.A6 | (iOS) `cd ios && pod install --repo-update`, rồi `flutter build ios --no-codesign` | Thành công (iOS tối thiểu 15.5) | [ ] |

**Bảng test tự động theo file:**

| File | Số test | Kiểm tra gì |
|---|---|---|
| `logic_test.dart` | 10 | hash ảnh, độ lệch Hamming, độ nét Laplacian, gom nhóm ảnh giống, định dạng dung lượng/ngày |
| `vault_crypto_test.dart` | 7 | mã hoá/giải mã đúng với nhiều kích thước, sai khoá thì lỗi, sửa 1 byte thì lỗi, **cắt mất chunk cuối bị phát hiện**, file không phải vault bị từ chối |
| `achievements_test.dart` | 22 | chuỗi ngày hiện tại/dài nhất, qua tháng, ngưỡng huy hiệu |
| `sig_cache_test.dart` | 4 | cache đúng theo thời gian sửa, ghi/đọc không mất độ chính xác, bỏ dòng hỏng, dọn ảnh đã xoá |
| `suggestions_test.dart` | 9 | các ngưỡng gợi ý, thứ tự, tối đa 3 |
| `receipt_text_test.dart` | 7 | nhận hoá đơn tiếng Việt/Anh, loại ảnh ít chữ, khớp nguyên từ |
| `video_view_test.dart` | 5 | lọc/sắp xếp video, quy tắc "nhỏ hơn ≥10% mới giữ" |
| `auth_rules_test.dart` | 14 | kiểm tra email, quy tắc mật khẩu (≥8 ký tự, có chữ và số), dịch lỗi đăng nhập, không lộ lỗi nội bộ |

## 0.B Khởi động & điều hướng

**Chuẩn bị:** dừng hẳn app cũ, `flutter run` (**không** hot reload).

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 0.B1 | Cài mới / xoá dữ liệu app → mở | Splash → 3 trang giới thiệu → đăng nhập/dùng thử → xin quyền ảnh → vào app | [ ] |
| 0.B2 | Cho phép quyền ảnh | Tab **Duyệt** hiện số ảnh đã tải | [ ] |
| 0.B3 | **Lỗi trước đây — chồng tab.** Chạm lần lượt Duyệt → Dọn dẹp → Thư viện → Dung lượng → Cài đặt | Mỗi lúc chỉ **một** trang hiển thị; không còn chữ/tiêu đề tab khác lẫn vào. Có hiệu ứng mờ + trượt nhẹ | [ ] |
| 0.B4 | Chạm tab thật nhanh 10 lần liên tiếp | Không chồng trang, không giật, không crash | [ ] |
| 0.B5 | Cuộn tab Dọn dẹp xuống giữa, đổi tab rồi quay lại | Vị trí cuộn giữ nguyên | [ ] |
| 0.B6 | Icon tab đang chọn | Đổi sang icon đặc, phóng to nhẹ, chữ đậm hơn | [ ] |
| 0.B7 | Cài đặt → Chế độ tối/sáng | Mọi tab đổi màu, chữ đọc được | [ ] |
| 0.B8 | Cài đặt → English ↔ Tiếng Việt | Nhãn của 5 tab và các màn con đổi theo, không sót chuỗi cũ | [ ] |
| 0.B9 | Cài đặt hệ thống → cỡ chữ lớn nhất → mở app | Không tràn/vỡ layout | [ ] |
| 0.B10 | Bật "Remove animations" của hệ thống | Nội dung hiện ngay, không trống hay trong suốt | [ ] |

## 0.C Giao diện Dọn dẹp

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 0.C1 | Mở tab Dọn dẹp | Thứ tự: tiêu đề → **hero** (Đã giải phóng / Có thể giải phóng + nút Quét nhanh) → (gợi ý) → **Dọn thông minh** lưới 2×2 → **Công cụ khác** danh sách. Không ô nào chữ xuống 3 dòng | [ ] |
| 0.C2 | Quan sát lúc mở | Các khối hiện lần lượt (mờ + trượt lên) | [ ] |
| 0.C3 | Nhấn giữ một ô/hàng | Co nhẹ, rung nhẹ; thả ra mở màn | [ ] |
| 0.C4 | Bấm **Quét nhanh** | Nút thành thanh tiến độ %, xong thành **Quét lại**; số "Có thể giải phóng" chạy lên | [ ] |
| 0.C5 | Trước khi quét | Các ô cần quét hiện "Chưa quét" + mũi tên | [ ] |
| 0.C6 | Sau khi quét | Số trên ô (ảnh giống, mờ, chụp màn hình, video) khớp số thực trong màn con | [ ] |
| 0.C7 | Vào từng công cụ: Ảnh mờ / Chụp màn hình / Video lớn / Chụp liên tiếp / Biên lai & tài liệu / Ảnh từ chat / Video trùng | Mở có hiệu ứng, hiện lưới ảnh; nếu rỗng hiện "Không có gì cần dọn" | [ ] |
| 0.C8 | Trong công cụ, chạm chọn ảnh | Ảnh thu nhỏ + tối đi, dấu tick bật ra, nút dưới đổi "Xoá N mục". Nhấn giữ → xem toàn màn hình | [ ] |
| 0.C9 | **Chụp liên tiếp** | Ảnh đẹp nhất nhãn "ĐẸP NHẤT" **không** chọn sẵn; các ảnh khác chọn sẵn | [ ] |

## 0.D Duyệt nhanh (Review) & xoá

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 0.D1 | Tab Duyệt → **Quét** | Vòng tiến độ + đếm `x / y`; nút **Dừng** dừng được | [ ] |
| 0.D2 | Quét xong | Thấy nhóm ảnh giống; ảnh nét nhất có viền xanh | [ ] |
| 0.D3 | Chạm ảnh trong nhóm | Ảnh mờ đi (đánh dấu xoá), số MB ở hero đổi | [ ] |
| 0.D4 | **Tự chọn** / **Đặt lại** | Chọn tất cả trừ ảnh nét nhất / bỏ hết | [ ] |
| 0.D5 | Bấm Xoá N ảnh → xác nhận | Hộp thoại → hệ thống hỏi quyền → ảnh vào "Đã xoá gần đây" → hiện màn chúc mừng | [ ] |
| 0.D6 | Bấm Huỷ ở hộp thoại | Không xoá gì | [ ] |

**Hạn chế đã biết (không báo lỗi):** các số `~MB` là **ước lượng** (dựa trên độ phân giải), không phải dung lượng thật.

**Tiêu chí hoàn thành GĐ0:** 0.A1–0.A5 đạt, 0.B3–0.B4 đạt (lỗi chồng tab đã hết), không crash ở 0.C và 0.D.

---

# GIAI ĐOẠN 1 — Bảo mật Vault (mã hoá thật)

**Mục tiêu:** ảnh trong Két riêng tư thật sự được mã hoá, khoá nằm trong Keystore, có sinh trắc học, chặn chụp màn hình, tự khoá.

**Thay đổi cần test:**
- Mã hoá AES-256-GCM theo từng chunk 1 MiB; định dạng file: `PCV1` + 8 byte ngẫu nhiên + dữ liệu.
- Khoá 32 byte lưu trong `flutter_secure_storage`.
- Ảnh thu nhỏ mã hoá riêng (`.thm`), file chính `.enc`.
- PIN băm có muối ×20.000; sai 5 lần khoá 30 giây.
- Sinh trắc học (chỉ mở khoá giao diện). `FLAG_SECURE`. Tự khoá khi app xuống nền.
- Di chuyển dữ liệu từ Két cũ (chưa mã hoá).

**Dữ liệu chuẩn bị:** 3 ảnh thử (khác nhau, dễ nhận ra) · 1 video ngắn · 1 video ≥100 MB · máy đã đăng ký vân tay/khuôn mặt · cáp USB + `adb` (cho 1.F). Package: `com.example.photo_cleaner` (kiểm tra lại trong `android/app/build.gradle.kts` nếu khác).

## 1.A Tạo PIN & vào Két

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.A1 | Dọn dẹp → **Két riêng tư** lần đầu | Màn "Tạo mã PIN" (4 số) | [ ] |
| 1.A2 | Nhập PIN `1234`, rồi nhập lại `4321` | Báo hai mã không khớp, quay về bước tạo | [ ] |
| 1.A3 | Tạo lại: `1234` / `1234` | Vào Két (trống). Banner nói ảnh được **mã hoá AES-256** và phải **khôi phục trước khi gỡ app/đổi máy** | [ ] |
| 1.A4 | Thoát Két, vào lại | Yêu cầu PIN; nhập `1234` đúng → vào | [ ] |

## 1.B Ẩn ảnh vào Két

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.B1 | **Thêm ảnh** → chọn 2 ảnh + 1 video ngắn → Ẩn | Hệ thống hỏi quyền xoá ảnh gốc. **App không tự quay về màn Dọn dẹp** trong lúc hộp thoại hiện | [ ] |
| 1.B2 | Đồng ý | Két hiện 3 mục có thumbnail (video có nút play); có thể có dòng tiến độ ngắn | [ ] |
| 1.B3 | Mở app Ảnh của máy | 3 mục vừa ẩn **không còn** ở thư viện | [ ] |
| 1.B4 | Nhấn giữ 1 ảnh trong Két | Xem toàn màn hình, zoom được, ảnh đúng nội dung | [ ] |
| 1.B5 | Đóng trình xem | Quay lại Két, không crash | [ ] |
| 1.B6 | Nhấn giữ video | Báo cần khôi phục về thư viện để xem (hạn chế đã biết) | [ ] |
| 1.B7 | Thêm ảnh nhưng **từ chối** hộp thoại xoá | Báo "Chưa ẩn ảnh nào"; Két không giữ bản sao thừa; ảnh gốc còn nguyên | [ ] |
| 1.B8 | Thêm video ≥100 MB | Giao diện không treo; hoàn tất; mục xuất hiện | [ ] |

## 1.C Khôi phục & xoá

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.C1 | Chọn 1 ảnh → **Khôi phục** | Ảnh quay lại thư viện (kiểm tra trong app Ảnh), biến mất khỏi Két; ảnh mở ra đúng, không hỏng | [ ] |
| 1.C2 | Khôi phục video | Video về thư viện, phát được, có tiếng | [ ] |
| 1.C3 | Chọn 1 mục → **Xoá** → xác nhận | Mất hẳn, **không** vào "Đã xoá gần đây" | [ ] |
| 1.C4 | Huỷ khi hỏi xác nhận xoá | Không xoá | [ ] |

## 1.D PIN & khoá tạm

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.D1 | Nhập sai PIN 4 lần | Báo sai, còn lại số lần thử | [ ] |
| 1.D2 | Nhập sai lần thứ 5 | **Khoá 30 giây**, có đếm ngược; phím bị vô hiệu | [ ] |
| 1.D3 | Đợi hết 30 giây, nhập đúng | Vào được | [ ] |
| 1.D4 | Sai 5 lần → thoát app hẳn → mở lại ngay | Vẫn còn thời gian khoá (hoặc ít nhất không cho thử vô hạn) — ghi nhận thực tế: ____ | [ ] |

## 1.E Sinh trắc học

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.E1 | Trong Két, bật công tắc **Mở khoá bằng sinh trắc học** | Hiện hộp xác thực hệ thống → đúng vân tay → bật thành công | [ ] |
| 1.E2 | Thoát Két, vào lại | Tự hiện hộp sinh trắc; vân tay đúng → vào thẳng | [ ] |
| 1.E3 | Hộp sinh trắc → bấm Huỷ | Về bàn phím PIN; nhập PIN vẫn vào được | [ ] |
| 1.E4 | Chạm biểu tượng vân tay ở góc bàn phím PIN | Gọi lại hộp sinh trắc | [ ] |
| 1.E5 | Vân tay sai nhiều lần | Hệ thống tự khoá/thông báo; app không crash; PIN vẫn dùng được | [ ] |
| 1.E6 | Máy **chưa đăng ký** sinh trắc | Công tắc bị ẩn | [ ] |
| 1.E7 | Tắt công tắc | Lần sau chỉ hỏi PIN | [ ] |

## 1.F Bảo mật thực tế (kiểm chứng bằng adb)

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.F1 | `adb shell run-as com.example.photo_cleaner ls app_flutter/vault` | Thấy file `*.enc` và `*.thm`. **Không** có file ảnh gốc | [ ] |
| 1.F2 | `adb exec-out run-as com.example.photo_cleaner head -c 16 app_flutter/vault/<tên>.enc \| xxd` | 4 byte đầu `5043 5631` ("PCV1"). **Không** thấy `ffd8` (JPEG) | [ ] |
| 1.F3 | Kích thước `.enc` so với ảnh gốc | Lớn hơn ảnh gốc khoảng 28 byte (+12 đầu, +16 mỗi chunk) | [ ] |
| 1.F4 | Chụp màn hình trong Két (nguồn + giảm âm lượng) | Bị chặn hoặc ảnh chụp đen. Ra khỏi Két thì chụp được | [ ] |
| 1.F5 | Vào Recent apps (đa nhiệm) khi đang ở trong Két | Ảnh xem trước của app **bị che/đen** | [ ] |
| 1.F6 | Trong Két bấm Home, rồi mở lại app | App về tab Dọn dẹp; vào Két lại phải nhập PIN | [ ] |
| 1.F7 | Đang xem ảnh toàn màn hình, bấm Home rồi mở lại | Trình xem đóng; thư mục `vault_view` tạm (trong cache) bị xoá: `adb shell run-as com.example.photo_cleaner ls cache` không còn file ảnh giải mã | [ ] |
| 1.F8 | Kiểm tra backup | `adb shell dumpsys package com.example.photo_cleaner \| grep -i allowBackup` → không cho phép sao lưu | [ ] |

## 1.G Độ bền

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 1.G1 | Vuốt tắt app trong lúc đang ẩn ảnh | Mở lại: Két không có file hỏng; ảnh gốc còn nguyên nếu chưa bị xoá | [ ] |
| 1.G2 | Hết dung lượng khi ẩn ảnh lớn (tuỳ chọn) | Báo lỗi nhẹ nhàng, ảnh gốc không mất | [ ] |
| 1.G3 | **Migrate:** cài bản cũ có ảnh trong Két (nếu còn bản cũ) rồi nâng cấp | Ảnh cũ được mã hoá tự động, có dòng tiến độ; mở lại xem được; file thô cũ biến mất | [ ] |
| 1.G4 | Gỡ app rồi cài lại | Két trống — **đúng thiết kế** (khoá gắn với app) | [ ] |

**Hạn chế đã biết (không báo lỗi):**
- Sinh trắc học chỉ mở khoá giao diện, không dùng làm khoá mã hoá.
- Không chặn chụp màn hình trên iOS.
- Android ≤ 8 có thể chưa hiện chặn chụp màn hình đầy đủ.
- Không xem được video ngay trong Két.
- Mất Két khi gỡ app hoặc đổi máy.

**Tiêu chí hoàn thành GĐ1:** 1.B1–1.B3, 1.C1, 1.D2, 1.F1–1.F2, 1.F4, 1.F6 đạt; không có ca nào làm mất ảnh.

---

# GIAI ĐOẠN 2 — Gamification & thống kê

**Mục tiêu:** chuỗi ngày, mục tiêu tháng, 11 huy hiệu, màn chúc mừng có chia sẻ; số liệu không mất.

**Thay đổi cần test:** bộ đếm trọn đời tách khỏi lịch sử 200 mục; chuỗi ngày (còn sống nếu hôm qua có dọn); mục tiêu 250 MB/500 MB/1 GB/2 GB; thẻ chia sẻ (ảnh PNG).

**11 huy hiệu:** Lần dọn đầu · 100 MB · 1 GB · 5 GB · 100 mục · 1.000 mục · Chuỗi 3 ngày · Chuỗi 7 ngày · Chuỗi 30 ngày · Hộp đồ nghề (≥4 công cụ) · Người giữ két.

**Chuẩn bị:** dùng bản cài mới (xoá dữ liệu) cho 2.A; giữ lại một bản có lịch sử cũ cho 2.F nếu có.

## 2.A Màn chúc mừng

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.A1 | Cài mới. Xoá bất kỳ vài ảnh (ví dụ qua Ảnh chụp màn hình) | Hiện sheet chúc mừng: dấu ✓ bật ra, số MB **chạy từ 0 lên**, "Chuỗi 1 ngày", thanh mục tiêu tháng | [ ] |
| 2.A2 | Cùng lần đó | Có thẻ **Huy hiệu mới: Lần dọn đầu** | [ ] |
| 2.A3 | Số lượng ảnh và MB trong sheet | Khớp với số vừa xoá | [ ] |
| 2.A4 | Bấm **Chia sẻ** | Mở khung chia sẻ hệ thống kèm ảnh thẻ + câu chữ | [ ] |
| 2.A5 | Chia sẻ vào Ghi chú/Zalo | Ảnh nhận được rõ nét, không bị cắt, chữ đọc được | [ ] |
| 2.A6 | Huỷ khung chia sẻ | Quay lại sheet, không crash | [ ] |
| 2.A7 | Bấm **Xong** | Sheet đóng, màn trước cập nhật số liệu | [ ] |

## 2.B Chuỗi ngày

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.B1 | Tab Dung lượng → **Hoạt động** | Thẻ chuỗi: 7 chấm của 7 ngày gần nhất, hôm nay có ✓; hiện "Chuỗi hiện tại" và "Kỷ lục" | [ ] |
| 2.B2 | Dọn thêm lần nữa trong cùng ngày | Chuỗi **không** tăng (vẫn 1) | [ ] |
| 2.B3 | Đổi ngày hệ thống **+1 ngày**, mở app, dọn 1 lần | Chuỗi = 2 | [ ] |
| 2.B4 | Đổi tiếp +1 ngày, **không dọn**, mở Hoạt động | Chuỗi còn hiện 2 (còn sống nếu hôm qua có dọn) | [ ] |
| 2.B5 | Đổi thêm +1 ngày nữa (bỏ trọn 1 ngày), mở Hoạt động | Chuỗi về 0; **Kỷ lục giữ nguyên** (2) | [ ] |
| 2.B6 | **Nhớ đặt lại ngày/giờ hệ thống về tự động** | — | [ ] |

## 2.C Mục tiêu tháng

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.C1 | Chọn mục tiêu 250 MB → 500 MB → 1 GB → 2 GB | Phần trăm và vòng tròn đổi ngay theo từng lựa chọn | [ ] |
| 2.C2 | Tắt hẳn app, mở lại | Lựa chọn mục tiêu vẫn giữ | [ ] |
| 2.C3 | Dọn đủ vượt mục tiêu (ví dụ chọn 250 MB và dọn > 250 MB) | Phần trăm tối đa 100% (không vượt/không vỡ giao diện) | [ ] |
| 2.C4 | Sang tháng mới (đổi ngày +1 tháng) | Tiến độ tháng về 0 nhưng tổng trọn đời không giảm | [ ] |

## 2.D Huy hiệu

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.D1 | Mở lưới huy hiệu | Có đủ 11 huy hiệu; chưa mở thì mờ/xám | [ ] |
| 2.D2 | Chạm 1 huy hiệu đã mở / chưa mở | Hiện mô tả + "Đã mở khoá / Chưa mở khoá" | [ ] |
| 2.D3 | Dọn ở **4 công cụ khác nhau** (Duyệt, Ảnh mờ, Chụp màn hình, Biên lai…) | **Hộp đồ nghề** mở khoá và hiện trong sheet chúc mừng lần thứ 4 | [ ] |
| 2.D4 | Ẩn ≥1 mục vào Két | **Người giữ két** mở khoá (kiểm tra ở tab Hoạt động) | [ ] |
| 2.D5 | Đạt ngưỡng 100 mục (hoặc 100 MB) | Huy hiệu tương ứng bật; **không** bật lặp lại ở lần dọn sau | [ ] |
| 2.D6 | Một lần dọn mở 2 huy hiệu cùng lúc | Sheet hiện cả hai, không tràn màn hình | [ ] |

## 2.E Hoạt động & biểu đồ

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.E1 | Tab Hoạt động: thứ tự khối | Chuỗi ngày → Mục tiêu tháng → Huy hiệu → Tổng giải phóng → biểu đồ 30 ngày → theo công cụ | [ ] |
| 2.E2 | Biểu đồ 30 ngày | Cột của hôm nay cao đúng với số vừa dọn | [ ] |
| 2.E3 | Phân bổ theo công cụ | Có dòng cho từng công cụ đã dùng, tên đúng (ví dụ "Ảnh đã nén", "Video đã nén") | [ ] |

## 2.F Dữ liệu cũ & độ bền

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 2.F1 | **Người dùng cũ:** cài đè lên bản có lịch sử trước đây | Tổng "Đã giải phóng" **không giảm/không mất** | [ ] |
| 2.F2 | Như 2.F1 | Không bật hàng loạt huy hiệu cùng lúc khi mở lần đầu | [ ] |
| 2.F3 | Dọn > 200 lần (hoặc đã có >200 mục lịch sử) | Tổng trọn đời tiếp tục tăng, **không** giảm khi lịch sử cắt bớt | [ ] |
| 2.F4 | Vuốt tắt app ngay sau khi dọn xong | Mở lại: số liệu đã lưu | [ ] |

**Hạn chế đã biết:** số MB giải phóng là ước lượng; chia sẻ chỉ gửi ảnh thẻ, không gửi dữ liệu cá nhân.

**Tiêu chí hoàn thành GĐ2:** 2.A1–2.A5, 2.B3–2.B5, 2.C1–2.C2, 2.D3, 2.F1 đạt.

---

# GIAI ĐOẠN 3 — Dọn thông minh

**Mục tiêu:** quét lại nhanh nhờ cache; có gợi ý đúng lúc; lọc biên lai chính xác bằng nhận dạng chữ (OCR) trên máy.

**Thay đổi cần test:** cache chữ ký ảnh (`sig_cache.txt`) lưu bền; quét 4 ảnh song song; tuỳ chọn quét **Tất cả**; mục **Gợi ý cho bạn** (tối đa 3); OCR bằng ML Kit.

**Dữ liệu chuẩn bị:** ≥6 ảnh giống nhau/gần giống · ≥3 ảnh mờ · ≥3 ảnh chụp màn hình · ≥2 hoá đơn rõ chữ (nên có 1 hoá đơn **tiếng Việt có dấu**) · 1 ảnh tài liệu in · 1 ảnh phong cảnh rất sáng · (tuỳ chọn) ≥10 ảnh chụp màn hình cũ >90 ngày và ≥20 ảnh chat cũ >60 ngày.

## 3.A Cache quét

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 3.A1 | Cài đặt → "Số ảnh cần quét" | Có 4 lựa chọn: 1.000 / 3.000 / 10.000 / **Tất cả**; ghi chú nói lần sau chỉ phân tích ảnh mới | [ ] |
| 3.A2 | Chọn **Tất cả** → quét lần 1 (cache trống). Bấm giờ: ____ giây | Hoàn tất, có kết quả | [ ] |
| 3.A3 | Không đổi gì → quét lần 2. Bấm giờ: ____ giây | **Nhanh hơn rõ** lần 1; kết quả **giống hệt** lần 1 (số nhóm, số ảnh mờ) | [ ] |
| 3.A4 | Chụp thêm 2–3 ảnh mới (1 ảnh gần giống ảnh cũ) → quét | Ảnh mới được tính (nhóm giống cập nhật); vẫn nhanh | [ ] |
| 3.A5 | Chỉnh sửa 1 ảnh (làm mờ bằng app Ảnh) → quét | Ảnh đó được phân tích lại và xuất hiện trong "Ảnh mờ" | [ ] |
| 3.A6 | Đổi độ nhạy **ảnh mờ / độ giống** → quét lại | Kết quả đổi theo độ nhạy; vẫn nhanh (cache không phụ thuộc độ nhạy) | [ ] |
| 3.A7 | Xoá 1 ảnh bằng app khác → quét | Không crash; ảnh không còn trong kết quả | [ ] |
| 3.A8 | Đóng hẳn app, mở lại, quét | Vẫn nhanh (cache lưu bền) | [ ] |
| 3.A9 | Bấm **Dừng** giữa lúc quét, rồi quét lại | Không hỏng; quét tiếp được; phần đã làm không phải làm lại (hoặc ít nhất không sai kết quả) | [ ] |
| 3.A10 | Vuốt tắt app giữa lúc quét, mở lại và quét | Không crash, cache không hỏng | [ ] |
| 3.A11 | Kiểm tra file cache: `adb shell run-as com.example.photo_cleaner find . -name sig_cache.txt` rồi `head -3` | Dòng đầu `PCSIG1`, các dòng sau dạng `id<TAB>mod<TAB>hash<TAB>sharp<TAB>bright` | [ ] |

## 3.B Gợi ý thông minh

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 3.B1 | Cài mới (chưa quét) → mở Dọn dẹp | Mục **Gợi ý cho bạn** có "Đến lúc quét lại — bạn chưa quét lần nào". Chạm → bắt đầu quét | [ ] |
| 3.B2 | Quét xong, mở lại Dọn dẹp | Gợi ý "quét lại" biến mất (vừa quét) | [ ] |
| 3.B3 | Có ≥3 ảnh mờ | Có gợi ý "N ảnh mờ" | [ ] |
| 3.B4 | Có ảnh trùng cộng ≥5 MB | Có gợi ý "~X trong ảnh giống nhau". Ít hơn 5 MB thì **không** hiện | [ ] |
| 3.B5 | ≥10 ảnh chụp màn hình cũ >90 ngày | Có gợi ý ảnh chụp màn hình cũ. Chạm → công cụ mở, **đã chọn sẵn đúng các ảnh cũ** (số chọn khớp gợi ý) | [ ] |
| 3.B6 | ≥20 ảnh chat cũ >60 ngày | Có gợi ý ảnh chat cũ, chọn sẵn | [ ] |
| 3.B7 | Nhiều điều kiện cùng đúng | Chỉ hiện **tối đa 3**, gợi ý tác động lớn nhất đứng trước | [ ] |
| 3.B8 | Đổi ngày hệ thống **+8 ngày**, mở Dọn dẹp | Gợi ý "Lần quét cuối cách đây N ngày" lên đầu. **Nhớ đặt lại ngày** | [ ] |
| 3.B9 | Đổi ngày +6 ngày | **Chưa** có gợi ý quét lại (ngưỡng 7 ngày) | [ ] |
| 3.B10 | Xoá hết ảnh mờ rồi về Dọn dẹp | Gợi ý ảnh mờ biến mất/giảm theo số còn lại | [ ] |

> Mẹo tạo dữ liệu "cũ" nếu máy không có: ảnh phải mang ngày chụp cũ trong MediaStore. Cách đơn giản nhất là dùng ảnh/chụp màn hình có sẵn từ lâu. Nếu ảnh đẩy từ máy tính vẫn mang ngày hôm nay thì bỏ qua 3.B5–3.B6 và ghi "không có dữ liệu".

## 3.C OCR biên lai & tài liệu

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 3.C1 | Dọn dẹp → **Biên lai & tài liệu** (sau khi quét) | Danh sách "đoán" ban đầu (có thể lẫn ảnh không phải hoá đơn). Có thẻ **Lọc chính xác bằng nhận dạng chữ** | [ ] |
| 3.C2 | Bấm **Chạy** | "Đang đọc chữ… x / y" + thanh tiến độ; giao diện không đứng | [ ] |
| 3.C3 | Bấm **Dừng** giữa chừng | Dừng; danh sách giữ nguyên như trước (không bị lọc dở) | [ ] |
| 3.C4 | Chạy lại, chờ xong | Thẻ thành "Đã lọc… Giữ lại x / y"; hoá đơn/tài liệu thật **còn**; ảnh phong cảnh sáng **bị loại** | [ ] |
| 3.C5 | Hoá đơn tiếng Việt có dấu (Tổng cộng, Thanh toán, VAT…) | Được giữ lại | [ ] |
| 3.C6 | Ảnh có chữ nhưng không phải hoá đơn (ví dụ biển hiệu 3–4 chữ) | Bị loại | [ ] |
| 3.C7 | Bấm **Đặt lại** | Trở về danh sách ban đầu | [ ] |
| 3.C8 | Chạy OCR, rồi xoá 1 ảnh trong danh sách | Số "Giữ lại" cập nhật, không crash | [ ] |
| 3.C9 | Đóng app, mở lại | Kết quả OCR **mất** (chỉ giữ trong phiên) — đúng thiết kế | [ ] |
| 3.C10 | Chạy OCR khi danh sách rỗng | Không crash; nút bị ẩn/vô hiệu | [ ] |
| 3.C11 | Bật chế độ máy bay rồi chạy OCR | Vẫn chạy được (OCR chạy trên máy, không cần mạng) | [ ] |
| 3.C12 | (iOS) Chạy OCR | Hoạt động, không crash do thiếu ML Kit | [ ] |

**Hạn chế đã biết:**
- Số `~MB` vẫn là ước lượng, không phải dung lượng thật.
- OCR có thể loại nhầm hoá đơn mờ/nghiêng.
- Quét "Tất cả" lần đầu trên thư viện hàng chục nghìn ảnh có thể rất lâu; chưa có quét nền.
- ML Kit làm app nặng thêm vài chục MB.
- Ảnh được sửa mà không đổi thời gian sửa đổi có thể dùng kết quả cũ.

**Tiêu chí hoàn thành GĐ3:** 3.A2–3.A3 (lần 2 nhanh rõ), 3.A5, 3.B1, 3.B3, 3.B7, 3.C4–3.C5 đạt.

---

# GIAI ĐOẠN 4 — Nén & quản lý video

**Mục tiêu:** liệt kê video nặng theo dung lượng thật, xem trước, nén an toàn, giữ bản gốc đến khi xác nhận.

**Thay đổi cần test:** màn **Nén video** mới (lọc ≥100 MB/≥500 MB, sắp xếp, xem trước), nén bằng `light_compressor_v2` (Nhẹ/Cân bằng/Mạnh), tiến độ + Huỷ, quy tắc "nhỏ hơn ≥10% mới giữ", lưu video mới vào thư viện.

**Dữ liệu chuẩn bị:**
- V1: video ngắn ~10–30 giây quay bằng máy (có tiếng nói/nhạc để kiểm tra âm thanh).
- V2: video dài/nặng ≥100 MB (ví dụ quay 1080p 2–3 phút).
- V3: video đã rất nhẹ (≤5 MB) hoặc đã nén qua Zalo.
- Máy còn trống ít nhất 2 GB.
- Trước khi test: `flutter pub get`, dừng hẳn app, chạy lại (có plugin native mới + `minSdk` 24).

## 4.A Danh sách & bộ lọc

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 4.A1 | Dọn dẹp → **Nén video** | Có vòng tải rồi lưới video; mỗi ô có dung lượng thật (dưới trái) và độ dài (dưới phải) | [ ] |
| 4.A2 | So dung lượng ở ô với thông tin chi tiết trong app Ảnh/Files | Khớp (sai lệch nhỏ chấp nhận) | [ ] |
| 4.A3 | Bộ lọc **≥100 MB**, rồi **≥500 MB** | Chỉ còn video đủ lớn; không có thì hiện "Không có video phù hợp." | [ ] |
| 4.A4 | Sắp xếp **Dung lượng / Độ dài / Mới nhất** | Thứ tự giảm dần theo tiêu chí đúng | [ ] |
| 4.A5 | Máy không có video | Hiện trạng thái trống, không crash | [ ] |
| 4.A6 | Chỉ liệt kê tối đa ~40 video lớn nhất theo độ phân giải×thời lượng | Ghi nhận: video nhỏ có thể không xuất hiện (hạn chế đã biết) | [ ] |

## 4.B Xem trước

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 4.B1 | Chạm nút ▶ ở góc ô | Bảng xem trước mở, video tự phát, lặp lại | [ ] |
| 4.B2 | Chạm vào video | Tạm dừng/tiếp tục | [ ] |
| 4.B3 | Vuốt xuống đóng | Âm thanh dừng ngay, không phát nền | [ ] |
| 4.B4 | Mở xem trước nhiều video liên tiếp | Không crash, không treo | [ ] |
| 4.B5 | Video dọc và video ngang | Tỉ lệ khung hình đúng, không méo | [ ] |
| 4.B6 | Chạm ô (không phải ▶) | Chọn/bỏ chọn, **không** mở xem trước | [ ] |

## 4.C Nén cơ bản

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 4.C1 | Chọn V1, mức **Cân bằng**. Nút dưới hiện "Nén 1 video · X MB" | Dung lượng tổng khớp video đã chọn | [ ] |
| 4.C2 | Bấm Nén | Thanh tiến độ chạy tới 100%, chữ "Video 1 / 1 · N%"; các nút lọc/mức bị khoá | [ ] |
| 4.C3 | Xong | Hộp thoại "Đã lưu 1 video nén", ghi số MB nhẹ hơn | [ ] |
| 4.C4 | Mở app Ảnh | Có video mới tên `…_c`; **xem được, có hình, có tiếng**, tỉ lệ khung hình đúng, độ dài giống bản gốc | [ ] |
| 4.C5 | Chọn **Giữ video gốc** | Video gốc còn nguyên; không xoá gì | [ ] |
| 4.C6 | Làm lại, chọn **Chuyển video gốc** → xác nhận quyền hệ thống | Bản gốc vào "Đã xoá gần đây"; hiện màn chúc mừng đúng số MB tiết kiệm | [ ] |
| 4.C7 | Tab Dung lượng → Hoạt động | Có dòng **Video đã nén**; tổng giải phóng/chuỗi/mục tiêu tháng tăng | [ ] |
| 4.C8 | Quay lại màn Nén video | Danh sách làm mới (bản gốc đã chuyển đi không còn) | [ ] |

## 4.D Chất lượng & mức nén

Ghi kết quả thực tế trên cùng một video V2:

| Mức | Dung lượng gốc | Dung lượng sau nén | Giảm % | Thời gian nén | Chất lượng xem |
|---|---|---|---|---|---|
| Nhẹ | | | | | |
| Cân bằng | | | | | |
| Mạnh | | | | | |

| Mã | Mong đợi | Đạt |
|---|---|---|
| 4.D1 | Mạnh nhỏ hơn Cân bằng, Cân bằng nhỏ hơn Nhẹ | [ ] |
| 4.D2 | Mức Nhẹ/Cân bằng xem bình thường; mức Mạnh vẫn xem được (có thể mờ hơn) | [ ] |
| 4.D3 | Độ dài video nén = độ dài gốc (±1 giây), âm thanh đồng bộ hình | [ ] |

## 4.E Huỷ, chặn & lỗi

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 4.E1 | Chọn 2–3 video, bấm Nén, **bấm Huỷ** giữa chừng | Hiện "Đang huỷ…", dừng trong vài giây; nút/bộ lọc mở lại | [ ] |
| 4.E2 | Sau 4.E1 | Các video **đã xong trước đó** (nếu có) vẫn được lưu và hỏi giữ/chuyển gốc; video đang nén dở **không** để lại bản hỏng trong thư viện | [ ] |
| 4.E3 | Nén video đã rất nhẹ (V3) | "Không có video nào nén nhỏ hơn được." — không tạo bản sao thừa | [ ] |
| 4.E4 | Chọn hỗn hợp V1+V3 | V1 lưu, V3 bị bỏ; hộp thoại ghi "(bỏ qua 1)" | [ ] |
| 4.E5 | Đang nén, bấm nút Back của máy | Không thoát được; phải Huỷ trước | [ ] |
| 4.E6 | Đang nén, nhấn Home (xuống nền) vài giây rồi quay lại | Ghi nhận thực tế: tiếp tục / dừng / lỗi: ____ (hạn chế đã biết: cần giữ app mở) | [ ] |
| 4.E7 | Khoá màn hình khi đang nén | Ghi nhận thực tế: ____ | [ ] |
| 4.E8 | Máy gần đầy bộ nhớ khi nén video lớn | Báo lỗi hoặc bỏ qua, **không treo**; bản gốc nguyên vẹn | [ ] |
| 4.E9 | Nén video lớn ≥100 MB | Hoàn tất, giao diện vẫn phản hồi (nút Huỷ bấm được) | [ ] |
| 4.E10 | Từ chối quyền thư viện khi lưu | Báo lỗi/bỏ qua, không crash | [ ] |
| 4.E11 | Kiểm tra file tạm sau khi nén xong | `adb shell run-as com.example.photo_cleaner find . -name "*_c.mp4"` → không còn file nén tồn trong thư mục app | [ ] |

## 4.F Tích hợp chéo

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 4.F1 | Nén video, rồi vào **Video dung lượng lớn** (ToolScreen) | Danh sách cập nhật; xoá video bằng công cụ này vẫn hoạt động | [ ] |
| 4.F2 | Nén video rồi ẩn bản nén vào Két (GĐ1) | Hoạt động bình thường | [ ] |
| 4.F3 | Kiểm tra huy hiệu **Hộp đồ nghề** | "Nén video" tính là một công cụ riêng (kind `videocompress`) | [ ] |

**Hạn chế đã biết (không báo lỗi):**
- Bản nén mang **ngày hôm nay** và **mất GPS/metadata**.
- Chưa kiểm tra dung lượng trống trước khi nén (chỉ nhắc trên màn hình).
- Chưa nén nền: cần giữ app mở.
- Video lưu trên iCloud (iOS) có thể phải tải về trước nên chậm.
- Danh sách chỉ lấy khoảng 40 video lớn nhất theo độ phân giải × thời lượng.

**Tiêu chí hoàn thành GĐ4:** 4.A1, 4.A3, 4.C2–4.C6, 4.D1, 4.E1–4.E3, 4.E5, 4.E8 đạt; bản gốc không bao giờ bị xoá khi chưa xác nhận.

---

# GIAI ĐOẠN 5 — Icon app mới

**Mục tiêu:** icon ngoài màn hình chính là icon mới (khung ảnh + tia sáng, nền xanh lá), không còn icon Flutter mặc định; logo trong app khớp với icon.

**Thay đổi cần test:** bộ ảnh trong `assets/icon/`, cấu hình `flutter_launcher_icons`, `AppMark` vẽ lại.

**Chuẩn bị:**
```bash
flutter pub get
dart run flutter_launcher_icons
flutter run -d <ID_iPhone>      # chạy lại hẳn, không hot reload
```
Nếu iPhone vẫn hiện icon cũ: xoá app khỏi iPhone rồi cài lại (iOS giữ cache icon).

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 5.1 | `dart run flutter_launcher_icons` | Chạy xong không báo lỗi; tạo/ghi đè icon trong `android/` và `ios/` | [ ] |
| 5.2 | (iOS) Nhìn icon trên màn hình chính | Icon xanh lá, khung ảnh trắng + tia sáng; **không** có viền trắng/đen thừa ở góc | [ ] |
| 5.3 | (iOS) Tên dưới icon | "Photo Cleaner" (hoặc tên bạn đặt), không bị cắt xấu | [ ] |
| 5.4 | (Android) Icon trên launcher | Hình khung ảnh nằm gọn giữa nền xanh, **không bị cắt** | [ ] |
| 5.5 | (Android) Đổi dạng icon trong Cài đặt launcher: tròn / bo góc / giọt nước | Hình vẫn nguyên vẹn ở mọi dạng | [ ] |
| 5.6 | (Android 13+) Bật "Themed icons" | Icon đổi sang bản một màu theo hình nền, vẫn nhận ra khung ảnh + tia sáng | [ ] |
| 5.7 | Icon ở kích thước nhỏ (thư mục, tìm kiếm) | Vẫn nhận ra được | [ ] |
| 5.8 | Mở app → màn chào và màn đăng nhập | Logo trong app **giống** icon (xanh lá, khung ảnh, tia sáng), không méo | [ ] |
| 5.9 | Chế độ tối | Icon và logo vẫn rõ | [ ] |

**Hạn chế đã biết:** chưa có icon chế độ tối / nhuộm màu riêng của iOS 18. Logo xanh lá khác tông xanh dương chủ đạo của giao diện (chủ ý, chưa đổi màu chủ đạo).

**Tiêu chí hoàn thành GĐ5:** 5.1, 5.2 hoặc 5.4 đạt (tuỳ máy test) và 5.8 đạt.

---

# GIAI ĐOẠN 6 — Đăng nhập thật (Supabase)

**Mục tiêu:** đăng ký/đăng nhập thật bằng email + mật khẩu và Google; xác nhận email; quên mật khẩu; đổi tên, đổi mật khẩu, đăng xuất, xoá tài khoản; vẫn dùng được ở chế độ khách.

**Thay đổi cần test:** `AuthService`, `SessionProvider` (xác thực thật), màn đăng nhập, màn Tài khoản, màn đặt mật khẩu mới, deep link `photocleaner://login-callback/`, quyền INTERNET.

**Chuẩn bị (bắt buộc):**
1. Làm theo `docs/SUPABASE_SETUP.md` mục 1–5 (và mục 6 nếu test Google).
2. Tạo `env.json` từ `env.example.json`, điền URL + anon key thật.
3. `python3 patch_platforms.py`, `flutter pub get`.
4. Chạy từ **terminal**: `flutter run -d <ID_iPhone> --dart-define-from-file=env.json` (bấm ▶ trong Xcode không truyền khoá).
5. Có 2 email thật để test (một để đăng ký, một dự phòng) và quyền mở email **trên chính điện thoại test**.
6. Lưu ý: gói miễn phí giới hạn rất ít email/giờ; nếu gặp "quá nhiều lần", đợi hoặc cấu hình SMTP riêng.

## 6.A Cấu hình & chế độ khách

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.A1 | Chạy **không** có `--dart-define-from-file` | Màn đăng nhập hiện khung đỏ "Bản này chưa kết nối máy chủ đăng nhập…"; nút Đăng nhập/Tạo tài khoản/Google/Apple **bị mờ** | [ ] |
| 6.A2 | Như 6.A1, bấm **Tiếp tục với tư cách khách** | Vào app dùng bình thường; Cài đặt hiện "Khách" + nút Đăng nhập | [ ] |
| 6.A3 | Chạy **có** khoá | Không còn khung đỏ; các nút hoạt động | [ ] |
| 6.A4 | Người dùng cũ (bản trước có "hồ sơ giả lập") nâng cấp lên | Hiện là Khách (hồ sơ giả bị xoá), không còn tên/email giả | [ ] |
| 6.A5 | Dòng mô tả trên màn đăng nhập | Không còn nhắc "gói Pro" | [ ] |

## 6.B Đăng ký

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.B1 | Tab **Đăng ký**, để trống tên, bấm Tạo tài khoản | Lỗi "Nhập tên của bạn" | [ ] |
| 6.B2 | Email `abc`, `a@b` | Lỗi "Email không hợp lệ" | [ ] |
| 6.B3 | Mật khẩu `abc12` | Lỗi "Tối thiểu 8 ký tự" | [ ] |
| 6.B4 | Mật khẩu `abcdefgh` / `12345678` | Lỗi cần chữ số / cần chữ cái tương ứng | [ ] |
| 6.B5 | Tên + email thật + mật khẩu `Matkhau123` → Tạo tài khoản | Nút đổi "Vui lòng đợi…" rồi chuyển về tab Đăng nhập, khung xanh "Đã gửi liên kết xác nhận tới …" | [ ] |
| 6.B6 | Mở hộp thư (cả thư rác) | Có thư xác nhận từ Supabase (ghi thời gian đến: ____) | [ ] |
| 6.B7 | Đăng nhập **trước khi** bấm link xác nhận | Lỗi "Email chưa được xác nhận…" | [ ] |
| 6.B8 | Bấm link xác nhận **trên điện thoại** | Mở lại app (không báo lỗi route); ghi nhận: vào app luôn / quay về đăng nhập: ____ | [ ] |
| 6.B9 | Sau 6.B8, đăng nhập bằng tài khoản đó | Thành công | [ ] |
| 6.B10 | Đăng ký lại cùng email | Ghi nhận thông báo thực tế: ____ (Supabase có thể báo như thành công để không lộ email tồn tại) | [ ] |
| 6.B11 | Trên Supabase → Authentication → Users | Thấy user mới; **không** thấy mật khẩu dạng chữ | [ ] |

## 6.C Đăng nhập

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.C1 | Để trống mật khẩu → Đăng nhập | Lỗi "Nhập mật khẩu" | [ ] |
| 6.C2 | Sai mật khẩu | Khung đỏ "Email hoặc mật khẩu không đúng." (không lộ lỗi kỹ thuật) | [ ] |
| 6.C3 | Đúng email + mật khẩu (lần đầu cài) | Sang bước xin quyền ảnh, rồi vào app | [ ] |
| 6.C4 | Cài đặt | Hiện đúng tên, email, chữ cái đầu; có nút **Quản lý tài khoản** và **Đăng xuất** | [ ] |
| 6.C5 | Vuốt tắt app hẳn, mở lại | **Vẫn đăng nhập**, không phải nhập lại | [ ] |
| 6.C6 | Bật chế độ máy bay → đăng nhập | Khung đỏ "Không có kết nối mạng…"; không crash, không treo | [ ] |
| 6.C7 | Bấm nút đăng nhập liên tục nhiều lần | Chỉ gửi một lần (nút mờ "Vui lòng đợi…") | [ ] |
| 6.C8 | Biểu tượng con mắt | Hiện/ẩn mật khẩu | [ ] |
| 6.C9 | Thử sai mật khẩu 6–10 lần liên tiếp | Có lúc báo "quá nhiều lần…"; sau vài phút thử lại được | [ ] |
| 6.C10 | Đăng nhập từ **Cài đặt → Đăng nhập** (đã qua onboarding) | Sau khi thành công về **thẳng app**, không bắt xem lại bước quyền ảnh | [ ] |

## 6.D Quên mật khẩu

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.D1 | **Quên mật khẩu?** → email sai định dạng | Lỗi "Email không hợp lệ" | [ ] |
| 6.D2 | Email đã đăng ký → Gửi liên kết | Hiện "Nếu có tài khoản…, chúng tôi đã gửi liên kết". Không còn dòng "chưa có server" | [ ] |
| 6.D3 | Email **chưa** đăng ký | Vẫn hiện cùng thông báo (không lộ email nào có tài khoản) | [ ] |
| 6.D4 | Mở thư, bấm link **trên điện thoại** | App mở ra màn **Đặt mật khẩu mới** | [ ] |
| 6.D5 | Mật khẩu yếu / hai ô không khớp | Hiện lỗi tương ứng, không gửi | [ ] |
| 6.D6 | Nhập mật khẩu mới hợp lệ → Lưu | Báo "Đã đổi mật khẩu", vào app | [ ] |
| 6.D7 | Đăng xuất, đăng nhập bằng mật khẩu **cũ** | Bị từ chối | [ ] |
| 6.D8 | Đăng nhập bằng mật khẩu **mới** | Thành công | [ ] |
| 6.D9 | Mở link đặt lại, bấm **Để sau** | Vào app; ghi nhận: đang ở trạng thái đăng nhập: ____ (đây là hành vi của Supabase vì link tạo phiên tạm) | [ ] |
| 6.D10 | Mở lại cùng link lần 2 (đã dùng/hết hạn) | Không crash; ghi nhận thông báo: ____ | [ ] |

## 6.E Google / Apple

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.E1 | Bấm **Google** | Mở trang đăng nhập Google trong trình duyệt của app | [ ] |
| 6.E2 | Chọn tài khoản Google | Trở lại app, đã đăng nhập, vào bước tiếp theo | [ ] |
| 6.E3 | Cài đặt hiện tên + email lấy từ Google | Đúng tên/email | [ ] |
| 6.E4 | Mở Google rồi **huỷ/đóng** trình duyệt | Quay lại màn đăng nhập, không crash, nút dùng lại được | [ ] |
| 6.E5 | Chưa bật Google trong Supabase (nếu thử) | Khung đỏ "Cách đăng nhập này chưa được bật." | [ ] |
| 6.E6 | Bấm **Apple** (tài khoản Apple miễn phí) | Khung đỏ "chưa được bật" hoặc lỗi dễ hiểu; **không crash** | [ ] |
| 6.E7 | (Khi có gói Apple Developer) đăng nhập Apple | Thành công như Google | [ ] |

## 6.F Quản lý tài khoản

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.F1 | Cài đặt → **Quản lý tài khoản** | Mở màn Tài khoản: email, ô tên, đổi mật khẩu, đăng xuất, vùng nguy hiểm | [ ] |
| 6.F2 | Đổi tên → Lưu tên | Báo "Đã cập nhật tên"; Cài đặt đổi theo; tắt mở app vẫn giữ | [ ] |
| 6.F3 | Xoá trống tên → Lưu | Lỗi "Nhập tên của bạn" | [ ] |
| 6.F4 | Đổi mật khẩu: yếu / không khớp | Hiện lỗi, không gửi | [ ] |
| 6.F5 | Đổi mật khẩu hợp lệ | Báo "Đã đổi mật khẩu"; đăng xuất rồi đăng nhập lại bằng mật khẩu mới được | [ ] |
| 6.F6 | **Đăng xuất** (trong màn Tài khoản) | Về màn đăng nhập (không còn kẹt màn Tài khoản ở dưới); vào lại app bằng Khách thì Cài đặt hiện "Khách" | [ ] |
| 6.F7 | Đăng xuất bằng nút ở Cài đặt | Về màn đăng nhập | [ ] |
| 6.F8 | **Xoá tài khoản** → Huỷ | Không xoá gì | [ ] |
| 6.F9 | Xoá tài khoản → **Xoá vĩnh viễn** | Về màn đăng nhập; trên Supabase → Users: user biến mất | [ ] |
| 6.F10 | Đăng nhập lại bằng tài khoản vừa xoá | Bị từ chối | [ ] |
| 6.F11 | Sau khi xoá tài khoản | Ảnh, Két, thống kê trên máy **vẫn còn nguyên** | [ ] |
| 6.F12 | Xoá tài khoản khi **chưa chạy** file SQL (nếu thử) | Khung báo lỗi kèm gợi ý máy chủ thiếu hàm xoá; không mất gì | [ ] |

## 6.G Bảo mật & phát hành

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.G1 | Tìm trong log `flutter run` chuỗi `eyJ` (token) hoặc mật khẩu bạn nhập | **Không** xuất hiện | [ ] |
| 6.G2 | (Android) `adb shell run-as com.example.photo_cleaner cat shared_prefs/FlutterSharedPreferences.xml \| grep -i "access_token\|refresh_token"` | Không có token trong SharedPreferences (phiên nằm trong bộ lưu bảo mật) | [ ] |
| 6.G3 | Kiểm tra `git status` | `env.json` **không** bị theo dõi (đã nằm trong `.gitignore`) | [ ] |
| 6.G4 | (Android) `flutter build apk --release --dart-define-from-file=env.json`, cài và đăng nhập | Đăng nhập được (kiểm tra quyền INTERNET trong bản release) | [ ] |
| 6.G5 | Chuyển vùng giữa Wi-Fi và 4G khi đang đăng nhập | Không crash; báo lỗi mạng dễ hiểu nếu mất kết nối | [ ] |
| 6.G6 | Đăng nhập trên 2 máy cùng tài khoản | Cả hai hoạt động; đổi tên ở máy này thì máy kia thấy sau khi mở lại | [ ] |

## 6.H Hồi quy với tính năng cũ

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| 6.H1 | Đăng nhập → quét, xoá ảnh, xem chúc mừng | Hoạt động như trước | [ ] |
| 6.H2 | Đăng xuất → thống kê, huy hiệu, chuỗi ngày | **Không mất** (dữ liệu trên máy độc lập với tài khoản) | [ ] |
| 6.H3 | Két riêng tư sau khi đăng nhập/đăng xuất | PIN và ảnh trong Két nguyên vẹn | [ ] |
| 6.H4 | Chế độ khách dùng đầy đủ tính năng dọn dẹp | Không bị khoá tính năng nào | [ ] |

**Hạn chế đã biết (không báo lỗi):**
- Đăng nhập Apple cần gói Apple Developer trả phí để thử.
- Email xác nhận/đặt lại phụ thuộc giới hạn SMTP của Supabase gói miễn phí.
- Chưa đồng bộ thống kê qua tài khoản (giai đoạn 7); đăng nhập hiện chỉ xác định bạn là ai.
- Màn "Điều khoản / Chính sách riêng tư" chưa có nội dung thật (cần trước khi lên App Store).
- Link email phải mở trên chính thiết bị đã cài app.

**Tiêu chí hoàn thành GĐ6:** 6.A1–6.A3, 6.B5–6.B9, 6.C2–6.C5, 6.D4–6.D8, 6.E1–6.E2 (Google), 6.F5–6.F6, 6.F9–6.F11, 6.G1 đạt.

---

# HỒI QUY CUỐI (chạy sau cùng, ~10 phút)

| Mã | Thao tác | Kết quả mong đợi | Đạt |
|---|---|---|---|
| R1 | Cài mới → toàn bộ luồng: onboarding → quét → xoá → chúc mừng | Không crash | [ ] |
| R2 | Duyệt tab nhanh 20 lần sau khi dùng các tính năng | Không chồng trang | [ ] |
| R3 | Quét lại sau khi nén video + ẩn ảnh + xoá | Số liệu đúng, không crash | [ ] |
| R4 | Tab Dung lượng khớp với tab Hoạt động | Tổng giải phóng nhất quán | [ ] |
| R5 | Dùng liên tục 10 phút | Không giật rõ rệt, không phình bộ nhớ bất thường | [ ] |
| R6 | Thu hồi quyền ảnh trong Cài đặt rồi mở app | Hiện màn xin quyền, không crash | [ ] |
| R7 | Xoay ngang màn hình | Không crash | [ ] |
| R8 | Chế độ tối + chữ lớn trong từng màn mới (Két, Chúc mừng, Nén video, OCR) | Chữ đọc được, không tràn | [ ] |

---

# BẢNG TỔNG KẾT

| Giai đoạn | Số ca | Đạt | Lỗi | Chặn | Ghi chú |
|---|---|---|---|---|---|
| 0. Build, giao diện | 6 + 10 + 9 + 6 = 31 | | | | |
| 1. Vault | 4 + 8 + 4 + 4 + 7 + 8 + 4 = 39 | | | | |
| 2. Gamification | 7 + 6 + 4 + 6 + 3 + 4 = 30 | | | | |
| 3. Dọn thông minh | 11 + 10 + 12 = 33 | | | | |
| 4. Video | 6 + 6 + 8 + 3 + 11 + 3 = 37 | | | | |
| 5. Icon | 9 | | | | |
| 6. Đăng nhập | 5 + 11 + 10 + 10 + 7 + 12 + 6 + 4 = 65 | | | | |
| Hồi quy | 8 | | | | |

**Kết luận:** ☐ Có thể dùng · ☐ Cần sửa lỗi trước · ☐ Chưa dùng được

**Ưu tiên nếu ít thời gian (≈30 phút):** 0.A3–0.A5 → 0.B3–0.B4 → 1.B1–1.B3, 1.F1–1.F2, 1.F6 → 2.A1–2.A2 → 3.A2–3.A3 → 4.C1–4.C6 → 4.E1 → 5.1–5.2 → 6.A1, 6.B5–6.B9, 6.C2–6.C5.

---

# MẪU BÁO LỖI

```
Mã ca:            (ví dụ 1.F2)
Giai đoạn:        (0–4)
Thiết bị / OS:    (ví dụ SM A217F, Android 13)
Build:            (debug/release, ngày build)
Thao tác đã làm:
Kết quả thực tế:
Kết quả mong đợi:
Tái hiện:         luôn luôn / thỉnh thoảng / 1 lần
Ảnh chụp / log:   (đính kèm)
Mức độ:           Chặn / Nghiêm trọng / Nhẹ / Thẩm mỹ
```

Lấy log nhanh:

```bash
flutter run 2>&1 | tee run.log
adb logcat -s flutter AndroidRuntime
adb logcat -c   # xoá log cũ trước khi tái hiện lỗi
```

Khi báo lỗi, dán: mã ca + 30–50 dòng log quanh thời điểm lỗi (đặc biệt dòng `Exception`, `E/flutter`, `FATAL EXCEPTION`).
