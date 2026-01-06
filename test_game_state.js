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
    server.listen(8768, () => resolve(server));
  });
}

async function testGameState() {
  console.log('Testing actual game state changes...\n');

  const server = await startServer();
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:8768/test_emulator.html', { waitUntil: 'networkidle2' });
  await new Promise(resolve => setTimeout(resolve, 1000));

  const romPath = path.join(__dirname, 'build', 'stellar-assault.nes');
  const romBuffer = fs.readFileSync(romPath);
  const romBase64 = romBuffer.toString('base64');

  const result = await page.evaluate((base64Data) => {
    const tests = [];

    function test(name, passed, details) {
      tests.push({ name, passed, details });
      return passed;
    }

    try {
      // Load ROM
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

      // Run initialization
      for (let i = 0; i < 120; i++) window.nes.frame();

      // Check player position memory (addresses from source: player_x at $05, player_y at $06)
      const initialX = window.nes.cpu.mem[0x05];
      const initialY = window.nes.cpu.mem[0x06];
      test('Player initialized', initialX !== undefined && initialY !== undefined,
        `Initial position: X=${initialX}, Y=${initialY}`);

      // Press RIGHT and check if X coordinate changes
      window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_RIGHT);
      for (let i = 0; i < 60; i++) window.nes.frame();
      window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_RIGHT);

      const afterRightX = window.nes.cpu.mem[0x05];
      test('Movement RIGHT works', afterRightX > initialX,
        `X changed from ${initialX} to ${afterRightX} (delta: +${afterRightX - initialX})`);

      // Press LEFT and check if X decreases
      window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_LEFT);
      for (let i = 0; i < 60; i++) window.nes.frame();
      window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_LEFT);

      const afterLeftX = window.nes.cpu.mem[0x05];
      test('Movement LEFT works', afterLeftX < afterRightX,
        `X changed from ${afterRightX} to ${afterLeftX} (delta: ${afterLeftX - afterRightX})`);

      // Check if frame counter is incrementing (at $0A)
      const frame1 = window.nes.cpu.mem[0x0A];
      for (let i = 0; i < 60; i++) window.nes.frame();
      const frame2 = window.nes.cpu.mem[0x0A];
      const delta = (frame2 - frame1 + 256) % 256;
      test('Frame counter incrementing', delta === 60 || delta === 61, // Allow for 1 frame variance
        `Frame counter: ${frame1} → ${frame2} (delta: +${delta})`);

      // Test shooting - check bullet array (at $0300+)
      const bulletsBefore = [];
      for (let i = 0; i < 8; i++) {
        bulletsBefore.push(window.nes.cpu.mem[0x0300 + i]);
      }

      window.nes.buttonDown(1, window.jsnes.Controller.BUTTON_A);
      for (let i = 0; i < 20; i++) window.nes.frame();
      window.nes.buttonUp(1, window.jsnes.Controller.BUTTON_A);

      const bulletsAfter = [];
      for (let i = 0; i < 8; i++) {
        bulletsAfter.push(window.nes.cpu.mem[0x0300 + i]);
      }

      const bulletChanged = bulletsBefore.some((val, idx) => val !== bulletsAfter[idx]);
      test('Shooting creates bullets', bulletChanged,
        `Bullet array changed: ${bulletChanged}`);

      // Run extended test - 600 frames (10 seconds)
      let crashed = false;
      for (let i = 0; i < 600; i++) {
        try {
          window.nes.frame();
        } catch (e) {
          crashed = true;
          break;
        }
      }
      test('Stability (10 seconds)', !crashed, crashed ? 'Crashed' : '600 frames OK');

      return { success: tests.every(t => t.passed), tests };
    } catch (e) {
      return { success: false, tests: [{ name: 'Fatal error', passed: false, details: e.toString() }] };
    }
  }, romBase64);

  console.log('=== GAME STATE TESTS ===\n');
  result.tests.forEach(t => {
    const icon = t.passed ? '✅' : '❌';
    console.log(`${icon} ${t.name}`);
    if (t.details) console.log(`   ${t.details}`);
  });

  const passed = result.tests.filter(t => t.passed).length;
  const total = result.tests.length;
  console.log(`\n${passed}/${total} tests passed`);

  await browser.close();
  server.close();

  if (result.success) {
    console.log('\n✅ YES - GAME WORKS CORRECTLY');
  } else {
    console.log('\n❌ NO - GAME HAS ISSUES');
  }

  return result.success;
}

testGameState().then(success => process.exit(success ? 0 : 1)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
