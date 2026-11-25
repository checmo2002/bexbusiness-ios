# BexBusiness cho iPhone

App iOS của BexBusiness (Powered by Beso). Đây là vỏ app gốc bọc giao diện của máy chủ BexBusiness, nên mỗi lần máy chủ cập nhật thì app trên iPhone có tính năng mới ngay, không cần cài lại.

Có sẵn:
- Chọn máy chủ: nhập địa chỉ, hoặc quét mã QR trong cửa sổ "Mở ra internet" của app Windows.
- Micro và camera cho phòng họp, quét QR để đăng nhập trên máy tính và chấm công.
- Tải tệp: mở bảng chia sẻ để lưu vào Tệp hoặc gửi qua Zalo.
- Số tin chưa đọc hiện trên biểu tượng app.
- Giao diện sáng/tối, có màn hình báo lỗi khi mất kết nối và nút đổi máy chủ.

## Cài lên iPhone bằng Apple ID miễn phí

Cần có: máy Mac đã cài **Xcode** (tải miễn phí trên App Store), một **Apple ID** và **cáp nối iPhone với Mac**.

1. Trên Mac, mở trang repo này trên GitHub, bấm **Code**, chọn **Download ZIP**, rồi giải nén.
2. Nhấp đúp file **BexBusiness.xcodeproj** để mở bằng Xcode.
3. Đăng nhập Apple ID: vào **Xcode**, chọn **Settings…**, mở tab **Accounts**, bấm **+**, chọn **Apple ID** rồi đăng nhập.
4. Ở cột trái, bấm vào **BexBusiness** (biểu tượng màu xanh trên cùng).
   - Chọn target **BexBusiness**, mở tab **Signing & Capabilities**.
   - Ở mục **Team**, chọn tên bạn (Personal Team).
   - Nếu Xcode báo bundle ID đã có người dùng, đổi **Bundle Identifier** thành tên khác, ví dụ `vn.beso.bexbusiness.ten-ban`.
5. Cắm iPhone vào Mac. Trên iPhone bấm **Tin cậy**, rồi bật **Chế độ nhà phát triển**: vào **Cài đặt**, chọn **Quyền riêng tư & Bảo mật**, rồi **Chế độ nhà phát triển**. iPhone sẽ khởi động lại.
6. Trên thanh trên cùng của Xcode, chọn iPhone của bạn rồi bấm nút **▶ (Run)**.
7. Lần đầu mở app, iPhone báo "Nhà phát triển không được tin cậy". Vào **Cài đặt**, chọn **Cài đặt chung**, rồi **Quản lý VPN & Thiết bị**. Bấm vào Apple ID của bạn, chọn **Tin cậy**.

Lưu ý: app ký bằng Apple ID miễn phí **hết hạn sau 7 ngày**. Khi hết hạn, cắm iPhone vào Mac và bấm ▶ lại là xong, dữ liệu vẫn giữ nguyên. Muốn hết giới hạn này, phát hành qua TestFlight hoặc App Store, hoặc có thông báo đẩy khi app đóng, thì cần tài khoản Apple Developer (99 USD/năm).

## Kết nối máy chủ

- **Cùng mạng Wi-Fi với máy chủ:** nhập `http://<IP máy chủ>:3000`. App Windows hiện sẵn địa chỉ này ở màn hình cài đặt.
- **Ở xa:** trên máy chủ Windows, chuột phải biểu tượng BexBusiness ở khay, chọn **Mở ra internet…**, rồi trên iPhone bấm **Quét mã QR trên máy tính**.
- Muốn đổi máy chủ sau này: vào **Cài đặt người dùng**, bấm nút **Máy chủ** ở góc trên.

## Build thử tự động

Mỗi lần đẩy code lên, GitHub Actions build thử trên máy Mac ảo, ở tab **Actions** của repo, để bắt lỗi trước khi mở bằng Xcode.
