// src/test.js - Comprehensive testing and validation suite
// This script validates that all components are working correctly

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { SunoAutomator } = require('./index.js');
require('dotenv').config();

// ===== TEST CONFIGURATION =====
const TEST_CONFIG = {
    timeout: 10000,
    headless: process.env.TEST_HEADLESS !== 'false',
    testSessionFile: 'test-session.json',
    testCsvFile: 'input/songs/test-songs.csv'
};

// ===== UTILITY FUNCTIONS =====

/**
 * Simple test runner - tracks passed/failed tests
 */
class TestRunner {
    constructor() {
        this.tests = [];
        this.passed = 0;
        this.failed = 0;
    }
    
    async run(name, testFunction) {
        console.log(`\n🧪 Running test: ${name}`);
        try {
            await testFunction();
            this.passed++;
            console.log(`✅ PASSED: ${name}`);
        } catch (error) {
            this.failed++;
            console.log(`❌ FAILED: ${name}`);
            console.log(`   Error: ${error.message}`);
            if (process.env.DEBUG === 'true') {
                console.log(`   Stack: ${error.stack}`);
            }
        }
    }
    
    summary() {
        const total = this.passed + this.failed;
        console.log(`\n📊 Test Summary:`);
        console.log(`   Total: ${total}`);
        console.log(`   Passed: ${this.passed}`);
        console.log(`   Failed: ${this.failed}`);
        console.log(`   Success Rate: ${total > 0 ? Math.round((this.passed / total) * 100) : 0}%`);
        
        return this.failed === 0;
    }
}

/**
 * Create test CSV file with sample data
 */
function createTestCsv() {
    const testData = `title,style,lyrics
"Test Song 1","acoustic guitar folk","[Verse 1]
This is a test song
For validation purposes
[Chorus]
Testing automation
Everything should work fine"
"Test Song 2","electronic synthwave","[Intro]
Synthetic melodies
[Verse 1]  
Digital dreams in neon lights
Virtual worlds and cyber nights
[Chorus]
We are the future generation
Living in digital creation"`;

    // Ensure directory exists
    const dir = path.dirname(TEST_CONFIG.testCsvFile);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    
    fs.writeFileSync(TEST_CONFIG.testCsvFile, testData);
    console.log(`📝 Created test CSV: ${TEST_CONFIG.testCsvFile}`);
}

/**
 * Cleanup test files
 */
function cleanupTestFiles() {
    const filesToClean = [
        TEST_CONFIG.testCsvFile,
        TEST_CONFIG.testSessionFile
    ];
    
    filesToClean.forEach(file => {
        if (fs.existsSync(file)) {
            fs.unlinkSync(file);
            console.log(`🗑️ Cleaned up: ${file}`);
        }
    });
}

// ===== INDIVIDUAL TEST FUNCTIONS =====

/**
 * Test 1: Environment and Dependencies
 */
async function testEnvironmentSetup() {
    // Check Node.js version
    const nodeVersion = process.version;
    if (!nodeVersion.startsWith('v18') && !nodeVersion.startsWith('v20')) {
        throw new Error(`Node.js version ${nodeVersion} may not be compatible (recommend v18+)`);
    }
    
    // Check required directories
    const requiredDirs = ['src', 'input', 'output', 'logs'];
    for (const dir of requiredDirs) {
        if (!fs.existsSync(dir)) {
            throw new Error(`Required directory missing: ${dir}`);
        }
    }
    
    // Check package.json
    if (!fs.existsSync('package.json')) {
        throw new Error('package.json not found');
    }
    
    const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    const requiredDeps = ['playwright', 'csv-parser', 'winston'];
    for (const dep of requiredDeps) {
        if (!packageJson.dependencies[dep]) {
            throw new Error(`Required dependency missing: ${dep}`);
        }
    }
    
    console.log('   ✓ Node.js version compatible');
    console.log('   ✓ Directory structure valid');
    console.log('   ✓ Dependencies configured');
}

/**
 * Test 2: Configuration Files
 */
async function testConfigurationFiles() {
    // Check .env.example exists
    if (!fs.existsSync('.env.example')) {
        throw new Error('.env.example template not found');
    }
    
    // Check Docker files
    if (!fs.existsSync('Dockerfile')) {
        throw new Error('Dockerfile not found');
    }
    
    if (!fs.existsSync('docker-compose.yml')) {
        throw new Error('docker-compose.yml not found');
    }
    
    // Validate docker-compose.yml structure
    const dockerCompose = fs.readFileSync('docker-compose.yml', 'utf8');
    if (!dockerCompose.includes('suno-automation') || !dockerCompose.includes('volumes:')) {
        throw new Error('docker-compose.yml missing required configuration');
    }
    
    console.log('   ✓ Environment template exists');
    console.log('   ✓ Docker configuration valid');
}

