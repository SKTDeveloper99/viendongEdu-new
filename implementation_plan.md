# Kế hoạch nâng cấp hỗ trợ Nhiều Máy Chấm Công (Multi-Device Support)

Việc hỗ trợ nhiều máy chấm công cùng lúc là một thay đổi lớn về mặt kiến trúc, vì hiện tại toàn bộ code (các Background Service, API Controller) đều giả định chỉ có **duy nhất 1 máy** (thông qua singleton `ZKService`).

Để hỗ trợ nhiều máy (`10.10.150.118` và `10.10.150.183`), chúng ta cần chuyển đổi kiến trúc từ 1-1 (1 App - 1 Device) sang 1-N (1 App - Nhiều Device) nhưng vẫn cố gắng giữ nguyên giao diện API để không phải đập đi xây lại toàn bộ các logic sẵn có.

> [!IMPORTANT]
> Đây là thay đổi cốt lõi. Hãy review kỹ và bấm **Proceed** nếu bạn đồng ý triển khai.

## Open Questions

1. **Đồng bộ hóa dữ liệu xuống máy:** Khi cập nhật dữ liệu (ví dụ: thêm mặt, sửa vân tay, xoá user) trên ứng dụng, bạn có muốn đẩy cập nhật này xuống **TẤT CẢ** các máy chấm công đang kết nối không? (Hiện tại kế hoạch của mình là có - đẩy xuống tất cả để máy nào cũng chấm công được).
2. **Log chấm công:** Lấy log từ tất cả các máy gộp lại đúng không?

## Proposed Changes

### 1. `appsettings.json`

Sửa đổi cấu hình từ 1 Object thành 1 Mảng (Array) để chứa danh sách nhiều máy.
```json
"ZKDevices": [
  { "IP": "10.10.150.118", "Port": 4370, "CommKey": 0, "MachineNumber": 1 },
  { "IP": "10.10.150.183", "Port": 4370, "CommKey": 0, "MachineNumber": 1 }
]
```

### 2. Core Service Refactor (Tách `ZKService` thành `ZKConnection` và `ZKDeviceManager`)

- **`[NEW] ZKFaceAPI/Models/ZKDeviceConfig.cs`**:
  Tạo object để map với file config.

- **`[NEW] ZKFaceAPI/Services/ZKConnection.cs`**:
  Đổi tên lõi của `ZKService` hiện tại thành `ZKConnection`. Class này sẽ bọc (wrap) 1 kết nối duy nhất (1 instance của `CZKEMClass`).

- **`[MODIFY] ZKFaceAPI/Services/ZKService.cs`**:
  Giữ nguyên tên `ZKService` để không làm lỗi các Controller đang dùng nó. Nhưng thay vì bọc 1 connection, nó sẽ đóng vai trò là **Device Manager** (Trình quản lý).
  - Nó chứa danh sách `List<ZKConnection>`.
  - Hàm `ConnectAll(configs)` sẽ kết nối toàn bộ máy trong list.
  - Hàm `GetAllUsers()` sẽ gom (merge) user từ tất cả các máy.
  - Hàm `GetAttendanceLogs()` sẽ gom toàn bộ log từ các máy.
  - Các hàm update (như `SetUser...`) sẽ chạy vòng lặp cập nhật xuống tất cả các máy.
  - Kích hoạt sự kiện `OnRealtimeAttendance` mỗi khi có máy nào đó gửi log realtime.

### 3. Background Services Refactor

- **`[MODIFY] ZKFaceAPI/Services/AttendancePollingService.cs`**:
  Cập nhật logic lấy config `ZKDevices` (Array) thay vì `ZKDevice`. Gọi hàm `_zkService.ConnectAll()` thay vì `ConnectTCP()`.
  
- **`[MODIFY] ZKFaceAPI/Services/FaceSyncBackgroundService.cs`**:
  Sẽ không cần sửa nhiều vì hàm của `ZKService` đã được bọc lại để tự động gom/đẩy trên tất cả thiết bị.

### 4. Controller Refactor

- Các Controllers (`UsersController`, `StudentsController`) cơ bản vẫn hoạt động bình thường, vì chúng ta đã thiết kế `ZKService` theo dạng Wrapper (Facade) ẩn đi sự phức tạp của nhiều máy. Chỉ cần dọn dẹp các lệnh connect/disconnect thủ công.

## Verification Plan

### Manual Verification
1. Sau khi áp dụng code, bạn sửa IP và thêm IP mới vào `appsettings.json`.
2. Khởi động lại ứng dụng.
3. Test chấm công bằng vân tay/khuôn mặt trên MÁY CŨ -> App nhận được realtime (nếu bật) hoặc polling thành công.
4. Test chấm công trên MÁY MỚI -> App nhận được log tương tự.
5. Cập nhật tên sinh viên trên giao diện -> Cả 2 máy đều nhận tên mới.
