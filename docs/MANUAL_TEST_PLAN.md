# Photo Cleaner — Bản test thủ công

Máy test chính: Android SM A217F. Làm thêm phần iOS nếu có thiết bị / simulator.
Cách ghi: tick `[x]` khi đạt. Nếu lỗi, ghi mã bước (ví dụ `6.4`) + ảnh chụp / log vào mục **Ghi nhận lỗi** ở cuối.

> Lưu ý: các tính năng mới (Vault mã hoá, Gamification, Cache quét, OCR, animation) **chưa từng được biên dịch hay chạy thử** trước bản test này. Nếu app không build được, dừng ở phần 1 và gửi log.

---

## 0. Chuẩn bị

1. Chạy trong thư mục dự án:
   ```bash
   flutter clean
   flutter pub get
   python3 patch_platforms.py        # chạy lại cho chắc, an toàn khi chạy nhiều lần
   ```
2. Chuẩn bị dữ liệu ảnh trên máy test (nên dùng ảnh thử, không dùng ảnh quan trọng):
   - [ ] ≥ 6 ảnh giống nhau / gần giống (chụp liên tiếp cùng một vật 3–4 tấm, copy thêm vài bản trùng).
   - [ ] ≥ 3 ảnh cố tình mờ (rung tay, chụp mất nét).
   - [ ] ≥ 3 ảnh chụp màn hình.
   - [ ] ≥ 2 ảnh hoá đơn / biên lai (chụp trên nền sáng, thấy chữ rõ), 1 ảnh tài liệu in.
   - [ ] 1 ảnh phong cảnh sáng (để kiểm tra nhận nhầm tài liệu).
   - [ ] ≥ 1 video ngắn và 1 video dài/nặng.
   - [ ] (Tuỳ chọn) ≥ 25 ảnh chụp màn hình cũ hơn 3 tháng và ảnh trong album Zalo/WhatsApp — nếu không có, bỏ qua mục 5.3.
3. Cài bản debug lên máy: `flutter run` (sau khi đã **dừng hẳn** app cũ — không dùng hot reload cho lần test đầu, vì `MainActivity` đã đổi).

---

## 1. Kiểm thử tự động (máy dev)

| # | Lệnh | Mong đợi | Đạt |
|---|---|---|---|
| 1.1 | `flutter analyze` | Không có `error`. (Warning / info nhỏ chấp nhận được, ghi lại số lượng.) | [ ] |
| 1.2 | `flutter test` | Tất cả test pass. Gồm các file: `logic_test`, `vault_crypto_test`, `achievements_test`, `sig_cache_test`, `suggestions_test`, `receipt_text_test`. | [ ] |
| 1.3 | `flutter build apk --debug` | Build thành công. | [ ] |
| 1.4 | (iOS) `cd ios && pod install --repo-update` rồi `flutter build ios --no-codesign` | Build thành công (ML Kit cần iOS 15.5+). | [ ] |

Nếu `1.2` có test fail: gửi nguyên đoạn output của test đó.

---

## 2. Khởi động & điều hướng

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 2.1 | Mở app lần đầu (cài mới / xoá dữ liệu app) | Splash → 3 trang giới thiệu → Đăng nhập / Dùng thử → Xin quyền ảnh → vào app. | [ ] |
| 2.2 | Cho phép truy cập ảnh | Vào tab **Duyệt**, thư viện tải xong (có số `n / tổng`). | [ ] |
| 2.3 | Chạm lần lượt 5 tab: Duyệt → Dọn dẹp → Thư viện → Dung lượng → Cài đặt | **Chỉ hiện đúng 1 trang tại một thời điểm**, không có chữ/thẻ của tab khác chồng lên. Chuyển tab có hiệu ứng mờ + trượt nhẹ, icon tab đang chọn phóng to nhẹ. | [ ] |
| 2.4 | Chuyển tab thật nhanh 10 lần liên tiếp | Không giật, không chồng trang, không crash. | [ ] |
| 2.5 | Cuộn Dọn dẹp xuống, sang tab khác, quay lại | Vị trí cuộn được giữ nguyên. | [ ] |
| 2.6 | Cài đặt → bật Chế độ tối / sáng | Mọi tab đổi màu đúng, chữ vẫn đọc được. | [ ] |
| 2.7 | Cài đặt → đổi English ↔ Tiếng Việt | Mọi nhãn trên 5 tab + màn con đổi ngôn ngữ, không còn chuỗi cũ. | [ ] |
| 2.8 | Cài đặt hệ thống → Cỡ chữ = lớn nhất → mở lại app | Layout không vỡ, không tràn chữ (app giới hạn tối đa 1.15×). | [ ] |
| 2.9 | Bật "Giảm chuyển động" của hệ thống (Remove animations) | Nội dung hiện ngay, không bị trống hay kẹt trong suốt. | [ ] |

