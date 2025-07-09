# Suno Automation

Automated song generation for Suno.com to efficiently use monthly credit allotments.

## 🎯 Purpose
This containerized solution automates the process of submitting songs to Suno, allowing you to:
- Batch process multiple songs from CSV files
- Automatically fill lyrics, style descriptions, and titles
- Wait appropriate intervals between submissions
- Track completion status and handle errors

## 🏗️ Architecture
- **Node.js + Playwright**: Browser automation framework
- **Docker**: Containerized environment for consistency
- **CSV Input**: Simple format for song data
- **API Integration**: Direct API calls for reliability

## 📁 Project Structure
```
├── src/                    # Source code
├── input/                  # Input CSV files and templates
├── output/                 # Completed songs and results
├── logs/                   # Automation and error logs
├── scripts/                # Build and deployment scripts
├── docs/                   # Documentation
└── .github/workflows/      # CI/CD configurations
```

## 🚀 Quick Start
1. Run setup: `./setup.sh`
2. Add your CSV file to `input/songs/`
3. Build and run: `./scripts/build-and-deploy.sh`

## 📚 Documentation
See [docs/INSTRUCTIONS.md](docs/INSTRUCTIONS.md) for complete setup and usage instructions.

## 🔒 Security Note
This project handles authentication tokens. Never commit session data to version control.