/**
 * Test 3: CSV Processing
 */
async function testCsvProcessing() {
    // Create test CSV
    createTestCsv();
    
    // Import CSV reading function
    const csv = require('csv-parser');
    
    return new Promise((resolve, reject) => {
        const songs = [];
        let errorOccurred = false;
        
        fs.createReadStream(TEST_CONFIG.testCsvFile)
            .pipe(csv())
            .on('data', (row) => {
                if (row.title && row.style && row.lyrics) {
                    songs.push(row);
                } else {
                    errorOccurred = true;
                    reject(new Error(`Invalid CSV row: ${JSON.stringify(row)}`));
                }
            })
            .on('end', () => {
                if (!errorOccurred) {
                    if (songs.length !== 2) {
                        reject(new Error(`Expected 2 songs, got ${songs.length}`));
                    } else {
                        console.log(`   ✓ CSV parsing successful (${songs.length} songs)`);
                        console.log(`   ✓ Song titles: ${songs.map(s => s.title).join(', ')}`);
                        resolve();
                    }
                }
            })
            .on('error', reject);
    });
}

/**
 * Test 4: Browser Automation Setup
 */
async function testBrowserAutomation() {
    console.log('   Starting browser...');
    
    const browser = await chromium.launch({
        headless: TEST_CONFIG.headless,
        timeout: TEST_CONFIG.timeout
    });
    
    const page = await browser.newPage();
    
    try {
        // Test basic navigation
        await page.goto('https://httpbin.org/html', { timeout: TEST_CONFIG.timeout });
        const title = await page.title();
        
        if (!title.includes('httpbin')) {
            throw new Error('Failed to load test page');
        }
        
        // Test form interaction
        await page.setContent(`
            <html>
                <body>
                    <textarea id="test-textarea" placeholder="Test textarea"></textarea>
                    <input id="test-input" placeholder="Test input" />
                    <button id="test-button">Test Button</button>
                </body>
            </html>
        `);
        
        await page.fill('#test-textarea', 'Test content');
        await page.fill('#test-input', 'Test input value');
        await page.click('#test-button');
        
        const textareaValue = await page.inputValue('#test-textarea');
        const inputValue = await page.inputValue('#test-input');
        
        if (textareaValue !== 'Test content') {
            throw new Error('Textarea fill failed');
        }
        
        if (inputValue !== 'Test input value') {
            throw new Error('Input fill failed');
        }
        
        console.log('   ✓ Browser launched successfully');
        console.log('   ✓ Page navigation working');
        console.log('   ✓ Form interaction working');
        
    } finally {
        await browser.close();
    }
}

/**
 * Test 5: Session Management
 */
async function testSessionManagement() {
    // Create mock session data
    const mockSession = {
        captured_at: new Date().toISOString(),
        method: 'test',
        cookies: [
            {
                name: '__client',
                value: 'test-token-value',
                domain: 'suno.com',
                path: '/',
                secure: true,
                httpOnly: false
            },
            {
                name: '__client_uat',
                value: '1234567890',
                domain: 'suno.com',
                path: '/',
                secure: true,
                httpOnly: false
            }
        ]
    };
    
    // Write test session file
    fs.writeFileSync(TEST_CONFIG.testSessionFile, JSON.stringify(mockSession, null, 2));
    
    // Test reading session file
    const loadedSession = JSON.parse(fs.readFileSync(TEST_CONFIG.testSessionFile, 'utf8'));
    
    if (!loadedSession.cookies || loadedSession.cookies.length !== 2) {
        throw new Error('Session data structure invalid');
    }
    
    if (!loadedSession.cookies.some(c => c.name === '__client')) {
        throw new Error('Required __client cookie missing');
    }
    
    console.log('   ✓ Session file creation working');
    console.log('   ✓ Session data structure valid');
    console.log(`   ✓ Found ${loadedSession.cookies.length} cookies`);
}

/**
 * Test 6: Network and Suno Accessibility
 */
