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
    server.listen(8769, () => resolve(server));
  });
}

async function testMinimalROM() {
  const server = await startServer();
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:8769/test_emulator.html', { waitUntil: 'networkidle2' });
  await new Promise(resolve => setTimeout(resolve, 1000));

  const romPath = path.join(__dirname, 'build', 'test_minimal.nes');
  const romBuffer = fs.readFileSync(romPath);
  const romBase64 = romBuffer.toString('base64');

  const result = await page.evaluate((base64Data) => {
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

    // Check initial state
    const initial = window.nes.cpu.mem[0x00];
    console.log('Initial value at $00:', initial);

    // Run 60 frames
    for (let i = 0; i < 60; i++) {
      window.nes.frame();
    }

    // Check after 60 frames
    const after = window.nes.cpu.mem[0x00];
    const value01 = window.nes.cpu.mem[0x01];

    console.log('After 60 frames:');
    console.log('  $00:', after);
    console.log('  $01:', value01);

    return {
      initial: initial,
      after: after,
      value01: value01,
      changed: after !== initial,
      correctInit: initial === 0x42 || initial === 0xFF, // Might be $FF before Reset runs
      pc: window.nes.cpu.REG_PC
    };
  }, romBase64);

  console.log('\n=== MINIMAL ROM TEST ===');
  console.log(`Initial $00: $${result.initial.toString(16).padStart(2, '0')}`);
  console.log(`After 60 frames $00: $${result.after.toString(16).padStart(2, '0')}`);
  console.log(`Value at $01: $${result.value01.toString(16).padStart(2, '0')}`);
  console.log(`PC: $${result.pc.toString(16).padStart(4, '0')}`);
  console.log(`Memory changed: ${result.changed ? 'YES ✅' : 'NO ❌'}`);

  await browser.close();
  server.close();

  // Check if $01 has the expected value ($99) and $00 changed from initial value
  const executing = result.value01 === 0x99 && result.changed;

  if (executing) {
    console.log('\n✅ YES - CPU IS EXECUTING CODE!');
    console.log(`Memory at $00 incremented ${(result.after - result.initial + 256) % 256} times`);
    return true;
  } else {
    console.log('\n❌ NO - CPU IS NOT EXECUTING PROPERLY');
    return false;
  }
}

testMinimalROM().then(success => process.exit(success ? 0 : 1)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
