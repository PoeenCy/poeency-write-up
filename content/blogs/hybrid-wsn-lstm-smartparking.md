+++
title = 'Smart City IoT: Hybrid WSN-LSTM Smart Parking System'
date = '2026-05-12T17:15:00+07:00'
draft = false
tags = ['WSN', 'IoT', 'Machine Learning', 'Bi-LSTM', 'Genetic Algorithms']
+++

# Cách Mạng Hóa Bãi Đỗ Xe Thông Minh Bằng Hybrid WSN và AI (Bi-LSTM)

Quản lý bãi đỗ xe tại các đô thị đông đúc luôn là một bài toán đau đầu. Với sự phát triển của IoT, việc sử dụng Mạng Cảm Biến Không Dây (WSN) đã trở thành giải pháp tiêu chuẩn. Nhưng thực tế triển khai lại phơi bày vô số hạn chế chí mạng về năng lượng và độ ổn định mạng lưới. Dự án **Hybrid WSN-LSTM Smart Parking** mang đến một câu trả lời thuyết phục bằng cách kết hợp sức mạnh phần cứng tối ưu và trí tuệ nhân tạo.

## 1. Vấn Đề Của Mạng Cảm Biến Đỗ Xe Truyền Thống

Trong một bãi đỗ xe thông minh, hàng trăm cảm biến ở mỗi ô đỗ xe phải liên tục báo cáo trạng thái (trống/có xe). Nếu áp dụng các giao thức truyền thống, chúng ta đối mặt với hai vấn đề lớn:
- **Giao thức Direct (Trực tiếp):** Mọi cảm biến đều cố gắng phát tín hiệu thẳng về Gateway. Cảm biến ở xa sẽ cạn kiệt pin cực nhanh (hiệu ứng path-loss d⁴) và gây xung đột tín hiệu nghiêm trọng.
- **Giao thức LEACH:** Dù đã có gom cụm (Clustering), nhưng việc chọn Cluster Head (CH) ngẫu nhiên gây lãng phí overhead rất cao do liên tục phát sóng dò tìm. 

Kết quả là toàn bộ mạng cảm biến chỉ sống sót được vài vòng đời lặp lại (12-179 vòng), tỉ lệ rớt gói tin cao, khiến dữ liệu cung cấp bị đứt quãng.

## 2. Giải Pháp Lai Ghép: Thuật Toán Di Truyền & Bi-LSTM

Hệ thống Hybrid WSN-LSTM được thiết kế gồm 2 phần giải quyết cả gốc lẫn ngọn:

**Ở tầng Giao thức mạng:**
Dự án thay thế các giao thức cũ bằng một **Giao thức Đề xuất (dựa trên Genetic Algorithm - GA)**. Thay vì chọn CH ngẫu nhiên, hệ thống dùng thuật toán di truyền để tối ưu vị trí CH, giúp tiết kiệm năng lượng nhất. Hệ thống cũng áp dụng lịch trình **TDMA** (phân chia khe thời gian) để xóa bỏ hoàn toàn việc các cảm biến tranh chấp gửi dữ liệu.

**Ở tầng Dự đoán (AI):**
Gói tin đôi khi vẫn bị thất thoát. Để hệ thống vẫn báo cáo chính xác chỗ trống, một mạng Neural **Bi-LSTM (Bidirectional Long Short-Term Memory)** được đặt ở Server. Mạng Bi-LSTM có khả năng đọc dữ liệu chuỗi thời gian 2 chiều (quá khứ và tương lai) trên khung thời gian 5 giây để dự đoán chính xác trạng thái đỗ xe, kể cả khi tín hiệu từ cảm biến chập chờn.

## 3. Sơ Đồ Kiến Trúc Hệ Thống

Kiến trúc dưới đây thể hiện sự phối hợp nhịp nhàng từ các điểm đỗ (cảm biến WSN), truyền tin qua Gateway và đưa vào đám mây để AI dự đoán trước khi xuất lên Dashboard.

![Sơ đồ kiến trúc Smart Parking System](/poeency-write-up/images/portfolio/smart_parking_wsn.png)

## 4. Kết Quả Vượt Trội

Việc áp dụng giải pháp lai ghép này mang lại những con số thống kê ấn tượng được chứng minh qua mô phỏng giao thông (SUMO):
- **Vòng đời mạng lưới (Network Lifetime):** Tăng vọt lên **500 vòng**, gấp gần 3 lần so với LEACH và 40 lần so với Direct.
- **Năng lượng tiêu thụ:** Giảm tới **73%** năng lượng trung bình mỗi vòng lặp. Cảm biến đầu tiên (FND - First Node Death) sống thọ hơn tới vòng 20 thay vì chết ngay vòng 1.
- Tính ổn định cực cao khi luôn duy trì được các cụm trưởng tối ưu, giảm thiểu thiết lập dư thừa.

Mô hình Hybrid WSN-LSTM chứng minh rằng: Tương lai của Smart City không chỉ là lắp thêm nhiều cảm biến, mà là cách chúng ta khiến các cảm biến đó nói chuyện với nhau thông minh hơn, và dùng AI để bù đắp hoàn hảo cho các giới hạn vật lý.

**Repository:** [Hybrid WSN-LSTM Smart Parking](https://github.com/PoeenCy/Hybrid-WSN-LSTM-SmartParking)
