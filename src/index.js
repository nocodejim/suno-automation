// src/index.js - Main automation script for Suno song generation
// This is the core application that handles the entire automation process

// Import required libraries
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const winston = require('winston');
require('dotenv').config();

// ===== LOGGING CONFIGURATION =====
// Winston is a popular logging library that helps us track what's happening
// This creates structured logs with timestamps and different severity levels
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'suno-automation' },
    transports: [
        // Log errors to a separate file for easy debugging
        new winston.transports.File({ 
            filename: 'logs/automation/error.log', 
            level: 'error' 
        }),
        // Log everything to a combined file
        new winston.transports.File({ 
            filename: 'logs/automation/combined.log' 
        }),
        // Also show logs in console during development
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

// ===== CONFIGURATION =====
// These settings control how the automation behaves
const CONFIG = {
    // Browser settings
    headless: process.env.HEADLESS === 'true',
    timeout: parseInt(process.env.TIMEOUT) || 30000,
    viewport: {
        width: parseInt(process.env.VIEWPORT_WIDTH) || 1920,
        height: parseInt(process.env.VIEWPORT_HEIGHT) || 1080
    },
    
    // Timing settings (in milliseconds)
    delays: {
        betweenSongs: parseInt(process.env.DELAY_BETWEEN_SONGS) || 240000, // 4 minutes
        formFill: parseInt(process.env.FORM_FILL_DELAY) || 1000, // 1 second
        submission: parseInt(process.env.SUBMISSION_TIMEOUT) || 10000 // 10 seconds
    },
    
    // File paths
    inputCsv: process.env.INPUT_CSV || 'input/songs/songs.csv',
    outputDir: process.env.OUTPUT_DIR || 'output/completed',
    sessionFile: process.env.SESSION_FILE || 'session.json',
    
    // Retry settings
    retryAttempts: parseInt(process.env.RETRY_ATTEMPTS) || 3,
    
    // Suno-specific settings
    suno: {
        url: 'https://suno.com/create',
        apiEndpoint: 'https://studio-api.prod.suno.com/api/generate/v2-web/',
        selectors: {
            lyricsTextarea: '[data-testid="lyrics-input-textarea"]',
            styleTextarea: '[data-testid="tag-input-textarea"]',
            titleInput: 'input[placeholder="Enter song title"]',
            createButton: 'span:has-text("Create")'
        }
    }
};

// ===== UTILITY FUNCTIONS =====

/**
 * Sleep function - pauses execution for specified milliseconds
 * This is essential for automation to wait between actions
 * @param {number} ms - milliseconds to sleep
 */
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * Ensure directory exists, create if it doesn't
 * @param {string} dirPath - path to directory
 */
const ensureDirectoryExists = (dirPath) => {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
        logger.info(`Created directory: ${dirPath}`);
    }
};

/**
 * Read CSV file and return array of song objects
 * CSV parsing converts text data into JavaScript objects we can work with
 * @param {string} filePath - path to CSV file
 * @returns {Promise<Array>} array of song objects
 */
const readSongsFromCsv = (filePath) => {
    return new Promise((resolve, reject) => {
        const songs = [];
        
        if (!fs.existsSync(filePath)) {
            reject(new Error(`CSV file not found: ${filePath}`));
            return;
        }
        
        fs.createReadStream(filePath)
            .pipe(csv())
            .on('data', (row) => {
                // Validate required fields
                if (row.title && row.style && row.lyrics) {
                    songs.push({
                        title: row.title.trim(),
                        style: row.style.trim(),
                        lyrics: row.lyrics.trim(),
                        status: 'pending'
                    });
                } else {
                    logger.warn(`Skipping incomplete row: ${JSON.stringify(row)}`);
                }
            })
            .on('end', () => {
                logger.info(`Loaded ${songs.length} songs from CSV`);
                resolve(songs);
            })
            .on('error', reject);
    });
};

/**
 * Save results to CSV file for tracking
 * @param {Array} results - array of result objects
 * @param {string} filename - output filename
 */
const saveResultsToCsv = async (results, filename) => {
    const csvWriter = createCsvWriter({
        path: path.join(CONFIG.outputDir, filename),
        header: [
            { id: 'title', title: 'Title' },
            { id: 'style', title: 'Style' },
            { id: 'status', title: 'Status' },
            { id: 'submittedAt', title: 'Submitted At' },
            { id: 'error', title: 'Error Message' },
            { id: 'sunoId', title: 'Suno ID' }
        ]
    });
    
    await csvWriter.writeRecords(results);
    logger.info(`Results saved to: ${filename}`);
};

