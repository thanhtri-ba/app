# Thiết lập đăng nhập thật (Supabase)

App dùng **Supabase Auth**: email + mật khẩu (có xác nhận email, đặt lại mật khẩu), Google và Apple qua trình duyệt, xoá tài khoản.
Chưa cấu hình thì app vẫn chạy ở **chế độ khách**, màn đăng nhập hiện thông báo "chưa kết nối máy chủ".

## 1. Tạo project
1. Vào https://supabase.com → đăng nhập → **New project**.
2. Chọn tổ chức, đặt tên (ví dụ `photo-cleaner`), **Region: Singapore** (gần Việt Nam), đặt Database password và **lưu lại**.
3. Đợi project khởi tạo (1–2 phút).

## 2. Lấy khoá cho app
Project Settings → **API** (hoặc **API Keys**):
- **Project URL**: dạng `https://abcdxyz.supabase.co`
- **anon / public key**: chuỗi dài bắt đầu bằng `eyJ…` (hoặc "publishable key" ở giao diện mới)

> **Tuyệt đối không dùng `service_role` key trong app.** Khoá đó bỏ qua mọi quyền bảo vệ dữ liệu.
> Khoá `anon` thì công khai theo thiết kế (an toàn nhờ Row Level Security), nhưng vẫn không đưa lên GitHub.

## 3. Bật đăng nhập email
Authentication → **Sign In / Providers** → **Email**:
- Enable Email provider: **Bật**
- **Confirm email: Bật** (khuyến nghị, người dùng phải bấm link trong thư)
- **Minimum password length: 8** (khớp với quy tắc trong app)

## 4. Cho phép quay lại app sau khi bấm link
Authentication → **URL Configuration**:
- **Site URL**: `photocleaner://login-callback/`
- **Redirect URLs** → Add URL, thêm **cả hai**:
  - `photocleaner://login-callback/`
  - `photocleaner://login-callback`

Thiếu bước này thì bấm link trong email sẽ không mở lại được app.

## 5. Chạy file SQL xoá tài khoản
SQL Editor → New query → dán toàn bộ nội dung `docs/supabase_setup.sql` → **Run**.
(Không chạy thì nút "Xoá tài khoản" trong app sẽ báo lỗi.)

## 6. Google Sign-In
1. https://console.cloud.google.com → chọn/tạo project → **APIs & Services → OAuth consent screen**: điền tên app, email hỗ trợ, lưu.
2. **Credentials → Create credentials → OAuth client ID** → loại **Web application**.
3. **Authorized redirect URIs** thêm:
   `https://<PROJECT-REF>.supabase.co/auth/v1/callback`
   (`<PROJECT-REF>` là phần trước `.supabase.co` trong Project URL.)
4. Tạo xong, copy **Client ID** và **Client secret**.
5. Supabase → Authentication → Providers → **Google** → Bật, dán Client ID + Secret → Save.

Đăng nhập Google chạy qua trình duyệt trong app, nên **không cần** tạo client iOS/Android riêng.

## 7. Apple Sign-In (làm sau, cần gói Apple Developer trả phí 99 USD/năm)
Cần: App ID có capability "Sign in with Apple", một **Services ID**, một **Key** `.p8`, rồi điền vào Supabase → Providers → **Apple**.
Tài khoản Apple miễn phí (Personal Team) **không** có capability này, nên bấm nút Apple lúc này sẽ báo "cách đăng nhập này chưa được bật".

## 8. Đưa khoá vào app
```bash
cd ~/development/photo_cleaner
cp env.example.json env.json        # rồi sửa env.json bằng URL + anon key thật
echo "env.json" >> .gitignore       # không đưa khoá lên git
python3 patch_platforms.py          # thêm INTERNET + deep link photocleaner://
flutter pub get
flutter run -d <ID_iPhone> --dart-define-from-file=env.json
```
- Phải chạy từ **terminal** như trên. Bấm ▶ trong Xcode **không** truyền khoá, app sẽ ở chế độ khách.
- Đổi khoá hoặc cấu hình native → dừng hẳn app và chạy lại (không hot reload).

## 9. Lưu ý vận hành
- Gói miễn phí dùng SMTP mặc định của Supabase, **giới hạn rất ít email mỗi giờ** (có thể chỉ vài thư). Khi test nhiều, bạn sẽ gặp lỗi "quá nhiều lần". Về lâu dài nên cấu hình SMTP riêng (Authentication → SMTP Settings).
- Email xác nhận/đặt lại có thể vào **thư rác**.
- Mở link email phải làm **trên cùng chiếc iPhone/Android đã cài app**.
- Phiên đăng nhập lưu trong Keychain / Android Keystore, không lưu mật khẩu.
- Ảnh và Két **không bao giờ** được gửi lên server.