async function testNetworkAccess() {
    const browser = await chromium.launch({
        headless: TEST_CONFIG.headless,
        timeout: TEST_CONFIG.timeout
    });
    
    const page = await browser.newPage();
    
    try {
        console.log('   Testing Suno.com accessibility...');
        
        // Navigate to Suno homepage
        const response = await page.goto('https://suno.com', { 
            timeout: TEST_CONFIG.timeout,
            waitUntil: 'networkidle' 
        });
        
        if (!response.ok()) {
            throw new Error(`Suno.com returned status: ${response.status()}`);
        }
        
        // Check if the page loaded correctly
        const title = await page.title();
        if (!title.toLowerCase().includes('suno')) {
            console.log(`   Warning: Unexpected page title: ${title}`);
        }
        
        // Test if we can reach the create page (without authentication)
        const createResponse = await page.goto('https://suno.com/create', {
            timeout: TEST_CONFIG.timeout,
            waitUntil: 'networkidle'
        });
        
        // This might redirect to login, which is expected
        const currentUrl = page.url();
        
        console.log('   ✓ Suno.com is accessible');
        console.log(`   ✓ Create page response: ${createResponse.status()}`);
        console.log(`   ✓ Final URL: ${currentUrl}`);
        
        // Check if we can see typical form elements (might be behind auth)
        const hasFormElements = await page.locator('textarea, input[type="text"]').count() > 0;
        if (hasFormElements) {
            console.log('   ✓ Form elements detected (likely authenticated)');
        } else {
            console.log('   ⚠ No form elements (likely needs authentication)');
        }
        
    } finally {
        await browser.close();
    }
}

/**
 * Test 7: Main Automation Class
 */
async function testAutomationClass() {
    const automator = new SunoAutomator();
    
    try {
        // Test initialization
        await automator.initialize();
        console.log('   ✓ SunoAutomator initialization successful');
        
        // Test navigation (will fail without auth, but should not crash)
        try {
            await automator.navigateToCreatePage();
            console.log('   ✓ Navigation to create page successful');
        } catch (error) {
            if (error.message.includes('authentication')) {
                console.log('   ⚠ Navigation failed due to authentication (expected)');
            } else {
                throw error;
            }
        }
        
        // Test cleanup
        await automator.cleanup();
        console.log('   ✓ Cleanup successful');
        
    } catch (error) {
        // Ensure cleanup even if test fails
        try {
            await automator.cleanup();
        } catch (cleanupError) {
            console.log(`   Warning: Cleanup failed: ${cleanupError.message}`);
        }
        throw error;
    }
}

/**
 * Test 8: Logging System
 */
async function testLoggingSystem() {
    const winston = require('winston');
    
    // Ensure logs directory exists
    if (!fs.existsSync('logs/automation')) {
        fs.mkdirSync('logs/automation', { recursive: true });
    }
    
    // Create test logger
    const testLogger = winston.createLogger({
        level: 'info',
        format: winston.format.combine(
            winston.format.timestamp(),
            winston.format.json()
        ),
        transports: [
            new winston.transports.File({ 
                filename: 'logs/automation/test.log' 
            })
        ]
    });
    
    // Test logging
    testLogger.info('Test info message');
    testLogger.warn('Test warning message');
    testLogger.error('Test error message');
    
    // Wait a moment for file write
    await new Promise(resolve => setTimeout(resolve, 100));
    
    // Check if log file was created and has content
    if (!fs.existsSync('logs/automation/test.log')) {
        throw new Error('Log file was not created');
    }
    
    const logContent = fs.readFileSync('logs/automation/test.log', 'utf8');
    if (!logContent.includes('Test info message')) {
        throw new Error('Log content not written correctly');
    }
    
    console.log('   ✓ Logger configuration working');
    console.log('   ✓ Log file creation successful');
    console.log('   ✓ Log content validation passed');
    
    // Cleanup test log
    fs.unlinkSync('logs/automation/test.log');
}

/**
 * Test 9: Docker Environment (if available)
 */
async function testDockerEnvironment() {
    const { exec } = require('child_process');
    const util = require('util');
    const execAsync = util.promisify(exec);
    
    try {
        // Check if Docker is available
        await execAsync('docker --version');
        console.log('   ✓ Docker is available');
        
        // Check if docker-compose is available
        await execAsync('docker compose version');
        console.log('   ✓ Docker Compose is available');
        
        // Validate Dockerfile syntax
        await execAsync('docker build --dry-run . > /dev/null 2>&1');
        console.log('   ✓ Dockerfile syntax valid');
        
        // Validate docker-compose configuration
        await execAsync('docker compose config > /dev/null 2>&1');
        console.log('   ✓ docker-compose.yml valid');
        
    } catch (error) {
        throw new Error(`Docker environment issue: ${error.message}`);
    }
}

