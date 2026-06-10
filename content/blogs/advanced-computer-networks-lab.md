+++
title = 'Enterprise Routing & Simulation: A Journey Exploring Advanced Computer Networks'
date = '2026-05-12T17:40:00+07:00'
draft = false
tags = ['Computer Networks', 'Routing', 'Network Simulation', 'Python', 'Zero Trust', 'IPv6']
categories = ['Network Engineering', 'Lab', 'Blog']
+++

**Overview:**  
Hello everyone, today I want to share a fascinating journey I experienced in my Advanced Computer Networks course. Instead of just learning dry theory on paper, this project served as a practical playground where I could manually build, configure, and break complex enterprise network systems to deeply understand how the networking world truly operates.

![Advanced Computer Networks Lab](/images/blogs/advanced-computer-networks-lab/advanced_computer_networks_lab.png)

### What Did I Implement?

This journey was divided into multiple stages (Labs), ranging from fundamental routing concepts to modern data center architectures:

1. **Kicking off with OSPF Multi-Area:**
   Everything started by designing a campus network separated into 3 distinct areas. Instead of using physical routers, I utilized **Mininet** and **FRRouting** for simulation. Experiencing ABR/ASBR configuration and tweaking path costs to create backup routes helped me truly grasp how data flows find the shortest (and safest) paths when a failure occurs.

2. **Building Security Perimeters (ACLs & Zero Trust):**
   In the next step, I deployed a 3-Tier network model (Core-Distribution-Access) integrated with a DMZ. The most interesting part was applying the **Zero Trust** mindset and **Micro-segmentation** via OpenFlow. Blocking internal malicious lateral movements gave off a very "white-hat hacker" vibe.

3. **Infrastructure Hardening (Network Hardening):**
   This is where I combined everything: OSPF Multi-Area, Extended ACLs, and DMZ into a real-world scenario where a company is infected by IoT malware. I designed a Defense in Depth system, isolating IoT devices into a Totally Stubby Area and encrypting routing updates with MD5.

4. **Deep Dive into Every Packet (Packet Analysis):**
   Using Wireshark and Tshark, I "dissected" L2/L3/L4 packets. Manually troubleshooting network drops due to misconfigured ACLs or failed OSPF Neighbor adjacencies provided truly unforgettable lessons.

5. **The Final Boss: IPv6 Spine-Leaf Data Center:**
   This is the part I am most proud of. I deployed a Spine-Leaf architecture (the standard model for modern Data Centers) entirely on pure IPv6, combining Tayga NAT64 to communicate with the IPv4 network. Not stopping at the infrastructure level, I also coded a custom **Web Dashboard** using Flask and Chart.js to monitor round-trip time (RTT) and test ECMP Load Balancing in real-time.

### The "Talking" Numbers & Key Takeaways

This project wasn't just about dry configuration lines. It brought measurable results:

- **Lightning-fast network convergence:** With the ECMP (Equal-Cost Multi-Path) design, I observed the network convergence time drop to a mere **0.x milliseconds** during a cable cut simulation—a speed almost imperceptible to the human eye.
- **Multi-layered security:** Successfully deployed at least **5 complex ACL policies**, securing the core area and the DMZ.
- **Automation & Monitoring:** The monitoring dashboard plotted thousands of data points in real-time, automatically exporting `.png` graphs and `.csv` datasets, making network performance evaluation more intuitive than ever.

Above all, this project helped me transition from merely "knowing" concepts (subnets, routing tables) to actually "understanding and doing" within an automated enterprise-simulated environment.

If you are interested in building complex network models and want to configure them yourself, you can check out the project's source code here:
**Repository:** [Advanced-Computer-Networks-Lab](https://github.com/PoeenCy/Advanced-Computer-Networks-Lab)