---

## 3. Duyệt nhanh (Review)

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 3.1 | Tab Duyệt → **Quét N ảnh** | Hiện vòng tiến độ % chạy mượt, đếm `x / y`; nút **Dừng** hoạt động. | [ ] |
| 3.2 | Chờ quét xong | Hiện hero + chip "Tệ nhất / Tháng này / Tất cả" + danh sách nhóm ảnh giống. Ảnh nét nhất mỗi nhóm có viền xanh. | [ ] |
| 3.3 | Chạm một ảnh trong nhóm | Ảnh được đánh dấu xoá (mờ đi), số `~MB` ở hero chạy (đếm) theo. | [ ] |
| 3.4 | Bấm **Tự chọn** | Mọi ảnh trừ ảnh nét nhất được đánh dấu. **Đặt lại** bỏ hết. | [ ] |
| 3.5 | Bấm nút Xoá `N ảnh` → xác nhận | Hộp thoại xác nhận → hệ thống hỏi quyền xoá → sau khi đồng ý hiện **màn chúc mừng** (xem 8). Ảnh vào "Đã xoá gần đây" trong app Ảnh. | [ ] |
| 3.6 | Bấm Huỷ ở hộp thoại | Không xoá gì. | [ ] |
| 3.7 | Bấm nút làm mới (↻) | Quét lại bình thường. | [ ] |

---

## 4. Dọn dẹp — giao diện

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 4.1 | Mở tab Dọn dẹp | Thấy: tiêu đề, **hero** (Đã giải phóng / Có thể giải phóng + nút Quét nhanh), mục **Dọn thông minh** (lưới 2×2), mục **Công cụ khác** (danh sách 6 hàng). Không tile nào bị chữ xuống 3 dòng. | [ ] |
| 4.2 | Các thẻ hiện lần lượt (hiệu ứng) | Có hiệu ứng mờ + trượt lên lần lượt khi mở app. | [ ] |
| 4.3 | Nhấn giữ một thẻ / hàng | Co nhẹ khi nhấn, rung nhẹ khi chạm. | [ ] |
| 4.4 | Bấm **Quét nhanh** ở hero | Nút đổi thành thanh tiến độ "Đang quét x%"; xong → nút thành **Quét lại**; số "Có thể giải phóng" chạy lên. | [ ] |
| 4.5 | Tile hiện số đúng | Sau khi quét: Ảnh giống (số nhóm), Ảnh mờ, Ảnh chụp màn hình, Video lớn khớp với số thực. Trước khi quét: "Chưa quét" + mũi tên. | [ ] |
| 4.6 | Mở từng công cụ: Ảnh mờ / Chụp màn hình / Video lớn / Chụp liên tiếp / Biên lai & tài liệu / Ảnh từ chat / Video trùng | Mỗi màn mở bằng hiệu ứng mờ + trượt, hiện lưới ảnh; nếu rỗng hiện icon ✓ "Không có gì cần dọn". | [ ] |
| 4.7 | Trong màn công cụ, chạm chọn ảnh | Ảnh thu nhỏ nhẹ + tối đi, dấu tick đỏ bật ra; nút dưới hiện "Xoá N mục". Nhấn giữ ảnh → xem toàn màn hình. | [ ] |
| 4.8 | **Chụp liên tiếp** | Mỗi chùm: ảnh đẹp nhất có nhãn ĐẸP NHẤT và **không** được chọn sẵn; các ảnh còn lại được chọn sẵn. | [ ] |

---

## 5. Dọn thông minh (Giai đoạn 3)

