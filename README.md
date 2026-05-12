# Nha Tran Thanh - Portfolio & Write-ups

Personal portfolio and blog focusing on Cybersecurity, built with Hugo and the PaperMod theme.

## 🚀 Overview

This website includes:
- **Portfolio**: Projects and achievements in the cybersecurity field.
- **Write-ups**: Articles on CTF challenges, network analysis, and AI/ML in security.
- **Research**: Study notes on IoT Security and related topics.

## 🛠️ Technology Stack

- **Hugo**: Static site generator
- **PaperMod**: Hugo theme
- **Git**: Version control

## 📦 Installation

### Requirements
- Hugo Extended (v0.161.1 or newer)
- Git

### Clone the repository

```bash
git clone <repository-url>
cd poeency-portfolio
git submodule update --init --recursive
```

## 🏃 Running Locally

```bash
hugo server -D
```

The website will be available at: `http://localhost:1313`

## 📝 Creating New Content

### Create a new blog post

```bash
hugo new posts/post-title.md
```

### Create a new portfolio project

```bash
hugo new portfolio/project-name.md
```

## 🔨 Build for Production

```bash
hugo --minify
```

The compiled files will be generated in the `public/` directory.

## 📂 Directory Structure

```
poeency-portfolio/
├── content/
│   ├── about.md          # About page
│   ├── portfolio/        # Portfolio projects
│   └── posts/            # Blog posts
├── themes/
│   └── PaperMod/         # Theme
├── static/               # Static files (images, css, js)
├── hugo.toml             # Configuration file
└── README.md
```

## 🎨 Customization

Edit the `hugo.toml` file to change:
- Personal information
- Menu navigation
- Social links
- Theme settings

## 📧 Contact

- **Email**: nhatran.network@gmail.com
- **LinkedIn**: [Nha Tran Thanh](https://www.linkedin.com/in/nha-tran-thanh-95a67835b/)
- **GitHub**: [PoeenCy](https://github.com/PoeenCy)

## 📄 License

© 2026 Nha Tran Thanh. All rights reserved.
