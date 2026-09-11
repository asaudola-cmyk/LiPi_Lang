// ==============================================================================
// 🧪 LIPI TEST SUITE: Client-Side WebAssembly Runner & Worker Verification
// ⚡ Tests apps/website/public/wasm_runner.js & apps/website/public/lipi_worker.js
// 🏛️ File: tests/test_wasm_runner.js
//
// WHY: Ensures the client-side JavaScript execution runtime and background WebWorker
//      correctly instantiate sovereign WebAssembly binaries emitted by Lipi, execute
//      all exported math/logic functions with bit-exact precision, provide safe UTF-8
//      linear memory inspection, and maintain responsive non-blocking background workers.
// ==============================================================================

const fs = require('fs');
const path = require('path');
const { Worker } = require('worker_threads');

const RUNNER_PATH = path.resolve(__dirname, '../apps/website/public/wasm_runner.js');
const WORKER_PATH = path.resolve(__dirname, '../apps/website/public/lipi_worker.js');
const WASM_PATH = '/tmp/test.wasm';

// Terminal formatting colors
const GREEN = '\x1b[32m';
const RED = '\x1b[31m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';

let passedTests = 0;
let totalTests = 0;

function assert(condition, message) {
  totalTests++;
  if (!condition) {
    console.error(`  ${RED}✖ FAILED: ${message}${RESET}`);
    process.exit(1);
  }
  passedTests++;
  console.log(`  ${GREEN}✔ PASS:${RESET} ${message}`);
}