// ===== BROWSER AUTOMATION CLASS =====

/**
 * SunoAutomator class handles all browser automation logic
 * Classes help organize related functions together
 */
class SunoAutomator {
    constructor() {
        this.browser = null;
        this.page = null;
        this.isAuthenticated = false;
    }
    
    /**
     * Initialize browser and page
     * Playwright creates a real browser instance we can control
     */
    async initialize() {
        logger.info('Initializing browser...');
        
        this.browser = await chromium.launch({
            headless: CONFIG.headless,
            args: [
                '--no-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--no-first-run',
                '--disable-default-apps'
            ]
        });
        
        this.page = await this.browser.newPage({
            viewport: CONFIG.viewport
        });
        
        // Set longer timeout for slow networks
        this.page.setDefaultTimeout(CONFIG.timeout);
        
        logger.info('Browser initialized successfully');
    }
    
    /**
     * Load authentication session from cookies
     * This allows us to stay logged in without manual login
     */
    async loadSession() {
        logger.info('Loading session...');
        
        if (fs.existsSync(CONFIG.sessionFile)) {
            try {
                const sessionData = JSON.parse(fs.readFileSync(CONFIG.sessionFile, 'utf8'));
                
                if (sessionData.cookies && sessionData.cookies.length > 0) {
                    await this.page.context().addCookies(sessionData.cookies);
                    logger.info('Session cookies loaded successfully');
                    this.isAuthenticated = true;
                } else {
                    logger.warn('No cookies found in session file');
                }
            } catch (error) {
                logger.error('Failed to load session:', error);
            }
        } else {
            logger.warn(`Session file not found: ${CONFIG.sessionFile}`);
            logger.info('Please run the setup process to capture authentication');
        }
    }
    
    /**
     * Navigate to Suno create page and verify we can access it
     */
    async navigateToCreatePage() {
        logger.info('Navigating to Suno create page...');
        
        await this.page.goto(CONFIG.suno.url, { 
            waitUntil: 'networkidle' 
        });
        
        // Wait for the form to be ready
        try {
            await this.page.waitForSelector(CONFIG.suno.selectors.lyricsTextarea, {
                timeout: 10000
            });
            logger.info('Create page loaded successfully');
        } catch (error) {
            logger.error('Failed to load create page - may need authentication');
            throw new Error('Create page not accessible - check authentication');
        }
    }
    
    /**
     * Fill out the song creation form
     * @param {Object} song - song object with title, style, lyrics
     */
    async fillSongForm(song) {
        logger.info(`Filling form for song: ${song.title}`);
        
        try {
            // Clear and fill lyrics textarea
            await this.page.click(CONFIG.suno.selectors.lyricsTextarea);
            await this.page.fill(CONFIG.suno.selectors.lyricsTextarea, '');
            await sleep(CONFIG.delays.formFill);
            await this.page.fill(CONFIG.suno.selectors.lyricsTextarea, song.lyrics);
            
            // Clear and fill style textarea  
            await this.page.click(CONFIG.suno.selectors.styleTextarea);
            await this.page.fill(CONFIG.suno.selectors.styleTextarea, '');
            await sleep(CONFIG.delays.formFill);
            await this.page.fill(CONFIG.suno.selectors.styleTextarea, song.style);
            
            // Clear and fill title input
            await this.page.click(CONFIG.suno.selectors.titleInput);
            await this.page.fill(CONFIG.suno.selectors.titleInput, '');
            await sleep(CONFIG.delays.formFill);
            await this.page.fill(CONFIG.suno.selectors.titleInput, song.title);
            
            logger.info('Form filled successfully');
            
        } catch (error) {
            logger.error(`Failed to fill form for ${song.title}:`, error);
            throw error;
        }
    }
    
