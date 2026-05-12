+++
title = 'Phân tích lưu lượng mạng với NFStream'
date = '2026-05-12T16:25:12+07:00'
draft = false
tags = ['network-analysis', 'nfstream', 'python', 'research']
categories = ['Network Security', 'Tutorial']
+++

## Giới thiệu

**NFStream** là một framework mạnh mẽ cho việc phân tích lưu lượng mạng, được viết bằng Python. Trong bài viết này, tôi sẽ hướng dẫn cách sử dụng NFStream để phân tích traffic và phát hiện các hành vi bất thường.

## NFStream là gì?

NFStream là một thư viện Python cho phép:
- Capture và phân tích network traffic real-time
- Trích xuất features từ network flows
- Hỗ trợ deep packet inspection
- Tích hợp dễ dàng với ML models

### Ưu điểm của NFStream

✅ **Hiệu suất cao**: Xử lý hàng triệu packets/giây  
✅ **Dễ sử dụng**: API đơn giản, dễ học  
✅ **Linh hoạt**: Hỗ trợ nhiều protocols  
✅ **ML-ready**: Dễ dàng tích hợp với scikit-learn, TensorFlow

## Cài đặt

```bash
pip install nfstream
```

## Ví dụ cơ bản

### 1. Phân tích file PCAP

```python
from nfstream import NFStreamer

# Đọc file pcap
streamer = NFStreamer(source="traffic.pcap")

# Duyệt qua các flows
for flow in streamer:
    print(f"Flow ID: {flow.id}")
    print(f"Source: {flow.src_ip}:{flow.src_port}")
    print(f"Destination: {flow.dst_ip}:{flow.dst_port}")
    print(f"Protocol: {flow.protocol}")
    print(f"Packets: {flow.bidirectional_packets}")
    print(f"Bytes: {flow.bidirectional_bytes}")
    print("-" * 50)
```

### 2. Capture traffic real-time

```python
from nfstream import NFStreamer

# Capture từ interface
streamer = NFStreamer(source="eth0", 
                     decode_tunnels=True,
                     bpf_filter="port 80 or port 443")

for flow in streamer:
    if flow.bidirectional_packets > 10:
        print(f"Suspicious flow detected: {flow.src_ip} -> {flow.dst_ip}")
```

## Trích xuất Features cho Machine Learning

```python
from nfstream import NFStreamer
import pandas as pd

# Đọc pcap và chuyển thành DataFrame
streamer = NFStreamer(source="traffic.pcap")
df = streamer.to_pandas()

# Chọn features quan trọng
features = [
    'bidirectional_packets',
    'bidirectional_bytes',
    'bidirectional_duration_ms',
    'src2dst_packets',
    'dst2src_packets',
    'bidirectional_mean_ps',
    'bidirectional_stddev_ps'
]

X = df[features]
print(X.head())
```

## Phát hiện Anomaly đơn giản

```python
from nfstream import NFStreamer
from sklearn.ensemble import IsolationForest
import pandas as pd

# Thu thập data
streamer = NFStreamer(source="normal_traffic.pcap")
df = streamer.to_pandas()

# Chuẩn bị features
features = ['bidirectional_packets', 'bidirectional_bytes', 
            'bidirectional_duration_ms']
X = df[features].fillna(0)

# Train model
model = IsolationForest(contamination=0.1, random_state=42)
model.fit(X)

# Detect anomalies
predictions = model.predict(X)
df['anomaly'] = predictions

# Hiển thị các flows bất thường
anomalies = df[df['anomaly'] == -1]
print(f"Detected {len(anomalies)} anomalous flows")
print(anomalies[['src_ip', 'dst_ip', 'bidirectional_packets', 'bidirectional_bytes']])
```

## Use Cases thực tế

### 1. Phát hiện DDoS
```python
# Đếm số connections đến một IP
dst_counts = df['dst_ip'].value_counts()
potential_ddos = dst_counts[dst_counts > 1000]
print("Potential DDoS targets:", potential_ddos)
```

### 2. Phát hiện Port Scanning
```python
# Tìm source IP kết nối đến nhiều ports khác nhau
port_scan = df.groupby('src_ip')['dst_port'].nunique()
scanners = port_scan[port_scan > 50]
print("Potential port scanners:", scanners)
```

### 3. Phân tích Protocol Distribution
```python
protocol_dist = df['protocol'].value_counts()
print("Protocol distribution:")
print(protocol_dist)
```

## Kết hợp với Deep Learning

```python
from nfstream import NFStreamer
import numpy as np
from tensorflow import keras

# Load pre-trained model
model = keras.models.load_model('intrusion_detection_model.h5')

# Analyze traffic
streamer = NFStreamer(source="eth0")

for flow in streamer:
    # Extract features
    features = np.array([[
        flow.bidirectional_packets,
        flow.bidirectional_bytes,
        flow.bidirectional_duration_ms,
        # ... more features
    ]])
    
    # Predict
    prediction = model.predict(features)
    
    if prediction > 0.8:  # Threshold
        print(f"⚠️ Intrusion detected: {flow.src_ip} -> {flow.dst_ip}")
```

## Best Practices

1. **Filter traffic**: Sử dụng BPF filters để giảm noise
2. **Feature selection**: Chọn features phù hợp với mục đích phân tích
3. **Normalization**: Chuẩn hóa data trước khi train ML models
4. **Real-time processing**: Xử lý theo batch để tối ưu performance
5. **Logging**: Lưu lại các flows đáng ngờ để phân tích sau

## Kết luận

NFStream là công cụ mạnh mẽ cho network analysis và security monitoring. Kết hợp với machine learning, chúng ta có thể xây dựng hệ thống phát hiện xâm nhập hiệu quả.

Trong các bài viết tiếp theo, tôi sẽ đi sâu hơn về:
- Xây dựng IDS với LSTM
- Feature engineering cho network traffic
- Real-time threat detection

## Tài liệu tham khảo

- [NFStream Documentation](https://www.nfstream.org/)
- [NFStream GitHub](https://github.com/nfstream/nfstream)

---

**Tags:** #network-analysis #nfstream #python #machine-learning #cybersecurity

Nếu bạn có câu hỏi hoặc muốn thảo luận thêm, hãy liên hệ với tôi qua email: nhatran.network@gmail.com