### 5.1 Cache quét tăng dần

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 5.1.1 | Cài đặt → "Số ảnh cần quét" → chọn **Tất cả** | Có đủ 4 lựa chọn: 1,000 / 3,000 / 10,000 / Tất cả. Ghi chú nói rõ lần sau chỉ phân tích ảnh mới. | [ ] |
| 5.1.2 | Quét lần 1 (cache trống). **Bấm giờ**: ___ giây | Hoàn tất bình thường. | [ ] |
| 5.1.3 | Không đổi gì, quét lần 2. **Bấm giờ**: ___ giây | **Nhanh hơn rõ rệt** lần 1 (dự kiến vài giây), kết quả giống lần 1. | [ ] |
| 5.1.4 | Chụp thêm 2–3 ảnh mới (trong đó 1 ảnh gần giống ảnh cũ) → quét lại | Ảnh mới được tính: nhóm ảnh giống tăng / cập nhật. Vẫn nhanh. | [ ] |
| 5.1.5 | Chỉnh sửa 1 ảnh (ví dụ làm mờ bằng app Ảnh) → quét lại | Ảnh đó được phân tích lại (không dùng kết quả cũ): xuất hiện trong "Ảnh mờ". | [ ] |
| 5.1.6 | Đổi **Độ nhạy ảnh mờ / Độ giống** trong Cài đặt → quét lại | Kết quả đổi theo độ nhạy mới, quét vẫn nhanh (cache không phụ thuộc độ nhạy). | [ ] |
| 5.1.7 | Xoá 1 ảnh khỏi máy bằng app khác → quét lại | Không crash; ảnh không còn trong kết quả. | [ ] |
| 5.1.8 | Đóng hẳn app, mở lại, quét | Vẫn nhanh (cache lưu bền trên đĩa). | [ ] |

### 5.2 Gợi ý thông minh

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 5.2.1 | Cài mới / chưa quét lần nào, mở Dọn dẹp | Mục **Gợi ý cho bạn** có dòng "Đến lúc quét lại — Bạn chưa quét lần nào". Chạm → bắt đầu quét. | [ ] |
| 5.2.2 | Sau khi quét xong | Dòng "quét lại" biến mất (vì mới quét). Nếu có ≥ 3 ảnh mờ → có gợi ý "N ảnh mờ"; nếu ảnh trùng ≥ 5 MB → gợi ý "~X trong ảnh giống nhau". | [ ] |
| 5.2.3 | (Cần dữ liệu) ≥ 10 ảnh chụp màn hình cũ > 90 ngày | Có gợi ý "N ảnh chụp màn hình cũ". Chạm → màn công cụ mở và **đã chọn sẵn đúng các ảnh cũ**. | [ ] |
| 5.2.4 | (Cần dữ liệu) ≥ 20 ảnh chat cũ > 60 ngày | Có gợi ý ảnh chat cũ, đã chọn sẵn. | [ ] |
| 5.2.5 | Chỉ hiện tối đa 3 gợi ý, gợi ý lớn nhất đứng trước | Đúng. | [ ] |
| 5.2.6 | Đổi ngày hệ thống lên +8 ngày (hoặc chờ), mở lại Dọn dẹp | Gợi ý "Lần quét cuối cách đây N ngày" xuất hiện đầu danh sách. Nhớ đặt lại ngày. | [ ] |

### 5.3 OCR biên lai / tài liệu

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 5.3.1 | Dọn dẹp → **Biên lai & tài liệu** (sau khi quét) | Danh sách ban đầu là kết quả "đoán" theo độ sáng; có thể chứa cả ảnh không phải hoá đơn. Có thẻ **Lọc chính xác bằng nhận dạng chữ** ở trên. | [ ] |
| 5.3.2 | Bấm **Chạy** | Hiện "Đang đọc chữ… x / y" + thanh tiến độ; nút **Dừng** hoạt động. | [ ] |
| 5.3.3 | Chờ xong | Thẻ đổi thành "Đã lọc… Giữ lại x / y". Hoá đơn / tài liệu thật **vẫn còn**; ảnh phong cảnh sáng **bị loại**. | [ ] |
| 5.3.4 | Bấm **Đặt lại** | Trở về danh sách ban đầu. | [ ] |
| 5.3.5 | Chạy OCR rồi xoá 1 ảnh trong danh sách | Số "Giữ lại" cập nhật, không crash. | [ ] |
| 5.3.6 | Hoá đơn tiếng Việt có dấu (Tổng cộng, Thanh toán…) | Được giữ lại. | [ ] |
| 5.3.7 | (iOS) Chạy OCR | Hoạt động; không crash do thiếu thư viện ML Kit. | [ ] |

