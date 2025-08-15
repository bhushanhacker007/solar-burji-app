#!/bin/bash

# Solar Burji App - GitHub Repository Setup Script

echo "🚀 Setting up GitHub Repository for Solar Burji App"
echo "=================================================="

echo ""
echo "📋 Prerequisites:"
echo "1. GitHub account"
echo "2. Git configured with your credentials"
echo ""

# Check if git is configured
if ! git config --global user.name > /dev/null 2>&1; then
    echo "❌ Git user.name not configured"
    echo "Run: git config --global user.name 'Your Name'"
    exit 1
fi

if ! git config --global user.email > /dev/null 2>&1; then
    echo "❌ Git user.email not configured"
    echo "Run: git config --global user.email 'your.email@example.com'"
    exit 1
fi

echo "✅ Git is properly configured"
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " github_username

if [ -z "$github_username" ]; then
    echo "❌ GitHub username is required"
    exit 1
fi

echo ""
echo "📝 Repository Details:"
echo "Name: solar-burji-app"
echo "Description: Solar Burji Business Management App - Flutter + PHP"
echo "URL: https://github.com/$github_username/solar-burji-app"
echo ""

echo "🔗 Next Steps:"
echo "1. Go to: https://github.com/new"
echo "2. Repository name: solar-burji-app"
echo "3. Description: Solar Burji Business Management App - Flutter + PHP"
echo "4. Make it Public or Private"
echo "5. DO NOT initialize with README (we already have one)"
echo "6. Click 'Create repository'"
echo ""

read -p "Press Enter after creating the repository on GitHub..."

echo ""
echo "🔧 Setting up remote repository..."

# Add remote origin
git remote add origin https://github.com/$github_username/solar-burji-app.git

if [ $? -eq 0 ]; then
    echo "✅ Remote origin added successfully"
else
    echo "❌ Failed to add remote origin"
    echo "Repository might already exist or URL is incorrect"
    exit 1
fi

echo ""
echo "📤 Pushing code to GitHub..."

# Push to GitHub
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Success! Your code is now on GitHub!"
    echo ""
    echo "🔗 Repository URL: https://github.com/$github_username/solar-burji-app"
    echo ""
    echo "📱 What's included:"
    echo "✅ Complete Flutter frontend"
    echo "✅ PHP backend with REST API"
    echo "✅ Cross-platform support"
    echo "✅ Comprehensive documentation"
    echo "✅ Demo package with production builds"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Share the repository URL with clients"
    echo "2. Set up GitHub Pages for web demo"
    echo "3. Configure CI/CD if needed"
    echo "4. Add collaborators if required"
    echo ""
else
    echo "❌ Failed to push to GitHub"
    echo "Check your internet connection and GitHub credentials"
    exit 1
fi

echo "✨ Setup complete! Happy coding!"
