# Suno Automation - Complete Instructions

## 📋 Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start Guide](#quick-start-guide)
- [Detailed Setup Process](#detailed-setup-process)
- [Authentication Setup](#authentication-setup)
- [CSV Format and Song Preparation](#csv-format-and-song-preparation)
- [Running the Automation](#running-the-automation)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Understanding the Code](#understanding-the-code)
- [Development Best Practices](#development-best-practices)
- [Security Considerations](#security-considerations)
- [FAQ and Common Issues](#faq-and-common-issues)

## 🎯 Overview

This automation system helps you efficiently use your Suno monthly credits by automatically submitting songs from CSV files. The system:

- **Reads song data** from CSV files (title, style, lyrics)
- **Automates browser interactions** with Suno's interface
- **Handles authentication** using your existing session
- **Manages timing** with 4-minute intervals between submissions
- **Tracks results** and provides comprehensive logging
- **Runs in Docker** for consistent, isolated execution

### 🏗️ Technical Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CSV Files     │───▶│  Node.js Script  │───▶│  Suno Website   │
│  (Song Data)    │    │   + Playwright    │    │   (Submission)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Docker Container │
                       │   (Isolated Env)  │
                       └──────────────────┘
```

## 🛠️ Prerequisites

### System Requirements
- **Operating System**: WSL Ubuntu 24.04 (recommended) or any Linux distribution
- **RAM**: Minimum 4GB (browser automation is memory-intensive)
- **Storage**: At least 2GB free space
- **Network**: Stable internet connection for Suno access

### Required Software
The build script will automatically install these, but you can install manually:

1. **Docker & Docker Compose**
   ```bash
   # The script handles this, but manual installation:
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Node.js 18+ and npm**
   ```bash
   # The script handles this, but manual installation:
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. **Git** (usually pre-installed on WSL)
   ```bash
   sudo apt-get update && sudo apt-get install git
   ```

## 🚀 Quick Start Guide

### Step 1: Initial Setup
```bash
# Clone or create project directory
mkdir suno-automation && cd suno-automation

# Run the setup script
chmod +x setup.sh
./setup.sh
```

### Step 2: Prepare Your Data
```bash
# Create your songs CSV file
cp input/templates/songs-template.csv input/songs/my-songs.csv
# Edit my-songs.csv with your song data
```

### Step 3: Capture Authentication
```bash
# Follow authentication setup guide below
# Save session.json in project root
```

### Step 4: Build and Deploy
```bash
# Make build script executable and run
chmod +x scripts/build-and-deploy.sh
./scripts/build-and-deploy.sh
```

### Step 5: Monitor
```bash
# Watch logs
./scripts/build-and-deploy.sh logs

# Check status
./scripts/build-and-deploy.sh status
```

## 📁 Detailed Setup Process

### Understanding the Project Structure

```
suno-automation/
├── src/                          # Source code directory
│   ├── index.js                  # Main automation script
│   └── test.js                   # Testing utilities
├── input/                        # Input data directory
│   ├── songs/                    # Your CSV files go here
│   └── templates/                # Example CSV templates
├── output/                       # Results and generated files
│   ├── completed/                # Successful submissions
│   ├── failed/                   # Failed attempts
│   └── audio/                    # Downloaded audio (future feature)
├── logs/                         # Application logs
│   ├── automation/               # Automation process logs
│   └── docker/                   # Build and deployment logs
├── scripts/                      # Build and deployment scripts
├── docs/                         # Documentation
├── .github/workflows/            # CI/CD configurations (future)
├── package.json                  # Node.js dependencies
├── Dockerfile                    # Container configuration
├── docker-compose.yml            # Multi-container setup
├── .env.example                  # Environment variables template
└── README.md                     # Project overview
```

### Why This Structure Matters

**Separation of Concerns**: Each directory has a specific purpose
- `src/` contains the actual program code
- `input/` and `output/` separate data from code
- `logs/` keeps debugging information organized
- `scripts/` contains automation for building/deploying

**Docker Best Practices**: The structure supports containerization
- Clear separation between application and data
- Volume mounting for persistent data
- Environment-based configuration

## 🔐 Authentication Setup

### Understanding Suno Authentication

Suno uses a modern authentication system called **Clerk** that creates session tokens. Instead of storing passwords, we capture the authenticated session cookies.

### Method 1: Manual Session Capture (Recommended)

1. **Open Chrome/Edge Developer Tools**
   ```
   Press F12 or right-click → Inspect
   ```

2. **Navigate to Application Tab**
   ```
   Dev Tools → Application → Storage → Cookies → suno.com
   ```

3. **Copy All Cookies**
   ```bash
   # Create session.json in project root with this structure:
   {
     "cookies": [
       {
         "name": "__client",
         "value": "eyJhbGciOiJSUzI1NiIs...",
         "domain": "suno.com",
         "path": "/",
         "secure": true,
         "httpOnly": false
       },
       {
         "name": "__client_uat",
         "value": "1752005175",
         "domain": "suno.com", 
         "path": "/",
         "secure": true,
         "httpOnly": false
       }
       // ... include ALL cookies from suno.com
     ]
   }
   ```

### Method 2: Automated Session Capture Script

```javascript
// src/capture-session.js - Run this in browser console
// Copy and paste this into Chrome DevTools Console on suno.com/create

const cookies = await new Promise((resolve) => {
  chrome.cookies.getAll({domain: 'suno.com'}, resolve);
});

const sessionData = {
  cookies: cookies.map(cookie => ({
    name: cookie.name,
    value: cookie.value,
    domain: cookie.domain,
    path: cookie.path,
    secure: cookie.secure,
    httpOnly: cookie.httpOnly
  }))
};

console.log('Copy this to session.json:');
console.log(JSON.stringify(sessionData, null, 2));
```

### Session Security Notes

⚠️ **IMPORTANT**: Session files contain authentication tokens
- Never commit `session.json` to Git (it's in .gitignore)
- Regenerate sessions if compromised
- Sessions expire - you'll need to recapture periodically

## 📊 CSV Format and Song Preparation

### Understanding CSV Format

**CSV (Comma-Separated Values)** is a simple text format for storing tabular data. Each line represents a row, and commas separate columns.

### Required CSV Structure

```csv
title,style,lyrics
"Song Title Here","Style Description","Complete lyrics with structure"
```

### Column Definitions

1. **title** (max 100 characters)
   - The name of your song
   - Will appear as the song title in Suno
   - Example: `"Midnight Blues"`

2. **style** (max 1000 characters)
   - Musical style and production instructions
   - Can include tempo, instruments, mood, genre
   - Example: `"slow blues guitar, melancholy vocals, minor key"`

3. **lyrics** (max 5000 characters)
   - Complete song lyrics with structure markers
   - Include verse/chorus labels in brackets
   - Example: `"[Verse 1]\nWalking down the street...\n[Chorus]\nLife goes on..."`

### Advanced CSV Example

```csv
title,style,lyrics
"Digital Dreams","synthwave electronic 80s retro neon cyberpunk","[Intro synth arpeggios]
Neon lights flicker in the rain
[Verse 1]
Electric pulse through digital veins
Virtual reality, nothing's the same
[Chorus]
We're living in digital dreams
Nothing is quite what it seems
[Verse 2]
Code flows like rivers of light
In this cybernetic night"

"Country Road Home","acoustic country folk guitar harmonica","[Intro harmonica and guitar]
[Verse 1]
Dusty road beneath my feet
Heading home where two hearts meet
[Chorus] 
Take me home on that country road
Where the wildflowers grow
[Bridge]
Years have passed but I still know
The way back home on country roads"
```

### CSV Best Practices

**Quoting**: Always wrap text in quotes to handle commas and line breaks
```csv
"Good Title","rock, energetic","[Verse]\nThis works correctly"
Bad Title,rock energetic,This might break due to commas
```

**Line Breaks**: Use `\n` for line breaks within lyrics
```csv
"Title","style","[Verse 1]\nFirst line\nSecond line\n[Chorus]\nChorus lyrics"
```

**Special Characters**: Avoid these in CSV data:
- Unmatched brackets `[` or `(`
- Excessive punctuation that might confuse Suno
- Very long words or text blocks

### Creating Your CSV

**Method 1: Text Editor** (VSCode recommended)
```bash
code input/songs/my-songs.csv
```

**Method 2: Spreadsheet Application**
- Use Excel, Google Sheets, or LibreOffice Calc
- Export as CSV when finished
- Ensure UTF-8 encoding

**Method 3: Programming**
```javascript
// Example Node.js script to generate CSV
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const csvWriter = createCsvWriter({
    path: 'input/songs/generated-songs.csv',
    header: [
        {id: 'title', title: 'title'},
        {id: 'style', title: 'style'},
        {id: 'lyrics', title: 'lyrics'}
    ]
});

const songs = [
    {
        title: 'Generated Song',
        style: 'electronic dance',
        lyrics: '[Verse 1]\nGenerated content\n[Chorus]\nDance beat'
    }
];

csvWriter.writeRecords(songs);
```

## 🏃 Running the Automation

### Understanding the Build Process

The build script performs several important steps:

1. **Dependency Check**: Ensures Docker, Node.js, and other tools are installed
2. **Environment Setup**: Creates configuration files and directories
3. **Image Building**: Creates a Docker container with all dependencies
4. **Deployment**: Starts the automation in the container

### Build Script Options

```bash
# Full process (recommended for first run)
./scripts/build-and-deploy.sh full

# Individual steps
./scripts/build-and-deploy.sh build     # Just build Docker image
./scripts/build-and-deploy.sh deploy    # Deploy existing image
./scripts/build-and-deploy.sh run       # Run with docker run instead of compose

# Monitoring
./scripts/build-and-deploy.sh logs      # Watch live logs
./scripts/build-and-deploy.sh status    # Check container status

# Cleanup
./scripts/build-and-deploy.sh cleanup   # Stop and remove containers
```

### What Happens During Execution

1. **Initialization**
   - Browser (Chromium) starts in the container
   - Session cookies are loaded for authentication
   - Suno create page is accessed

2. **Song Processing Loop**
   ```
   For each song in CSV:
   ├── Load song data (title, style, lyrics)
   ├── Fill Suno form fields
   ├── Submit via API call
   ├── Wait 4 minutes
   └── Continue to next song
   ```

3. **Result Tracking**
   - Success/failure status for each song
   - Suno submission IDs for successful songs
   - Error messages for failed submissions
   - CSV file with complete results

### Configuration Options

Edit `.env` file to customize behavior:

```bash
# Browser settings
HEADLESS=true              # Set to false to see browser GUI
TIMEOUT=30000             # 30 seconds for page loads
VIEWPORT_WIDTH=1920       # Browser window size
VIEWPORT_HEIGHT=1080

# Timing (in milliseconds)
DELAY_BETWEEN_SONGS=240000    # 4 minutes between submissions
FORM_FILL_DELAY=1000         # 1 second between form fields
SUBMISSION_TIMEOUT=10000      # 10 seconds for API calls

# Files
INPUT_CSV=input/songs/my-songs.csv    # Your CSV file path
OUTPUT_DIR=output/completed           # Where results are saved

# Retry behavior
RETRY_ATTEMPTS=3          # How many times to retry failed songs
```

## 📊 Monitoring and Troubleshooting

### Log Files and Their Purpose

**Application Logs** (`logs/automation/`)
- `combined.log`: All automation activity
- `error.log`: Only errors and failures
- Includes timestamps and detailed error messages

**Docker Logs** (`logs/docker/`)
- `build-deploy.log`: Build process and deployment activity
- Container startup and system-level issues

### Reading Log Files

```bash
# Watch live automation logs
tail -f logs/automation/combined.log

# View recent errors
tail -n 50 logs/automation/error.log

# Check build issues
tail -f logs/docker/build-deploy.log
```

### Common Issues and Solutions

**Issue**: "Session file not found"
```
Solution: Create session.json with authentication cookies
See: Authentication Setup section above
```

**Issue**: "CSV file not found"
```
Solution: Ensure your CSV file exists in input/songs/ directory
Check: ls -la input/songs/
```

**Issue**: "Docker permission denied"
```
Solution: Add user to docker group and restart session
Commands: 
  sudo usermod -aG docker $USER
  newgrp docker  # or logout/login
```

**Issue**: "Browser automation fails"
```
Solution: Check if headless mode is causing issues
Fix: Set HEADLESS=false in .env to see browser GUI
```

**Issue**: "API authentication failed" 
```
Solution: Session cookies may have expired
Fix: Recapture session.json following authentication guide
```

### Debugging Strategies

**Enable Visual Mode**
```bash
# Edit .env file
HEADLESS=false

# Rebuild and run
./scripts/build-and-deploy.sh full
```

**Check Container Status**
```bash
# View container logs
docker logs suno-automation

# Access container shell for debugging
docker exec -it suno-automation /bin/bash
```

**Verify Input Data**
```bash
# Check CSV format
head -5 input/songs/your-file.csv

# Count songs
wc -l input/songs/your-file.csv
```

### Performance Monitoring

**Resource Usage**
```bash
# Check Docker resource usage
docker stats suno-automation

# Check system resources
htop  # or top
```

**Progress Tracking**
```bash
# Count completed songs
ls -l output/completed/

# Check current progress in logs
grep "Processing song" logs/automation/combined.log | tail -5
```

## 🧠 Understanding the Code

### Node.js and JavaScript Fundamentals

Since you're new to JavaScript, here are key concepts used in this project:

**Asynchronous Programming**
```javascript
// Functions that take time use 'await'
await page.click(button);           // Wait for click to complete
await sleep(4000);                  // Wait 4 seconds
await submitSong();                 // Wait for submission to finish
```

**Promises and Error Handling**
```javascript
try {
    const result = await riskyOperation();
    // Handle success
} catch (error) {
    // Handle errors
    logger.error('Something went wrong:', error);
}
```

**Classes and Objects**
```javascript
// A class is a blueprint for creating objects
class SunoAutomator {
    constructor() {
        this.browser = null;    // Properties store data
    }
    
    async initialize() {        // Methods perform actions
        this.browser = await chromium.launch();
    }
}

// Create an instance (object) from the class
const automator = new SunoAutomator();
```

### Key Libraries and Their Roles

**Playwright** - Browser Automation
```javascript
// Playwright controls a real browser programmatically
const browser = await chromium.launch();    // Start browser
const page = await browser.newPage();       // Open tab
await page.goto('https://suno.com');        // Navigate
await page.click('#button');                // Click elements
await page.fill('#input', 'text');          // Type text
```

**Winston** - Logging
```javascript
// Winston helps track what's happening
logger.info('Process started');       // Information
logger.warn('Something unusual');      // Warning
logger.error('Something failed');      // Error
```

**CSV-Parser** - Data Reading
```javascript
// Converts CSV text into JavaScript objects
// "title,style,lyrics" becomes {title: "...", style: "...", lyrics: "..."}
```

### Code Organization Patterns

**Configuration at the Top**
```javascript
const CONFIG = {
    timeout: 30000,
    delays: { betweenSongs: 240000 }
};
// Keeps all settings in one place for easy changes
```

**Error Handling Throughout**
```javascript
// Every operation that might fail is wrapped in try/catch
try {
    await riskyOperation();
} catch (error) {
    logger.error('Failed:', error);
    // Continue with next operation or retry
}
```

**Modular Functions**
```javascript
// Break complex tasks into smaller, focused functions
async function fillSongForm(song) {          // Single responsibility
    await fillLyrics(song.lyrics);
    await fillStyle(song.style);
    await fillTitle(song.title);
}
```

### Understanding the Main Flow

1. **Initialization Phase**
   ```javascript
   // Set up browser, load authentication, navigate to page
   await automator.initialize();
   await automator.loadSession();
   await automator.navigateToCreatePage();
   ```

2. **Processing Loop** 
   ```javascript
   // For each song in the CSV
   for (const song of songs) {
       const result = await automator.processSong(song);
       results.push(result);
       await sleep(CONFIG.delays.betweenSongs);
   }
   ```

3. **Cleanup and Results**
   ```javascript
   // Save results and clean up resources
   await saveResultsToCsv(results);
   await automator.cleanup();
   ```

## 📚 Development Best Practices

### Version Control with Git

**Understanding Git Concepts**
- **Repository**: Your project folder with complete history
- **Commit**: A snapshot of your code at a specific time
- **Branch**: Parallel version of your code for features/experiments
- **Remote**: Copy of your repository on GitHub/GitLab

**Essential Git Commands**
```bash
# Check status of your changes
git status

# See what's changed
git diff

# Add files to staging area
git add filename.js
git add .                    # Add all changes

# Create a commit with descriptive message
git commit -m "Add CSV validation to prevent malformed data"

# Push changes to remote repository  
git push origin main

# Create a new feature branch
git checkout -b feature/improve-error-handling

# Switch between branches
git checkout main
git checkout feature/improve-error-handling

# Merge feature back to main
git checkout main
git merge feature/improve-error-handling
```

**Commit Message Best Practices**
```bash
# Good commit messages are descriptive and explain WHY
git commit -m "Fix session timeout by increasing retry delay

Previous 10-second timeout was too short for slow networks.
Increased to 30 seconds and added exponential backoff
for better reliability."

# Bad commit messages
git commit -m "fix stuff"
git commit -m "updates"
git commit -m "debugging"
```

### GitHub Best Practices

**Repository Setup**
```bash
# Initialize repository and connect to GitHub
git init
git remote add origin https://github.com/yourusername/suno-automation.git
git branch -M main
git push -u origin main
```

**Issue Tracking**
- Create issues for bugs and feature requests
- Use labels: `bug`, `enhancement`, `documentation`
- Reference issues in commits: `git commit -m "Fix timeout issue #23"`

**Pull Requests**
```bash
# Create feature branch
git checkout -b feature/add-music-genre-detection

# Make changes and commit
git add .
git commit -m "Add genre detection from lyrics analysis"

# Push branch to GitHub
git push origin feature/add-music-genre-detection

# Create Pull Request on GitHub web interface
# Request review from team members
```

**README and Documentation**
- Keep README.md up-to-date with setup instructions
- Document any configuration changes
- Include troubleshooting for common issues

### Code Quality Standards

**Consistent Formatting**
```javascript
// Use consistent indentation (2 or 4 spaces)
if (condition) {
    doSomething();
    doSomethingElse();
}

// Descriptive variable names
const songProcessingResults = [];    // Good
const results = [];                  // Okay
const r = [];                       // Bad
```

**Error Handling Patterns**
```javascript
// Always handle errors gracefully
async function processSong(song) {
    try {
        const result = await submitToSuno(song);
        return { status: 'success', data: result };
    } catch (error) {
        logger.error(`Failed to process ${song.title}:`, error);
        return { status: 'failed', error: error.message };
    }
}
```

**Configuration Management**
```javascript
// Use environment variables for settings
const config = {
    timeout: process.env.TIMEOUT || 30000,           // Fallback values
    apiUrl: process.env.API_URL || 'default-url',
    debug: process.env.DEBUG === 'true'              // Boolean conversion
};
```

### Testing Strategies

**Manual Testing**
```bash
# Test with small CSV file first
echo "title,style,lyrics
Test Song,acoustic,Test lyrics" > input/songs/test.csv

# Run with debug mode
HEADLESS=false ./scripts/build-and-deploy.sh run
```

**Automated Testing** (Future Enhancement)
```javascript
// src/test.js - Basic test structure
const { SunoAutomator } = require('./index.js');

async function testBasicFunctionality() {
    const automator = new SunoAutomator();
    
    try {
        await automator.initialize();
        console.log('✅ Browser initialization works');
        
        await automator.navigateToCreatePage();
        console.log('✅ Navigation works');
        
    } catch (error) {
        console.log('❌ Test failed:', error.message);
    } finally {
        await automator.cleanup();
    }
}

testBasicFunctionality();
```

### Dependency Management

**Understanding package.json**
```json
{
  "dependencies": {
    "playwright": "^1.40.0"     // ^ means "compatible version"
  },
  "devDependencies": {          // Only needed for development
    "nodemon": "^3.0.1"        // Auto-restart during development
  }
}
```

**Updating Dependencies**
```bash
# Check for outdated packages
npm outdated

# Update specific package
npm install playwright@latest

# Update all packages (be careful!)
npm update

# Audit for security vulnerabilities
npm audit
npm audit fix
```

**Lock Files**
- `package-lock.json` ensures everyone gets exact same dependency versions
- Always commit `package-lock.json` to Git
- Never manually edit lock files

### Docker Best Practices

**Multi-stage Builds** (Advanced)
```dockerfile
# Separate build and runtime stages for smaller images
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-slim AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
CMD ["npm", "start"]
```

**Security Considerations**
```dockerfile
# Run as non-root user
RUN groupadd -r automation && useradd -r -g automation automation
USER automation

# Use specific versions, not 'latest'
FROM node:18.17.0-bullseye

# Minimize attack surface
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

## 🔒 Security Considerations

### Authentication Token Security

**Session Data Protection**
- Session tokens are equivalent to passwords
- Never commit session.json to version control
- Rotate sessions regularly (monthly recommended)
- Use environment variables for sensitive data

**File Permissions**
```bash
# Restrict access to session file
chmod 600 session.json
chown $USER:$USER session.json

# Check file permissions
ls -la session.json
# Should show: -rw------- (owner read/write only)
```

### Container Security

**Network Isolation**
```yaml
# docker-compose.yml - Remove host networking in production
services:
  suno-automation:
    network_mode: bridge    # Instead of host
    ports:
      - "127.0.0.1:3000:3000"  # Bind to localhost only
```

**Volume Security**
```bash
# Mount only necessary directories
docker run \
  --volume $(pwd)/input:/app/input:ro \     # Read-only input
  --volume $(pwd)/output:/app/output \      # Read-write output
  --volume $(pwd)/logs:/app/logs \          # Read-write logs
  suno-automation
```

### Code Security

**Input Validation**
```javascript
// Validate CSV data before processing
function validateSong(song) {
    if (!song.title || song.title.length > 100) {
        throw new Error('Invalid title length');
    }
    if (!song.lyrics || song.lyrics.length > 5000) {
        throw new Error('Invalid lyrics length');
    }
    // Additional validation...
}
```

**Error Information Leakage**
```javascript
// Don't expose sensitive info in logs
try {
    await authenticatedRequest(secretToken);
} catch (error) {
    // Good: Generic error message
    logger.error('Authentication failed');
    
    // Bad: Exposes token
    logger.error(`Auth failed with token ${secretToken}: ${error}`);
}
```

### Dependency Security

**Regular Updates**
```bash
# Check for security vulnerabilities
npm audit

# Fix automatically where possible
npm audit fix

# Update specific vulnerable package
npm install package-name@latest
```

**Dependabot Configuration** (GitHub)
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    reviewers:
      - "yourusername"
```

## ❓ FAQ and Common Issues

### Q: How many songs can I process at once?
**A**: This depends on your Suno subscription limits. The automation waits 4 minutes between submissions to respect rate limits. Plan for about 15 songs per hour.

### Q: What happens if my session expires during processing?
**A**: The automation will fail and log the error. You'll need to recapture your session.json and restart. Consider processing in smaller batches for long runs.

### Q: Can I run this on Windows directly?
**A**: The scripts are designed for Linux/WSL. On Windows, use WSL2 with Ubuntu 24.04 for best compatibility.

### Q: How do I know if a song was successful?
**A**: Check the results CSV in `output/completed/`. Successful songs will have a Suno ID and status 'success'.

### Q: Can I modify the 4-minute delay?
**A**: Yes, edit `DELAY_BETWEEN_SONGS` in the .env file. Be careful not to set it too low or you might hit rate limits.

### Q: What if Suno changes their interface?
**A**: The automation uses data-testid selectors which are more stable, but interface changes may require code updates. Check logs for "element not found" errors.

### Q: How do I add more songs while automation is running?
**A**: Stop the automation, add songs to your CSV, and restart. The system doesn't support hot-reloading of CSV files.

### Q: Can I run multiple instances simultaneously?
**A**: Not recommended. Multiple instances might interfere with each other and could trigger anti-automation measures.

### Q: How do I backup my session and data?
**A**: 
```bash
# Backup important files
cp session.json session.json.backup
tar -czf backup-$(date +%Y%m%d).tar.gz input/ output/ session.json .env
```

### Q: What's the difference between docker run and docker-compose?
**A**: 
- `docker run`: Single container, good for simple scenarios
- `docker-compose`: Multi-container setup, better for complex applications
- Use docker-compose for this project (it's the default)

### Q: How do I update the automation when new versions are available?
**A**:
```bash
# Pull latest code
git pull origin main

# Rebuild and deploy
./scripts/build-and-deploy.sh full
```

### Troubleshooting Checklist

**Before Running**
- [ ] Session.json exists and is recent (< 1 week old)
- [ ] CSV file exists in input/songs/ directory
- [ ] CSV file has correct format (title, style, lyrics columns)
- [ ] Docker is installed and running
- [ ] User is in docker group (`groups $USER` should show docker)

**If Automation Fails**
- [ ] Check container logs: `docker logs suno-automation`
- [ ] Verify CSV format: `head input/songs/your-file.csv`
- [ ] Test authentication: Access suno.com/create in browser
- [ ] Check disk space: `df -h`
- [ ] Verify network connectivity: `ping suno.com`

**Performance Issues**
- [ ] Check system resources: `htop` or `docker stats`
- [ ] Verify browser isn't running in visible mode unnecessarily
- [ ] Ensure SSD storage (automation is disk-intensive)
- [ ] Check for other browser instances consuming memory

---

## 🎉 Conclusion

This automation system provides a robust, scalable solution for managing your Suno credits efficiently. By following these instructions and best practices, you'll have a reliable tool that can process hundreds of songs with minimal manual intervention.

Remember to:
- Start with small batches to test your setup
- Monitor logs regularly for issues
- Keep your authentication session current
- Follow security best practices with sensitive data
- Contribute improvements back to the project

Happy automating! 🎵

---

**Last Updated**: July 2025
**Version**: 1.0.0
**Compatibility**: Suno.com v4.5, Node.js 18+, Docker 24+