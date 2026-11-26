# BexBusiness cho iPhone, iPad và Mac

App BexBusiness cho thiết bị Apple (Powered by Beso). Một project dùng chung cho iPhone, iPad và Mac (Mac Catalyst). Đây là vỏ app gốc bọc giao diện của máy chủ BexBusiness, nên mỗi lần máy chủ cập nhật thì app có tính năng mới ngay, không cần cài lại.

Có sẵn:
- Chọn máy chủ: nhập địa chỉ, hoặc quét mã QR trong cửa sổ "Mở ra internet" của app Windows.
- Micro và camera cho phòng họp, quét QR để đăng nhập trên máy tính và chấm công.
- Tải tệp: mở bảng chia sẻ để lưu vào Tệp hoặc gửi qua Zalo.
- App đứng yên như app gốc (không phóng to cả trang). Bấm **Xem** ở tệp PDF, ảnh, video, Word/Excel thì mở trình xem tài liệu: chụm hai ngón để phóng to, có nút chia sẻ.
- Số tin chưa đọc hiện trên biểu tượng app.
- Giao diện sáng/tối, có màn hình báo lỗi khi mất kết nối và nút đổi máy chủ.
- Thông báo tin nhắn mới của hệ thống (bật trong Cài đặt người dùng của BexBusiness). Trên Mac nhận được cả khi cửa sổ bị che; trên iPhone/iPad chỉ khi app còn mở.

**iPad:** xoay ngang/dọc, chia đôi màn hình (Split View), Stage Manager, mở nhiều cửa sổ, kéo thả tệp vào khung chat, bàn phím rời có phím tắt (giữ ⌘ để xem).

**Mac:** thanh tiêu đề gọn cùng màu app, cửa sổ kéo to nhỏ tuỳ ý, mở nhiều cửa sổ (⌘N), kéo thả tệp từ Finder vào khung chat, tải tệp mở hộp thoại Lưu, số tin chưa đọc trên Dock. Menu và phím tắt:
- ⌘R tải lại trang · ⇧⌘K đổi máy chủ

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

## Chạy trên iPad

Giống iPhone: cắm iPad vào Mac, chọn iPad ở thanh trên cùng của Xcode rồi bấm ▶.

## Chạy trên Mac

1. Mở **BexBusiness.xcodeproj** bằng Xcode, chọn Team như ở bước 4 phần iPhone.
2. Ở thanh trên cùng, bấm chỗ chọn thiết bị, chọn **My Mac (Mac Catalyst)**.
3. Bấm **▶**. Lần đầu macOS có thể hỏi mật khẩu máy để cho phép ký app, bấm **Luôn cho phép**.
4. Muốn có app trong thư mục Applications: trên menu Xcode chọn **Product → Show Build Folder in Finder**, vào `Products/Debug-maccatalyst`, kéo **BexBusiness.app** sang **Applications**.

Bản Mac ký bằng Apple ID miễn phí chỉ chạy trên chính máy Mac đó.

## Kết nối máy chủ

- Mở app là vào thẳng máy chủ BexBusiness chung **https://bexbusiness.xyz**: đăng ký hoặc đăng nhập rồi dùng luôn, không phải nhập gì.
- Tài khoản cá nhân chưa thuộc công ty nào vẫn dùng app bình thường. Muốn vào công ty: dán link mời, hoặc trong mục **Thêm** bấm **Quét mã QR mời vào công ty**.
- Link `bexbusiness://join/<mã>` mở thẳng màn tham gia công ty trong app.
- Mất mạng thì app hiện "Chưa kết nối được BexBusiness" và tự thử lại sau vài giây.
- **Nâng cao: máy chủ riêng của công ty.** Ở màn mất kết nối bấm dòng "Nâng cao: máy chủ riêng của công ty", hoặc vào **Cài đặt người dùng → Máy chủ** (Mac: **File → Đổi máy chủ…**). Nhập địa chỉ hoặc quét mã QR. Nút **Dùng máy chủ BexBusiness** đưa app về máy chủ chung.

## Build thử tự động

Mỗi lần đẩy code lên, GitHub Actions build thử cho iPhone, iPad và Mac trên máy Mac ảo (tab **Actions** của repo) để bắt lỗi trước khi mở bằng Xcode, rồi chụp màn hình máy ảo iPhone, iPad và bản Mac vào thư mục `screenshots/`.
