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
    server.listen(8770, () => resolve(server));
  });
}

async function testFullGameInit() {
  const server = await startServer();
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.goto('http://localhost:8770/test_emulator.html', { waitUntil: 'networkidle2' });
  await new Promise(resolve => setTimeout(resolve, 1000));

  const romPath = path.join(__dirname, 'build', 'stellar-assault.nes');
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

    // Check memory immediately after load (before any frames)
    const beforeFrames = {
      player_x: window.nes.cpu.mem[0x05],
      player_y: window.nes.cpu.mem[0x06],
      frame_counter: window.nes.cpu.mem[0x0A],
      nmi_ready: window.nes.cpu.mem[0x10],
      pc: window.nes.cpu.REG_PC
    };

    // Run 1 frame
    window.nes.frame();

    const after1Frame = {
      player_x: window.nes.cpu.mem[0x05],
      player_y: window.nes.cpu.mem[0x06],
      frame_counter: window.nes.cpu.mem[0x0A],
      nmi_ready: window.nes.cpu.mem[0x10],
      pc: window.nes.cpu.REG_PC
    };

    // Run 119 more frames (total 120)
    for (let i = 0; i < 119; i++) {
      window.nes.frame();
    }

    const after120Frames = {
      player_x: window.nes.cpu.mem[0x05],
      player_y: window.nes.cpu.mem[0x06],
      frame_counter: window.nes.cpu.mem[0x0A],
      nmi_ready: window.nes.cpu.mem[0x10],
      pc: window.nes.cpu.REG_PC
    };

    return { beforeFrames, after1Frame, after120Frames };
  }, romBase64);

  console.log('\n=== FULL GAME INITIALIZATION TEST ===\n');

  console.log('Before any frames:');
  console.log(`  player_x:       $${result.beforeFrames.player_x.toString(16).padStart(2, '0')} (${result.beforeFrames.player_x}) [expected: 0xFF or 0x00]`);
  console.log(`  player_y:       $${result.beforeFrames.player_y.toString(16).padStart(2, '0')} (${result.beforeFrames.player_y}) [expected: 0xFF or 0x00]`);
  console.log(`  frame_counter:  $${result.beforeFrames.frame_counter.toString(16).padStart(2, '0')} [expected: 0x00]`);
  console.log(`  PC:             $${result.beforeFrames.pc.toString(16).padStart(4, '0')}`);

  console.log('\nAfter 1 frame:');
  console.log(`  player_x:       $${result.after1Frame.player_x.toString(16).padStart(2, '0')} (${result.after1Frame.player_x}) [expected: 0x78 = 120]`);
  console.log(`  player_y:       $${result.after1Frame.player_y.toString(16).padStart(2, '0')} (${result.after1Frame.player_y}) [expected: 0xC8 = 200]`);
  console.log(`  frame_counter:  $${result.after1Frame.frame_counter.toString(16).padStart(2, '0')} [expected: 0x01]`);
  console.log(`  nmi_ready:      $${result.after1Frame.nmi_ready.toString(16).padStart(2, '0')}`);
  console.log(`  PC:             $${result.after1Frame.pc.toString(16).padStart(4, '0')}`);

  console.log('\nAfter 120 frames:');
  console.log(`  player_x:       $${result.after120Frames.player_x.toString(16).padStart(2, '0')} (${result.after120Frames.player_x})`);
  console.log(`  player_y:       $${result.after120Frames.player_y.toString(16).padStart(2, '0')} (${result.after120Frames.player_y})`);
  console.log(`  frame_counter:  $${result.after120Frames.frame_counter.toString(16).padStart(2, '0')} (${result.after120Frames.frame_counter})`);
  console.log(`  PC:             $${result.after120Frames.pc.toString(16).padStart(4, '0')}`);

  await browser.close();
  server.close();

  const initialized = result.after1Frame.player_x === 0x78 && result.after1Frame.player_y === 0xC8;
  const frameCounting = result.after120Frames.frame_counter > 0;

  console.log('\n=== VERDICT ===');
  if (initialized && frameCounting) {
    console.log('✅ YES - GAME INITIALIZED AND RUNNING');
    return true;
  } else if (initialized && !frameCounting) {
    console.log('⚠️  Game initialized but frame counter not incrementing');
    return false;
  } else {
    console.log('❌ NO - GAME NOT INITIALIZING PROPERLY');
    return false;
  }
}

testFullGameInit().then(success => process.exit(success ? 0 : 1)).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
