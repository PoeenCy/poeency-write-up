+++
title = 'Vulnerability Research: ESP32 BluFi Stack Overflow (NCC-BluFi-Ref-WXR)'
date = '2026-05-12T17:10:00+07:00'
draft = false
tags = ['IoT Security', 'Vulnerability Research', 'ESP32', 'Buffer Overflow']
+++

**Overview:**  
This project dives deep into embedded systems security by analyzing and exploiting a critical stack overflow vulnerability (NCC-BluFi-Ref-WXR) in Espressif's ESP32 BluFi protocol. The flaw allows an unauthenticated attacker within BLE range to trigger Denial of Service (DoS) or potentially Remote Code Execution (RCE).

**What I did:**
- Successfully reproduced the attack vector using Python (Bleak) against actual ESP32 hardware running vulnerable ESP-IDF firmware.
- Conducted root-cause analysis at the C-source level, specifically investigating the `strncpy` mechanism during `ESP_BLUFI_EVENT_RECV_STA_SSID` handling.
- Proposed and validated a robust security patch implementing a raw memory management wrapper (utilizing safe `memset`, `memcpy`, and explicit null-termination) to completely prevent buffer overflow/over-read while ensuring data integrity.

**Key Achievements & Skills Gained:**  
- Practical experience with IoT exploitation, memory corruption vulnerabilities, and firmware patching.
- Deepened understanding of BLE communication and ESP-IDF architecture.

> 🖼️ *[Placeholder: Add screenshots of the DoS payload execution, serial monitor panic logs, or code diffs here. Save images to `static/images/portfolio/`]*

**Repository:** [ESP32 BluFi Stack Overflow](https://github.com/PoeenCy/esp32-blufi-stack-overflow)