---

## 6. Két riêng tư (Vault) — mã hoá thật

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 6.1 | Dọn dẹp → **Két riêng tư** (lần đầu) | Màn "Tạo mã PIN" 4 số → nhập lại để xác nhận → vào két (trống). | [ ] |
| 6.2 | Nhập PIN xác nhận khác lần đầu | Báo "Hai mã không khớp", quay lại bước tạo. | [ ] |
| 6.3 | Banner trong két | Nói ảnh được **mã hoá AES-256** và cần khôi phục trước khi gỡ app / đổi máy. | [ ] |
| 6.4 | **Thêm ảnh** → chọn 2 ảnh + 1 video → Ẩn | Hệ thống hỏi quyền xoá ảnh gốc → đồng ý. Két hiện 3 mục có ảnh thu nhỏ (video có nút play). **App không bị tự thoát ra ngoài** trong lúc hộp thoại hệ thống hiện. | [ ] |
| 6.5 | Mở app Ảnh của máy | Ảnh vừa ẩn **không còn** trong thư viện. | [ ] |
| 6.6 | Nhấn giữ 1 ảnh trong két | Mở xem toàn màn hình (zoom được). Đóng lại. | [ ] |
| 6.7 | Nhấn giữ video | Báo "Hãy khôi phục video về thư viện để xem". | [ ] |
| 6.8 | **Kiểm tra mã hoá thật** (cần cáp USB + debug build): `adb shell run-as com.example.photo_cleaner ls app_flutter/vault` | Thấy các file `*.enc` và `*.thm`; **không** có file ảnh gốc không đuôi. | [ ] |
| 6.9 | `adb exec-out run-as com.example.photo_cleaner head -c 16 app_flutter/vault/<tên>.enc \| xxd` | 4 byte đầu là `5043 5631` ("PCV1"); **không** thấy `ffd8` (JPEG). | [ ] |
| 6.10 | Chụp màn hình khi đang ở trong két (nút nguồn + giảm âm lượng) | Bị chặn ("Không thể chụp màn hình") hoặc ảnh chụp đen. Ra khỏi két thì chụp được bình thường. | [ ] |
| 6.11 | Trong két, đưa app xuống nền (Home) rồi mở lại | App **trở về tab Dọn dẹp**; vào lại két phải nhập PIN. | [ ] |
| 6.12 | Nhập sai PIN 5 lần | Khoá 30 giây, có đếm ngược; các phím bị vô hiệu. Sau 30 giây nhập lại được. | [ ] |
| 6.13 | Bật **Mở khoá bằng sinh trắc học** (cần máy đã đăng ký vân tay/khuôn mặt) | Hiện yêu cầu xác thực → bật thành công. Máy không có sinh trắc học thì **ẩn** công tắc này. | [ ] |
| 6.14 | Thoát két, vào lại | Tự bật hộp xác thực sinh trắc học; vân tay đúng → vào két. Chạm biểu tượng vân tay ở góc dưới trái bàn phím PIN cũng gọi lại được. | [ ] |
| 6.15 | Huỷ hộp sinh trắc học → nhập PIN | Vẫn vào được bằng PIN. | [ ] |
| 6.16 | Chọn 1 mục → **Khôi phục** | Ảnh quay về thư viện (kiểm tra trong app Ảnh), biến mất khỏi két. | [ ] |
| 6.17 | Chọn 1 mục → **Xoá** → xác nhận | Mất vĩnh viễn, không vào "Đã xoá gần đây". | [ ] |
| 6.18 | Thêm ảnh vào két nhưng **từ chối** hộp thoại xoá của hệ thống | Báo "Chưa ẩn ảnh nào", két không giữ bản sao thừa. | [ ] |
| 6.19 | Thêm 1 ảnh rất lớn / video 100 MB+ | Không treo giao diện, không crash (xử lý trong nền). | [ ] |

