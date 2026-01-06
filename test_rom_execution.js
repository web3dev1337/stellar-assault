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
    server.listen(8766, () => {
      console.log('Test server running at http://localhost:8766');
      resolve(server);
    });
  });
}

async function testROMExecution() {
  console.log('Starting ROM execution test...');

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
  await page.goto('http://localhost:8766/test_emulator.html', { waitUntil: 'networkidle2' });

  // Wait for emulator to be ready
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Read our ROM file
  const romPath = path.join(__dirname, 'build', 'stellar-assault.nes');
  const romBuffer = fs.readFileSync(romPath);
  const romBase64 = romBuffer.toString('base64');

  console.log(`ROM size: ${romBuffer.length} bytes`);

  // Try to load and run the ROM
  console.log('Loading ROM and running for 60 frames...');
  const result = await page.evaluate((base64Data) => {
    // Convert base64 to Uint8Array
    const binary = atob(base64Data);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }

    // Convert to string for JSNES
    let romString = '';
    for (let i = 0; i < bytes.length; i++) {
      romString += String.fromCharCode(bytes[i]);
    }

    // Load ROM
    try {
      window.nes.loadROM(romString);
    } catch (e) {
      return { success: false, error: e.toString(), frames: 0 };
    }

    // Run 60 frames (1 second at 60fps)
    let framesRun = 0;
    let crashed = false;
    let crashError = null;

    for (let i = 0; i < 60; i++) {
      try {
        window.nes.frame();
        framesRun++;
      } catch (e) {
        crashed = true;
        crashError = e.toString();
        break;
      }
    }

    if (crashed) {
      return {
        success: false,
        error: 'Crashed during execution: ' + crashError,
        frames: framesRun
      };
    }

    return {
      success: true,
      error: null,
      frames: framesRun
    };
  }, romBase64);

  console.log('\n=== RESULT ===');
  console.log('Success:', result.success);
  console.log('Frames executed:', result.frames);
  if (result.error) {
    console.log('Error:', result.error);
  }

  console.log('\n=== CONSOLE LOGS ===');
  logs.forEach(log => console.log(log));

  console.log('\n=== PAGE ERRORS ===');
  errors.forEach(err => console.log(err));

  await browser.close();
  server.close();

  return { result, logs, errors };
}

testROMExecution().then(({ result, logs, errors }) => {
  if (!result.success) {
    console.log('\n❌ ROM EXECUTION FAILED');
    console.log('Frames before crash:', result.frames);
    process.exit(1);
  } else if (result.frames < 60) {
    console.log('\n⚠️  ROM LOADED BUT DID NOT RUN FULL 60 FRAMES');
    console.log('Frames executed:', result.frames);
    process.exit(1);
  } else {
    console.log('\n✅ ROM EXECUTED SUCCESSFULLY FOR 60 FRAMES');
    process.exit(0);
  }
}).catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
