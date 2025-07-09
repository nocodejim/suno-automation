// Session Capture Script for Suno Authentication
// Instructions:
// 1. Navigate to suno.com/create in Chrome
// 2. Open DevTools (F12) -> Console tab
// 3. Paste and run this entire script
// 4. Copy the output to session.json in your project root

(async function captureSession() {
    console.log('🔧 Capturing Suno session data...');
    
    // Method 1: Get cookies via document.cookie (works in all browsers)
    const cookieString = document.cookie;
    const cookies = cookieString.split(';').map(cookie => {
        const [name, value] = cookie.trim().split('=');
        return {
            name: name,
            value: value,
            domain: 'suno.com',
            path: '/',
            secure: true,
            httpOnly: false
        };
    }).filter(cookie => cookie.name); // Remove empty cookies
    
    // Method 2: Try to get more detailed cookie info (Chrome only)
    let detailedCookies = [];
    if (typeof chrome !== 'undefined' && chrome.cookies) {
        try {
            detailedCookies = await new Promise((resolve) => {
                chrome.cookies.getAll({domain: 'suno.com'}, resolve);
            });
        } catch (e) {
            console.log('⚠️ Detailed cookie access not available, using basic method');
        }
    }
    
    // Use detailed cookies if available, otherwise use basic method
    const finalCookies = detailedCookies.length > 0 ? detailedCookies : cookies;
    
    const sessionData = {
        captured_at: new Date().toISOString(),
        method: detailedCookies.length > 0 ? 'chrome_api' : 'document_cookie',
        cookies: finalCookies.map(cookie => ({
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain || 'suno.com',
            path: cookie.path || '/',
            secure: cookie.secure !== false,
            httpOnly: cookie.httpOnly || false
        }))
    };
    
    console.log('✅ Session captured successfully!');
    console.log(`📊 Found ${finalCookies.length} cookies`);
    console.log('📋 Copy the following JSON to session.json:');
    console.log('=====================================');
    console.log(JSON.stringify(sessionData, null, 2));
    console.log('=====================================');
    
    // Try to download as file (may not work in all browsers)
    try {
        const blob = new Blob([JSON.stringify(sessionData, null, 2)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'session.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('💾 Session file download initiated');
    } catch (e) {
        console.log('⚠️ Automatic download failed, please copy manually');
    }
    
    return sessionData;
})();