---

## 7. Nén ảnh

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 7.1 | Dọn dẹp → **Nén ảnh** | Mở màn có 3 mức **Nhẹ / Cân bằng / Mạnh**, ảnh độ phân giải lớn nhất đứng đầu danh sách. | [ ] |
| 7.2 | Chọn vài ảnh, mức Cân bằng → **Nén N ảnh** | Hiện thanh tiến độ "Đang nén x / y". | [ ] |
| 7.3 | Khi xong → hộp thoại "Đã lưu N bản nén" → **Chuyển ảnh gốc** | Hộp thoại nói rõ tiết kiệm trung bình và tổng dung lượng; hệ thống hỏi quyền xoá; sau đó hiện màn chúc mừng đúng số MB tiết kiệm. | [ ] |
| 7.4 | Chọn **Giữ ảnh gốc** | Bản nén vẫn nằm trong thư viện, ảnh gốc giữ nguyên, không xoá gì. | [ ] |
| 7.5 | Mở ảnh đã nén | Hiển thị bình thường, đúng chiều (không bị xoay nghiêng). Lưu ý: bản nén **mất ngày chụp và GPS** (hạn chế đã biết). | [ ] |

---

## 7b. Nén video (Giai đoạn 4)

Chuẩn bị: có 2–3 video thật (nên có 1 video > 100 MB, 1 video ngắn < 10 MB). Dừng hẳn app và chạy lại (`flutter pub get` trước, vì có plugin mới).

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 7b.1 | Dọn dẹp → "Nén video" | Mở màn mới, có vòng tải rồi lưới video; mỗi ô hiện dung lượng thật (góc trái dưới) và độ dài (phải dưới) | [ ] |
| 7b.2 | Đổi bộ lọc ≥ 100 MB / ≥ 500 MB | Danh sách lọc đúng; không có video nào thì hiện "Không có video phù hợp." | [ ] |
| 7b.3 | Đổi sắp xếp Dung lượng / Độ dài / Mới nhất | Thứ tự đổi đúng (giảm dần) | [ ] |
| 7b.4 | Chạm nút ▶ ở góc ô | Bảng xem trước phát video, chạm vào video để tạm dừng/tiếp tục, vuốt xuống để đóng, âm thanh dừng | [ ] |
| 7b.5 | Chọn 1 video ngắn, mức "Cân bằng", bấm Nén | Thanh tiến độ chạy 0→100%, chữ "Video 1 / 1"; không văng app | [ ] |
| 7b.6 | Sau khi nén xong | Hộp thoại "Đã lưu 1 video nén", ghi số MB nhẹ hơn; vào thư viện ảnh của máy thấy video mới tên `..._c`, phát bình thường, có tiếng | [ ] |
| 7b.7 | Chọn "Giữ video gốc" | Video gốc còn nguyên; không có gì bị xoá | [ ] |
| 7b.8 | Lặp lại, chọn "Chuyển video gốc" → xác nhận | Gốc vào Đã xoá gần đây; có màn chúc mừng; tab Dung lượng → Hoạt động có dòng "Video đã nén" | [ ] |
| 7b.9 | Chọn 2–3 video, bấm Nén rồi bấm Huỷ giữa chừng | Hiện "Đang huỷ…", dừng trong vài giây; video đã xong trước đó (nếu có) vẫn được lưu; không có file rác trong thư viện | [ ] |
| 7b.10 | Nén video đã rất nhẹ (ví dụ vài MB) | Báo "Không có video nào nén nhỏ hơn được." (bản nén không nhỏ hơn 10% thì bị bỏ) | [ ] |
| 7b.11 | Đang nén, bấm nút Back của máy | Không thoát được (chặn), phải Huỷ trước | [ ] |
| 7b.12 | Mức "Mạnh" so với "Nhẹ" trên cùng video | Mạnh cho file nhỏ hơn rõ rệt; chất lượng xem được | [ ] |
| 7b.13 | Từ chối quyền thư viện / máy gần đầy bộ nhớ | Báo lỗi hoặc bỏ qua, không treo; ghi lại thông báo thật | [ ] |

