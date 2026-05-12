+++
title = 'Network Traffic Engineering: NFStream & CIC-IDS Pipeline'
date = '2026-05-12T17:35:00+07:00'
draft = false
tags = ['Network Engineering', 'Data Pipeline', 'NFStream', 'Machine Learning', 'Python']
+++

**Overview:**  
A critical component of AI-driven cybersecurity is processing raw network traffic into clean, structured data. This project implements a validated, end-to-end data pipeline to generate consistent, machine learning-ready datasets from raw network traffic (PCAP files and active network interfaces).

**What I did:**
- Built an automated feature extraction pipeline using **NFStream** to parse network flows, heavily inspired by the methodologies of the CIC-IDS-2017 dataset.
- Optimized the data engineering process to be lightweight, making it suitable for deployment on resource-constrained edge devices (like Raspberry Pi).
- Addressed data imbalance and feature normalization to ensure downstream Machine Learning models receive high-quality input.

**Key Achievements & Skills Gained:**  
- Network Traffic Analysis (NTA) and deep packet inspection concepts.
- Data Engineering for Cybersecurity (Python, Pandas, NFStream).
- Building automated pipelines for SecOps/MLOps integration.

> 🖼️ *[Placeholder: Add diagrams of the data pipeline flow or screenshots of the extracted datasets here. Save images to `static/images/portfolio/`]*

**Repository:** [NFStream-CIC-IDS-Pipeline](https://github.com/PoeenCy/NFStream-CIC-IDS-Pipeline)