// ===== MAIN TEST EXECUTION =====

/**
 * Main test function that runs all validation tests
 */
async function runAllTests() {
    console.log('🚀 Starting Suno Automation Validation Tests\n');
    console.log('=====================================');
    
    const runner = new TestRunner();
    
    // Run all tests
    await runner.run('Environment Setup', testEnvironmentSetup);
    await runner.run('Configuration Files', testConfigurationFiles);
    await runner.run('CSV Processing', testCsvProcessing);
    await runner.run('Browser Automation', testBrowserAutomation);
    await runner.run('Session Management', testSessionManagement);
    await runner.run('Network Access', testNetworkAccess);
    await runner.run('Automation Class', testAutomationClass);
    await runner.run('Logging System', testLoggingSystem);
    
    // Docker test is optional (might not be available in all environments)
    try {
        await runner.run('Docker Environment', testDockerEnvironment);
    } catch (error) {
        console.log('⚠️ Skipping Docker test (Docker not available or configured)');
    }
    
    // Cleanup
    cleanupTestFiles();
    
    // Show summary
    const success = runner.summary();
    
    console.log('\n=====================================');
    if (success) {
        console.log('🎉 All tests passed! System is ready for automation.');
        console.log('\n📋 Next Steps:');
        console.log('1. Capture your Suno session: Follow authentication guide');
        console.log('2. Prepare your CSV file: Add songs to input/songs/');
        console.log('3. Run automation: ./scripts/build-and-deploy.sh full');
    } else {
        console.log('❌ Some tests failed. Please fix issues before proceeding.');
        console.log('\n🔧 Troubleshooting:');
        console.log('- Check error messages above');
        console.log('- Ensure all dependencies are installed');
        console.log('- Run setup.sh if not already done');
        console.log('- Check docs/INSTRUCTIONS.md for detailed help');
    }
    
    process.exit(success ? 0 : 1);
}

/**
 * Interactive test runner - allows running individual tests
 */
async function runInteractiveTests() {
    const readline = require('readline');
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    });
    
    const question = (prompt) => new Promise(resolve => rl.question(prompt, resolve));
    
    console.log('🧪 Interactive Test Runner');
    console.log('Available tests:');
    console.log('1. Environment Setup');
    console.log('2. Configuration Files');
    console.log('3. CSV Processing');
    console.log('4. Browser Automation');
    console.log('5. Session Management');
    console.log('6. Network Access');
    console.log('7. Automation Class');
    console.log('8. Logging System');
    console.log('9. Docker Environment');
    console.log('0. Run All Tests');
    
    const choice = await question('\nSelect test to run (0-9): ');
    rl.close();
    
    const runner = new TestRunner();
    
    switch (choice) {
        case '1': await runner.run('Environment Setup', testEnvironmentSetup); break;
        case '2': await runner.run('Configuration Files', testConfigurationFiles); break;
        case '3': await runner.run('CSV Processing', testCsvProcessing); break;
        case '4': await runner.run('Browser Automation', testBrowserAutomation); break;
        case '5': await runner.run('Session Management', testSessionManagement); break;
        case '6': await runner.run('Network Access', testNetworkAccess); break;
        case '7': await runner.run('Automation Class', testAutomationClass); break;
        case '8': await runner.run('Logging System', testLoggingSystem); break;
        case '9': await runner.run('Docker Environment', testDockerEnvironment); break;
        case '0': return runAllTests();
        default: 
            console.log('Invalid choice');
            return;
    }
    
    cleanupTestFiles();
    runner.summary();
}

// ===== COMMAND LINE INTERFACE =====

if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.includes('--interactive') || args.includes('-i')) {
        runInteractiveTests();
    } else if (args.includes('--help') || args.includes('-h')) {
        console.log('Suno Automation Test Suite');
        console.log('');
        console.log('Usage:');
        console.log('  node src/test.js              Run all tests');
        console.log('  node src/test.js -i           Interactive mode');
        console.log('  node src/test.js --help       Show this help');
        console.log('');
        console.log('Environment Variables:');
        console.log('  TEST_HEADLESS=false           Show browser during tests');
        console.log('  DEBUG=true                    Show detailed error info');
    } else {
        runAllTests();
    }
}

module.exports = {
    runAllTests,
    runInteractiveTests,
    TestRunner
};
