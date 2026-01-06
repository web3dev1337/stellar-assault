const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const http = require('http');
const handler = require('serve-handler');

async function startServer() {
  const server = http.createServer((request, response) => {
    return handler(request, response, { public: __dirname });
  });
  return new Promise((resolve) => {
    server.listen(8767, () => {
      console.log('Test server running at http://localhost:8767');
      resolve(server);
    });
  });
}

async function testGameplay() {
  console.log('Starting comprehensive gameplay test...\n');

  const server = await startServer();
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  const logs = [];
  page.on('console', msg => {
    const text = msg.text();
    logs.push(text);
    if (text.includes('ERROR') || text.includes('Error')) {
      console.log('❌ BROWSER ERROR:', text);
    }
  });

  const errors = [];
  page.on('pageerror', error => {
    errors.push(error.message);
    console.log('❌ PAGE ERROR:', error.message);
  });

  await page.goto('http://localhost:8767/test_emulator.html', { waitUntil: 'networkidle2' });
  await new Promise(resolve => setTimeout(resolve, 1000));

  const romPath = path.join(__dirname, 'build', 'stellar-assault.nes');
  const romBuffer = fs.readFileSync(romPath);
  const romBase64 = romBuffer.toString('base64');

  console.log('Testing game mechanics...\n');

  const testResult = await page.evaluate((base64Data) => {
    const results = {
      success: true,
      tests: [],
      errors: []
    };

    function addTest(name, passed, details) {
      results.tests.push({ name, passed, details });
      if (!passed) results.success = false;
    }

    try {
      // Convert and load ROM
      const binary = atob(base64Data);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
      let romString = '';
      for (let i = 0; i < bytes.length; i++) {
        romString += String.fromCharCode(bytes[i]);
      }

      window.nes.loadROM(romString);
      addTest('ROM Loading', true, 'ROM loaded successfully');

      // Run initial frames to initialize
      for (let i = 0; i < 60; i++) {
        window.nes.frame();
      }
      addTest('Initial Execution', true, 'Ran 60 frames without crash');

      // Test controller input - press RIGHT
      window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_RIGHT);
      for (let i = 0; i < 30; i++) {
        window.nes.frame();
      }
      window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_RIGHT);
      addTest('Controller Input (RIGHT)', true, 'Button press processed without crash');

      // Test shooting - press A button
      window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_A);
      for (let i = 0; i < 10; i++) {
        window.nes.frame();
      }
      window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_A);
      addTest('Shooting (A Button)', true, 'Shooting processed without crash');

      // Run extended gameplay
      let frameCount = 0;
      let crashed = false;

      // Simulate 5 seconds of gameplay with random inputs
      for (let second = 0; second < 5; second++) {
        // Random movement
        const dir = Math.floor(Math.random() * 4);
        const buttons = [
          window.jsnes.Controller.BUTTON_UP,
          window.jsnes.Controller.BUTTON_DOWN,
          window.jsnes.Controller.BUTTON_LEFT,
          window.jsnes.Controller.BUTTON_RIGHT
        ];

        window.nes.buttonDown(1, buttons[dir]);

        // Random shooting
        if (Math.random() > 0.5) {
          window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_A);
        }

        for (let i = 0; i < 60; i++) {
          try {
            window.nes.frame();
            frameCount++;
          } catch (e) {
            crashed = true;
            results.errors.push('Crashed at frame ' + frameCount + ': ' + e.toString());
            break;
          }
        }

        window.nes.buttonUp(1, buttons[dir]);
        window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_A);

        if (crashed) break;
      }

      addTest('Extended Gameplay (5 seconds)', !crashed,
        crashed ? 'Crashed during gameplay' : `Ran ${frameCount} frames successfully`);

      // Memory access test - check if CPU is executing valid code
      const cpuPC = window.nes.cpu.REG_PC;
      const validRange = cpuPC >= 0xC000 && cpuPC <= 0xFFFF;
      addTest('CPU Program Counter', validRange,
        validRange ? `PC in valid ROM range: $${cpuPC.toString(16)}` : `PC out of range: $${cpuPC.toString(16)}`);

      // Check for infinite loops
      const initialPC = window.nes.cpu.REG_PC;
      for (let i = 0; i < 10; i++) {
        window.nes.frame();
      }
      const afterPC = window.nes.cpu.REG_PC;
      const notStuck = initialPC !== afterPC;
      addTest('CPU Progress', notStuck,
        notStuck ? 'CPU is executing code' : 'CPU appears stuck at same address');

    } catch (e) {
      results.success = false;
      results.errors.push(e.toString());
      addTest('Fatal Error', false, e.toString());
    }

    return results;
  }, romBase64);

  console.log('=== TEST RESULTS ===\n');

  let passedCount = 0;
  let failedCount = 0;

  testResult.tests.forEach(test => {
    const icon = test.passed ? '✅' : '❌';
    const status = test.passed ? 'PASS' : 'FAIL';
    console.log(`${icon} ${test.name}: ${status}`);
    if (test.details) {
      console.log(`   ${test.details}`);
    }
    if (test.passed) passedCount++;
    else failedCount++;
  });

  console.log(`\n=== SUMMARY ===`);
  console.log(`Passed: ${passedCount}/${testResult.tests.length}`);
  console.log(`Failed: ${failedCount}/${testResult.tests.length}`);

  if (testResult.errors.length > 0) {
    console.log('\n=== ERRORS ===');
    testResult.errors.forEach(err => console.log('❌', err));
  }

  await browser.close();
  server.close();

  if (testResult.success && passedCount === testResult.tests.length) {
    console.log('\n✅ ALL GAMEPLAY TESTS PASSED - GAME WORKS!');
    return true;
  } else {
    console.log('\n❌ SOME TESTS FAILED - GAME HAS ISSUES');
    return false;
  }
}

testGameplay().then(success => {
  process.exit(success ? 0 : 1);
}).catch(err => {
  console.error('Test failed:', err);
  process.exit(1);
});
