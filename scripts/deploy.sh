#!/bin/bash

# Script deploy tự động

echo "=== Hugo Portfolio Deployment Script ==="
echo ""

# Kiểm tra Hugo
if ! command -v hugo &> /dev/null; then
    echo "❌ Hugo chưa được cài đặt!"
    exit 1
fi

echo "✅ Hugo version: $(hugo version)"
echo ""

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf public/
rm -rf resources/

# Build site
echo "🔨 Building site..."
hugo --minify

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "📊 Build statistics:"
echo "   Total pages: $(find public -name "*.html" | wc -l)"
echo "   Total size: $(du -sh public | cut -f1)"
echo ""

# Commit và push (optional)
read -p "Commit và push changes? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git add .
    read -p "Commit message: " commit_msg
    git commit -m "$commit_msg"
    git push
    echo "✅ Pushed to repository"
fi

echo ""
echo "🚀 Deployment options:"
echo "   1. GitHub Pages: Push to gh-pages branch"
echo "   2. Netlify: netlify deploy --prod"
echo "   3. Vercel: vercel --prod"
echo "   4. Manual: Upload 'public/' folder to your server"
echo ""

read -p "Select deployment method (1-4, or skip): " deploy_choice

case $deploy_choice in
    1)
        echo "Deploying to GitHub Pages..."
        git subtree push --prefix public origin gh-pages
        ;;
    2)
        if command -v netlify &> /dev/null; then
            netlify deploy --prod
        else
            echo "❌ Netlify CLI not installed. Run: npm install -g netlify-cli"
        fi
        ;;
    3)
        if command -v vercel &> /dev/null; then
            vercel --prod
        else
            echo "❌ Vercel CLI not installed. Run: npm install -g vercel"
        fi
        ;;
    4)
        echo "📁 Build files are in 'public/' directory"
        echo "   Upload them to your web server"
        ;;
    *)
        echo "Skipping deployment"
        ;;
esac

echo ""
echo "✅ Done!"