---

## 8. Chúc mừng, chuỗi ngày, huy hiệu (Gamification)

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 8.1 | Hoàn tất 1 lần xoá bất kỳ | Hiện **sheet chúc mừng**: dấu ✓ bật ra, số MB chạy lên, "Chuỗi N ngày", thanh mục tiêu tháng. | [ ] |
| 8.2 | Lần xoá đầu tiên trên cài đặt mới | Có thẻ **Huy hiệu mới: Lần dọn đầu**. | [ ] |
| 8.3 | Bấm **Chia sẻ** | Mở khung chia sẻ của hệ thống kèm ảnh thẻ kết quả + câu chữ. Chia sẻ thử vào một app (Ghi chú / Zalo). Ảnh nhận được rõ nét. | [ ] |
| 8.4 | Bấm **Xong** | Sheet đóng, quay lại màn trước, số liệu đã cập nhật. | [ ] |
| 8.5 | Tab Dung lượng → **Hoạt động** | Thấy: thẻ chuỗi ngày (7 chấm, hôm nay có ✓), thẻ mục tiêu tháng, lưới 11 huy hiệu, rồi tổng giải phóng + biểu đồ 30 ngày. | [ ] |
| 8.6 | Đổi mục tiêu tháng 250 MB / 500 MB / 1 GB / 2 GB | Phần trăm và thanh vòng tròn đổi ngay; đóng mở app vẫn giữ lựa chọn. | [ ] |
| 8.7 | Chạm 1 huy hiệu | Hiện mô tả + "Đã mở khoá / Chưa mở khoá". | [ ] |
| 8.8 | Huy hiệu **Người giữ két** | Mở khoá sau khi két có ≥ 1 mục (xem ở tab Hoạt động). | [ ] |
| 8.9 | Dọn ở **≥ 4 công cụ khác nhau** (ví dụ review, blurry, screenshots, docs) | Huy hiệu **Hộp đồ nghề** mở khoá và hiện trong sheet chúc mừng. | [ ] |
| 8.10 | Dọn 2 ngày liên tiếp (đổi ngày hệ thống +1) | Chuỗi tăng lên 2. Bỏ qua 1 ngày trọn vẹn → chuỗi về 0 (nhưng "Kỷ lục" giữ nguyên). | [ ] |
| 8.11 | Người dùng cũ (đã có lịch sử trước bản này) | Tổng "Đã giải phóng" **không bị mất / không giảm**; không bị dồn hàng loạt thông báo huy hiệu mới. | [ ] |

---

## 9. Thông báo & Cài đặt

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 9.1 | Cài đặt → bật **Thanh trạng thái** (Android) | Xuất hiện thông báo thường trực: "Photo Cleaner — N nhóm giống · N ảnh mờ · có thể giải phóng ~X" + nút **Quét nhanh**. | [ ] |
| 9.2 | Bấm **Quét nhanh** trên thông báo (khi app đang đóng) | App mở, vào tab Duyệt và tự quét. | [ ] |
| 9.3 | Quét xong khi app đang mở | Nội dung thông báo cập nhật theo kết quả. | [ ] |
| 9.4 | Tắt công tắc | Thông báo thường trực biến mất. | [ ] |
| 9.5 | Nhắc quét định kỳ: Tắt / Hằng ngày / Hằng tuần | Lưu lại lựa chọn; bấm "Xem thử thông báo" hiện 1 thông báo mẫu. | [ ] |
| 9.6 | Từ chối quyền thông báo (Android 13+) | App không crash, báo cần cấp quyền. | [ ] |
| 9.7 | Cài đặt → **Xem lại giới thiệu** | Chạy lại splash/onboarding rồi quay về app. | [ ] |
| 9.8 | Đăng xuất / đăng nhập (giao diện giả lập) | Thẻ tài khoản đổi đúng tên / email; **không** lưu mật khẩu. | [ ] |

---

## 10. Thư viện & Dung lượng

