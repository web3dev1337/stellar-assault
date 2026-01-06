const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const http = require('http');
const handler = require('serve-handler');

async function startServer() {
  const server = http.createServer((request, response) => {
    return handler(request, response, {
      public: __dirname
    });
  });

  return new Promise((resolve) => {
    server.listen(8765, () => {
      console.log('Test server running at http://localhost:8765');
      resolve(server);
    });
  });
}

async function testROM() {
  console.log('Starting ROM test...');

  const server = await startServer();

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  // Capture console messages
  const logs = [];
  page.on('console', msg => {
    const text = msg.text();
    logs.push(text);
    console.log('BROWSER:', text);
  });

  // Capture errors
  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.message);
    console.log('ERROR:', error.message);
  });

  // Load our test page
  console.log('Loading emulator page...');
  await page.goto('http://localhost:8765/test_emulator.html', { waitUntil: 'networkidle2' });

  // Wait for emulator to be ready
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Read our ROM file
  const romPath = path.join(__dirname, 'build', 'stellar-assault.nes');
  const romBuffer = fs.readFileSync(romPath);
  const romBase64 = romBuffer.toString('base64');

  console.log(`ROM size: ${romBuffer.length} bytes`);

  // Try to load the ROM
  console.log('Loading ROM into emulator...');
  const result = await page.evaluate((base64Data) => {
    // Convert base64 to Uint8Array
    const binary = atob(base64Data);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }

    // Load ROM using our test function
    return window.loadROMFromBytes(bytes);
  }, romBase64);

  console.log('\n=== RESULT ===');
  console.log('Success:', result.success);
  if (result.errors && result.errors.length > 0) {
    console.log('Errors:', result.errors);
  }

  console.log('\n=== CONSOLE LOGS ===');
  logs.forEach(log => console.log(log));

  console.log('\n=== PAGE ERRORS ===');
  errors.forEach(err => console.log(err));

  await browser.close();
  server.close();

  return { result, logs, errors };
}

testROM().then(({ result, logs, errors }) => {
  if (!result.success) {
    console.log('\n❌ ROM FAILED TO LOAD');
    process.exit(1);
  } else {
    console.log('\n✅ ROM LOADED SUCCESSFULLY');
    process.exit(0);
  }
}).catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