    /**
     * Submit the song for generation
     * Uses direct API call for more reliability than clicking buttons
     */
    async submitSong() {
        logger.info('Submitting song...');
        
        try {
            // Get the current form data
            const lyrics = await this.page.inputValue(CONFIG.suno.selectors.lyricsTextarea);
            const style = await this.page.inputValue(CONFIG.suno.selectors.styleTextarea);
            const title = await this.page.inputValue(CONFIG.suno.selectors.titleInput);
            
            // Prepare API request payload
            const payload = {
                prompt: lyrics,
                tags: style,
                title: title,
                make_instrumental: false,
                stream: true
            };
            
            // Make API request using browser's authenticated session
            const response = await this.page.evaluate(async (apiPayload) => {
                const response = await fetch('https://studio-api.prod.suno.com/api/generate/v2-web/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(apiPayload)
                });
                
                return {
                    status: response.status,
                    data: await response.json()
                };
            }, payload);
            
            if (response.status === 200) {
                logger.info(`Song submitted successfully. ID: ${response.data.id}`);
                return response.data;
            } else {
                throw new Error(`API request failed with status: ${response.status}`);
            }
            
        } catch (error) {
            logger.error('Failed to submit song:', error);
            throw error;
        }
    }
    
    /**
     * Process a single song through the entire workflow
     * @param {Object} song - song object
     * @returns {Object} result object
     */
    async processSong(song) {
        const startTime = new Date();
        logger.info(`Starting to process: ${song.title}`);
        
        try {
            // Fill the form
            await this.fillSongForm(song);
            
            // Submit the song
            const submissionResult = await this.submitSong();
            
            const result = {
                title: song.title,
                style: song.style,
                status: 'success',
                submittedAt: startTime.toISOString(),
                sunoId: submissionResult.id,
                error: null
            };
            
            logger.info(`Successfully processed: ${song.title}`);
            return result;
            
        } catch (error) {
            const result = {
                title: song.title,
                style: song.style,
                status: 'failed',
                submittedAt: startTime.toISOString(),
                sunoId: null,
                error: error.message
            };
            
            logger.error(`Failed to process ${song.title}:`, error);
            return result;
        }
    }
    
    /**
     * Clean up browser resources
     */
    async cleanup() {
        if (this.browser) {
            await this.browser.close();
            logger.info('Browser closed');
        }
    }
}

// ===== MAIN EXECUTION FUNCTION =====

/**
 * Main function that orchestrates the entire automation process
 * This is where everything comes together
 */
async function main() {
    const startTime = new Date();
    logger.info('Starting Suno automation...');
    
    // Ensure output directories exist
    ensureDirectoryExists(CONFIG.outputDir);
    ensureDirectoryExists('logs/automation');
    
    let automator = null;
    let results = [];
    
    try {
        // Load songs from CSV
        const songs = await readSongsFromCsv(CONFIG.inputCsv);
        
        if (songs.length === 0) {
            throw new Error('No valid songs found in CSV file');
        }
        
        // Initialize browser automation
        automator = new SunoAutomator();
        await automator.initialize();
        await automator.loadSession();
        await automator.navigateToCreatePage();
        
        // Process each song
        for (let i = 0; i < songs.length; i++) {
            const song = songs[i];
            logger.info(`Processing song ${i + 1}/${songs.length}: ${song.title}`);
            
            // Process the song with retry logic
            let result = null;
            for (let attempt = 1; attempt <= CONFIG.retryAttempts; attempt++) {
                try {
                    result = await automator.processSong(song);
                    break; // Success, exit retry loop
                } catch (error) {
                    logger.warn(`Attempt ${attempt} failed for ${song.title}: ${error.message}`);
                    if (attempt === CONFIG.retryAttempts) {
                        // Final attempt failed, create error result
                        result = {
                            title: song.title,
                            style: song.style,
                            status: 'failed',
                            submittedAt: new Date().toISOString(),
                            sunoId: null,
                            error: `Failed after ${CONFIG.retryAttempts} attempts: ${error.message}`
                        };
                    } else {
                        // Wait before retry
                        await sleep(5000);
                    }
                }
            }
            
            results.push(result);
            
            // Wait between songs (except for the last one)
            if (i < songs.length - 1) {
                logger.info(`Waiting ${CONFIG.delays.betweenSongs / 1000} seconds before next song...`);
                await sleep(CONFIG.delays.betweenSongs);
            }
        }
        
        // Save results
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        await saveResultsToCsv(results, `results-${timestamp}.csv`);
        
        // Summary
        const successful = results.filter(r => r.status === 'success').length;
        const failed = results.filter(r => r.status === 'failed').length;
        
        logger.info(`Automation completed!`);
        logger.info(`Total songs: ${results.length}`);
        logger.info(`Successful: ${successful}`);
        logger.info(`Failed: ${failed}`);
        logger.info(`Duration: ${Math.round((new Date() - startTime) / 1000)} seconds`);
        
    } catch (error) {
        logger.error('Fatal error in automation:', error);
        process.exit(1);
    } finally {
        // Always clean up browser resources
        if (automator) {
            await automator.cleanup();
        }
    }
}

// ===== ERROR HANDLING =====

// Handle unhandled promise rejections
process.on('unhandledRejection', (error) => {
    logger.error('Unhandled promise rejection:', error);
    process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception:', error);
    process.exit(1);
});

// Start the automation when this file is run directly
if (require.main === module) {
    main();
}

module.exports = { SunoAutomator, main };