| # | Thao tác | Mong đợi | Đạt |
|---|---|---|---|
| 10.1 | Tab Thư viện | Hero có tổng ảnh tháng, cột biểu đồ **mọc lên** có hiệu ứng, nút "Mở ngày đông nhất" hoạt động. | [ ] |
| 10.2 | Chuyển tháng (‹ ›) | Nội dung đổi, có hiệu ứng xuất hiện lại. | [ ] |
| 10.3 | Chạm một ngày trong lịch | Mở màn Ngày với đúng ảnh ngày đó. | [ ] |
| 10.4 | Tab Dung lượng → **Thư viện** | Vòng donut vẽ dần, 3 phân loại (Ảnh / Video / Chụp màn hình), cột 12 tháng mọc lên. | [ ] |
| 10.5 | Chuyển **Thư viện ↔ Hoạt động** | Nội dung từng phần hiện lần lượt; tiêu đề và nút chuyển không nháy lại. | [ ] |

---

## 11. Trường hợp biên & độ bền

| # | Tình huống | Mong đợi | Đạt |
|---|---|---|---|
| 11.1 | Thu hồi quyền ảnh trong Cài đặt hệ thống rồi mở app | Hiện màn "Cho phép truy cập ảnh" với nút Cho phép / Mở Cài đặt, không crash. | [ ] |
| 11.2 | Chỉ cấp quyền "ảnh đã chọn" (Android 14+/iOS) | App hoạt động với phần ảnh được cấp, hiện ghi chú quyền hạn chế ở tab Dung lượng. | [ ] |
| 11.3 | Thư viện rỗng / rất ít ảnh | Các màn hiện trạng thái trống đẹp, không chia cho 0, không crash. | [ ] |
| 11.4 | Xoay ngang màn hình | Không crash; bố cục chấp nhận được. | [ ] |
| 11.5 | Vuốt tắt app trong lúc đang quét, mở lại | Mở lại bình thường; cache không hỏng (quét tiếp vẫn chạy). | [ ] |
| 11.6 | Vuốt tắt app trong lúc đang thêm ảnh vào két | Mở lại: két không chứa file hỏng; ảnh gốc vẫn còn trong thư viện nếu chưa xoá. | [ ] |
| 11.7 | Hết dung lượng bộ nhớ / máy yếu (tuỳ chọn) | Quét và mã hoá báo lỗi nhẹ nhàng, không treo. | [ ] |
| 11.8 | Dùng liên tục 10 phút, mở/đóng nhiều màn | Không giật lag rõ rệt; bộ nhớ không phình bất thường (xem `flutter devtools` nếu muốn). | [ ] |
| 11.9 | Gỡ cài đặt app rồi cài lại | Két trống (đúng thiết kế: mã hoá gắn với máy/app) — kiểm tra bạn đã **khôi phục** ảnh quan trọng trước khi gỡ. | [ ] |

---

## 12. Ghi nhận lỗi

Với mỗi lỗi, ghi:

```
Mã bước:        (ví dụ 6.4)
Thiết bị / OS:  (ví dụ SM A217F, Android 13)
Thao tác đã làm:
Kết quả thực tế:
Kết quả mong đợi:
Ảnh chụp / log:  (kèm đoạn `flutter run` hoặc `adb logcat -s flutter`)
Mức độ:         Chặn / Nghiêm trọng / Nhẹ / Thẩm mỹ
```

Cách lấy log nhanh khi app lỗi:
```bash
flutter run 2>&1 | tee run.log          # chạy và lưu log
adb logcat -s flutter AndroidRuntime    # chỉ log của Flutter và crash
```

## 13. Tổng kết

| Khu vực | Số bước | Đạt | Lỗi |
|---|---|---|---|
| 1. Tự động | 4 | | |
| 2. Điều hướng | 9 | | |
| 3. Review | 7 | | |
| 4. Dọn dẹp UI | 8 | | |
| 5. Dọn thông minh | 21 | | |
| 6. Vault | 19 | | |
| 7. Nén ảnh | 5 | | |
| 8. Gamification | 11 | | |
| 9. Thông báo & Cài đặt | 8 | | |
| 10. Thư viện & Dung lượng | 5 | | |
| 11. Biên | 9 | | |

**Ưu tiên nếu ít thời gian:** 1.1–1.3 → 2.3 → 6.4, 6.8–6.9, 6.11 → 5.1.2–5.1.3 → 8.1 → 3.5.