async function runTests() {
  console.log(`${CYAN}╔════════════════════════════════════════════════════════════════════════╗${RESET}`);
  console.log(`${CYAN}║  🧪 LIPI CLIENT-SIDE WASM RUNNER & WORKER VERIFICATION SUITE           ║${RESET}`);
  console.log(`${CYAN}╚════════════════════════════════════════════════════════════════════════╝${RESET}\n`);

  // ────────────────────────────────────────────────────────────────────────────
  // [Phase 1]: Module Loading & Environment Invariants
  // ────────────────────────────────────────────────────────────────────────────
  console.log(`${CYAN}[Phase 1]: Loading Sovereign wasm_runner.js Engine...${RESET}`);
  assert(fs.existsSync(RUNNER_PATH), `wasm_runner.js exists at ${RUNNER_PATH}`);
  assert(fs.existsSync(WORKER_PATH), `lipi_worker.js exists at ${WORKER_PATH}`);

  const LipiWasmRunner = require(RUNNER_PATH);
  assert(typeof LipiWasmRunner.runLipiWasm === 'function', 'runLipiWasm function is exported');
  assert(typeof LipiWasmRunner.createHostImports === 'function', 'createHostImports function is exported');
  assert(typeof LipiWasmRunner.decodeUtf8FromMemory === 'function', 'decodeUtf8FromMemory function is exported');

  // ────────────────────────────────────────────────────────────────────────────
  // [Phase 2]: Host Imports & UTF-8 Memory Decoding Diagnostics
  // ────────────────────────────────────────────────────────────────────────────
  console.log(`\n${CYAN}[Phase 2]: Host Imports & Memory Inspection Diagnostics...${RESET}`);

  // Test UTF-8 memory decoder
  const testBuffer = new ArrayBuffer(64);
  const testBytes = new Uint8Array(testBuffer);
  // Encode ASCII "Lipi-2.0"
  const asciiStr = 'Lipi-2.0';
  for (let i = 0; i < asciiStr.length; i++) {
    testBytes[i] = asciiStr.charCodeAt(i);
  }
  const decodedAscii = LipiWasmRunner.decodeUtf8FromMemory(testBuffer, 0, asciiStr.length);
  assert(decodedAscii === asciiStr, `decodeUtf8FromMemory decodes ASCII: expected '${asciiStr}', got '${decodedAscii}'`);

  // Multi-byte UTF-8 test (Bengali "লিপি": 0xE0, 0xA6, 0xB2, 0xE0, 0xA6, 0xBF, 0xE0, 0xA6, 0xAA, 0xE0, 0xA6, 0xBF)
  const bengaliBytes = Buffer.from('লিপি');
  for (let i = 0; i < bengaliBytes.length; i++) {
    testBytes[16 + i] = bengaliBytes[i];
  }
  const decodedBengali = LipiWasmRunner.decodeUtf8FromMemory(testBuffer, 16, bengaliBytes.length);
  assert(decodedBengali === 'লিপি', `decodeUtf8FromMemory decodes multi-byte UTF-8 Bengali: expected 'লিপি', got '${decodedBengali}'`);

  // Out of bounds safety test
  const oobDecoded = LipiWasmRunner.decodeUtf8FromMemory(testBuffer, 60, 10);
  assert(oobDecoded === '', 'decodeUtf8FromMemory safely traps out-of-bounds pointers');

  // Test Host Imports: print_str and print_int
  const sinkLog = [];
  const dummySink = (t) => sinkLog.push(t);
  const hostImports = LipiWasmRunner.createHostImports(dummySink, () => testBuffer);
  assert(typeof hostImports.env.print_str === 'function', 'env.print_str is a function');
  assert(typeof hostImports.env.print_int === 'function', 'env.print_int is a function');
  assert(typeof hostImports.env.time_now === 'function', 'env.time_now is a function');

  hostImports.env.print_int(2026);
  assert(sinkLog.length === 1 && sinkLog[0] === '2026', 'env.print_int converts integer to string');

  hostImports.env.print_str(0, asciiStr.length);
  assert(sinkLog.length === 2 && sinkLog[1] === asciiStr, 'env.print_str extracts memory string');

  const ts = hostImports.env.time_now();
  assert(typeof ts === 'number' && ts > 0, `env.time_now returns positive monotonic timestamp (${ts})`);

  // ────────────────────────────────────────────────────────────────────────────
  // [Phase 3]: Direct Execution of Compiled Lipi WASM Binary
  // ────────────────────────────────────────────────────────────────────────────
  console.log(`\n${CYAN}[Phase 3]: Direct Execution of /tmp/test.wasm...${RESET}`);
  assert(fs.existsSync(WASM_PATH), `WASM binary exists at ${WASM_PATH}`);

  const wasmBytes = fs.readFileSync(WASM_PATH);
  assert(wasmBytes.length > 8, `WASM binary size (${wasmBytes.length} bytes) is valid`);

  // 1. Test add(10, 32)
  const addReport = await LipiWasmRunner.runLipiWasm(wasmBytes, null, { entryPoint: 'add', args: [10, 32] });
  assert(addReport.status === 'ok', "Execution of 'add' succeeded");
  assert(addReport.result === 42, `add(10, 32) returned bit-exact 42 (got ${addReport.result})`);

  // 2. Test sub(50, 8)
  const subReport = await LipiWasmRunner.runLipiWasm(wasmBytes, null, { entryPoint: 'sub', args: [50, 8] });
  assert(subReport.status === 'ok', "Execution of 'sub' succeeded");
  assert(subReport.result === 42, `sub(50, 8) returned bit-exact 42 (got ${subReport.result})`);

  // 3. Test mul(6, 7)
  const mulReport = await LipiWasmRunner.runLipiWasm(wasmBytes, null, { entryPoint: 'mul', args: [6, 7] });
  assert(mulReport.status === 'ok', "Execution of 'mul' succeeded");
  assert(mulReport.result === 42, `mul(6, 7) returned bit-exact 42 (got ${mulReport.result})`);

  // 4. Test div_s(84, 2)
  const divReport = await LipiWasmRunner.runLipiWasm(wasmBytes, null, { entryPoint: 'div_s', args: [84, 2] });
  assert(divReport.status === 'ok', "Execution of 'div_s' succeeded");
  assert(divReport.result === 42, `div_s(84, 2) returned bit-exact 42 (got ${divReport.result})`);

  // 5. Test fib(10) (recursive Fibonacci)
  const fibReport = await LipiWasmRunner.runLipiWasm(wasmBytes, null, { entryPoint: 'fib', args: [10] });
  assert(fibReport.status === 'ok', "Execution of 'fib' succeeded");
  assert(fibReport.result === 55, `fib(10) returned bit-exact 55 (got ${fibReport.result})`);

  // 6. Test default main() entry point
  const mainReport = await LipiWasmRunner.runLipiWasm(wasmBytes);
  assert(mainReport.status === 'ok', "Execution of default entry point 'main' succeeded");
  assert(mainReport.result === 42, `main() returned bit-exact 42 (got ${mainReport.result})`);
  assert(mainReport.time_ms >= 0, `Execution timing reported: ${mainReport.time_ms} ms`);

  // ────────────────────────────────────────────────────────────────────────────
  // [Phase 4]: Error Handling & Fault Injection Diagnostics
  // ────────────────────────────────────────────────────────────────────────────
  console.log(`\n${CYAN}[Phase 4]: Fault Injection & Malformed Bytecode Diagnostics...${RESET}`);

  // Test invalid magic header
  const corruptMagic = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]);
  const errReport1 = await LipiWasmRunner.runLipiWasm(corruptMagic);
  assert(errReport1.status === 'error', 'Runner properly rejects invalid magic bytes');
  assert(errReport1.error.includes("Invalid WebAssembly magic header"), `Error message accurate: ${errReport1.error}`);

  // Test truncated header
  const truncHeader = Buffer.from([0x00, 0x61, 0x73]);
  const errReport2 = await LipiWasmRunner.runLipiWasm(truncHeader);
  assert(errReport2.status === 'error', 'Runner properly rejects truncated byte buffers');

  // ────────────────────────────────────────────────────────────────────────────
  // [Phase 5]: Dedicated WebWorker Asynchronous Execution Validation
  // ────────────────────────────────────────────────────────────────────────────
  console.log(`\n${CYAN}[Phase 5]: Dedicated WebWorker Background Thread Execution...${RESET}`);

  await new Promise((resolve, reject) => {
    const worker = new Worker(WORKER_PATH);
    let pingReceived = false;
    let fibReceived = false;
    let addReceived = false;
    let errReceived = false;

    worker.on('error', (err) => {
      console.error('Worker thread runtime error:', err);
      reject(err);
    });

    worker.on('message', (msg) => {
      // 1. Initial READY announcement
      if (msg.type === 'READY') {
        // Send PING
        worker.postMessage({ type: 'PING', id: 'ping-100' });
      }

      // 2. PONG response
      else if (msg.type === 'PONG' && msg.id === 'ping-100') {
        pingReceived = true;
        assert(true, 'Worker successfully responded to PING with PONG');

        // Send RUN fib(10)
        worker.postMessage({
          type: 'RUN',
          id: 'fib-job',
          wasmBytes: wasmBytes,
          entryPoint: 'fib',
          args: [10]
        });
      }

      // 3. DONE for fib(10)
      else if (msg.type === 'DONE' && msg.id === 'fib-job') {
        fibReceived = true;
        assert(msg.result === 55, `Worker computed fib(10) = ${msg.result} (expected 55)`);
        assert(msg.stats.status === 'ok', 'Worker reported execution stats status ok');

        // Send RUN add(100, 200)
        worker.postMessage({
          type: 'RUN',
          id: 'add-job',
          wasmBytes: wasmBytes,
          entryPoint: 'add',
          args: [100, 200]
        });
      }

      // 4. DONE for add(100, 200)
      else if (msg.type === 'DONE' && msg.id === 'add-job') {
        addReceived = true;
        assert(msg.result === 300, `Worker computed add(100, 200) = ${msg.result} (expected 300)`);

        // Send invalid payload to test error protocol
        worker.postMessage({
          type: 'RUN',
          id: 'corrupt-job',
          wasmBytes: new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7])
        });
      }

      // 5. ERROR for corrupt job
      else if (msg.type === 'ERROR' && msg.id === 'corrupt-job') {
        errReceived = true;
        assert(true, `Worker caught error gracefully: ${msg.error}`);

        // Terminate worker cleanly
        worker.terminate().then(() => {
          assert(pingReceived && fibReceived && addReceived && errReceived, 'All worker lifecycle events completed successfully');
          resolve();
        });
      }
    });
  });

  console.log(`\n${CYAN}════════════════════════════════════════════════════════════════════════${RESET}`);
  console.log(`  ${GREEN}🎉 ALL CLIENT-SIDE WASM RUNNER & WORKER INVARIANTS PASS! (${passedTests}/${totalTests})${RESET}`);
  console.log(`${CYAN}════════════════════════════════════════════════════════════════════════${RESET}`);
}

runTests().catch((err) => {
  console.error(`${RED}Fatal Test Runner Exception:${RESET}`, err);
  process.exit(1);
});
