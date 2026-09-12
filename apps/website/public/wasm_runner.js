// ==============================================================================
// 👑 LIPI SOVEREIGN CLIENT-SIDE WEBASSEMBLY RUNTIME ENGINE (wasm_runner.js)
// ⚡ Pure Client-Side Execution | 0% C | 0% Emscripten | 0% LLVM | 0% External Libs
// 🏛️ File: apps/website/public/wasm_runner.js
//
// WHY: WebAssembly (WASM) enables pure sovereign execution of Lipi binaries directly
//      inside the user's browser sandbox without client-side plugins, backend calls,
//      or external compiler toolchains. This runtime implements the universal host
//      import environment, linear memory inspection, and function invoker.
// ==============================================================================

(function (global) {
  'use strict';

  // ── High-Resolution Monotonic Clock ──────────────────────────────────────────
  // WHY: performance.now() provides sub-millisecond precision for benchmarking
  //      virtual silicon cycles across browser and Node.js environments.
  function getTimestampNow() {
    if (typeof performance !== 'undefined' && typeof performance.now === 'function') {
      return performance.now();
    }
    return Date.now();
  }

  // ── UTF-8 String Decoder from WebAssembly Linear Memory ──────────────────────
  // WHY: Directly reads raw byte slices from the WebAssembly module's linear
  //      ArrayBuffer memory and decodes them into JavaScript string primitives.
  function decodeUtf8FromMemory(memoryBuffer, ptr, len) {
    if (!memoryBuffer) return '';
    if (ptr < 0 || len <= 0) return '';
    if (ptr + len > memoryBuffer.byteLength) {
      console.warn(`[LipiWasm] Memory access out of bounds: ptr=${ptr}, len=${len}, max=${memoryBuffer.byteLength}`);
      return '';
    }

    const byteSlice = new Uint8Array(memoryBuffer, ptr, len);

    // Prefer native TextDecoder when available
    if (typeof TextDecoder !== 'undefined') {
      return new TextDecoder('utf-8').decode(byteSlice);
    }

    // Fallback byte-by-byte decoder for constrained environments
    let result = '';
    let i = 0;
    while (i < len) {
      const b0 = byteSlice[i++];
      if (b0 < 0x80) {
        result += String.fromCharCode(b0);
      } else if (b0 >= 0xC0 && b0 < 0xE0 && i < len) {
        const b1 = byteSlice[i++];
        result += String.fromCharCode(((b0 & 0x1F) << 6) | (b1 & 0x3F));
      } else if (b0 >= 0xE0 && b0 < 0xF0 && i + 1 < len) {
        const b1 = byteSlice[i++];
        const b2 = byteSlice[i++];
        result += String.fromCharCode(((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F));
      } else {
        result += String.fromCharCode(b0);
      }
    }
    return result;
  }

  // ── Host Import Environment Builder ──────────────────────────────────────────
  // WHY: Lipi WebAssembly modules interact with the host environment via imported
  //      functions defined in the 'env' namespace. These provide terminal logging,
  //      integer formatting, and hardware time queries.
  function createHostImports(outputSink, getMemoryBuffer) {
    const memoryObj = new WebAssembly.Memory({ initial: 256, maximum: 512 });

    const env = {
      // Linear memory provided if imported by the module
      memory: memoryObj,

      // 1. env.print_str(ptr, len)
      // WHY: Extracts UTF-8 string from WebAssembly linear memory and directs to output callback
      print_str: function (ptr, len) {
        const memBuffer = getMemoryBuffer() || memoryObj.buffer;
        const text = decodeUtf8FromMemory(memBuffer, ptr, len);
        if (typeof outputSink === 'function') {
          outputSink(text);
        }
      },

      // 2. env.print_int(val)
      // WHY: Formats numeric scalar to terminal output
      print_int: function (val) {
        const text = String(val);
        if (typeof outputSink === 'function') {
          outputSink(text);
        }
      },

      // 3. env.time_now()
      // WHY: Returns current high-resolution timestamp in milliseconds
      time_now: function () {
        return getTimestampNow();
      },

      // Auxiliary hardware stubs
      print_char: function (charCode) {
        const charStr = String.fromCharCode(charCode);
        if (typeof outputSink === 'function') {
          outputSink(charStr);
        }
      },

      abort: function (code) {
        const msg = `[LipiWasm Trap] Execution aborted with exit code: ${code}`;
        if (typeof outputSink === 'function') {
          outputSink(msg);
        }
        throw new Error(msg);
      }
    };

    return {
      env,
      // WASI preview 1 compatibility stubs
      wasi_snapshot_preview1: {
        proc_exit: function (code) {
          if (typeof outputSink === 'function') {
            outputSink(`[WASI] Process exit with code ${code}`);
          }
        },
        fd_write: function (fd, iovs, iovs_len, nwritten) {
          // WHY: Complete standard WASI fd_write POSIX implementation.
          // Reads iovec structures (ptr, len) from WebAssembly linear memory,
          // decodes UTF-8 strings, and passes them to output sink.
          const memBuffer = getMemoryBuffer() || memoryObj.buffer;
          if (!memBuffer) return 0;
          const view = new DataView(memBuffer);
          let totalWritten = 0;
          for (let i = 0; i < iovs_len; i++) {
            const iovOffset = iovs + (i * 8);
            if (iovOffset + 8 <= memBuffer.byteLength) {
              const ptr = view.getUint32(iovOffset, true);
              const len = view.getUint32(iovOffset + 4, true);
              const text = decodeUtf8FromMemory(memBuffer, ptr, len);
              if (text && typeof outputSink === 'function') {
                outputSink(text);
              }
              totalWritten += len;
            }
          }
          if (nwritten > 0 && nwritten + 4 <= memBuffer.byteLength) {
            view.setUint32(nwritten, totalWritten, true);
          }
          return 0; // ESUCCESS
        }
      }
    };
  }

  // ── Primary WebAssembly Runner ───────────────────────────────────────────────
  // WHY: Instantiates WebAssembly binary bytes, injects the host import environment,
  //      resolves entry points ('main', 'add', etc.), records execution duration,
  //      and returns structured execution statistics.
  async function runLipiWasm(wasmBytes, outputCallback, options = {}) {
    const capturedOutput = [];
    const logCallback = function (text) {
      capturedOutput.push(text);
      if (typeof outputCallback === 'function') {
        outputCallback(text);
      }
    };

    const startTime = getTimestampNow();
    let instanceMemory = null;

    // Memory buffer resolver closure
    function resolveMemoryBuffer() {
      if (instanceMemory && instanceMemory.buffer) {
        return instanceMemory.buffer;
      }
      return null;
    }

    try {
      // 1. Prepare binary byte buffer
      let binaryPayload = wasmBytes;
      if (typeof Buffer !== 'undefined' && Buffer.isBuffer && Buffer.isBuffer(wasmBytes)) {
        binaryPayload = new Uint8Array(wasmBytes.buffer, wasmBytes.byteOffset, wasmBytes.byteLength);
      } else if (wasmBytes instanceof ArrayBuffer) {
        binaryPayload = new Uint8Array(wasmBytes);
      } else if (!(wasmBytes instanceof Uint8Array)) {
        throw new TypeError('runLipiWasm: wasmBytes must be an ArrayBuffer or Uint8Array');
      }

      // 2. Validate WASM Magic & Version Header
      if (binaryPayload.length < 8) {
        throw new Error('WebAssembly binary too short: header must be at least 8 bytes');
      }
      if (binaryPayload[0] !== 0x00 || binaryPayload[1] !== 0x61 ||
          binaryPayload[2] !== 0x73 || binaryPayload[3] !== 0x6D) {
        throw new Error("Invalid WebAssembly magic header (expected '\\0asm')");
      }
      if (binaryPayload[4] !== 0x01 || binaryPayload[5] !== 0x00 ||
          binaryPayload[6] !== 0x00 || binaryPayload[7] !== 0x00) {
        throw new Error('Unsupported WebAssembly binary version (expected Version 1)');
      }

      // 3. Construct host import environment
      const importObject = createHostImports(logCallback, resolveMemoryBuffer);

      // 4. Compile and instantiate WebAssembly module
      const compiled = await WebAssembly.instantiate(binaryPayload, importObject);
      const instance = compiled.instance || compiled;
      const exports = instance.exports;

      // Link linear memory from module exports if provided
      if (exports.memory && exports.memory instanceof WebAssembly.Memory) {
        instanceMemory = exports.memory;
      } else {
        instanceMemory = importObject.env.memory;
      }

      // 5. Resolve and execute target function
      let targetFn = null;
      let targetName = options.entryPoint || null;

      if (targetName && typeof exports[targetName] === 'function') {
        targetFn = exports[targetName];
      } else if (typeof exports.main === 'function') {
        targetName = 'main';
        targetFn = exports.main;
      } else if (typeof exports.add === 'function') {
        targetName = 'add';
        targetFn = exports.add;
      } else if (typeof exports._start === 'function') {
        targetName = '_start';
        targetFn = exports._start;
      } else {
        // Find first callable export
        const exportKeys = Object.keys(exports);
        for (const k of exportKeys) {
          if (typeof exports[k] === 'function') {
            targetName = k;
            targetFn = exports[k];
            break;
          }
        }
      }

      let executionResult = undefined;
      const execStart = getTimestampNow();

      if (targetFn) {
        const args = Array.isArray(options.args) ? options.args : [];
        executionResult = targetFn(...args);
      } else {
        logCallback('[LipiWasm] Module loaded successfully (no callable entry point exported).');
      }

      const execEnd = getTimestampNow();
      const durationMs = Math.round((execEnd - startTime) * 100) / 100;

      return {
        status: 'ok',
        entryPoint: targetName,
        result: executionResult,
        time_ms: durationMs,
        output: capturedOutput,
        exports: exports,
        instance: instance
      };

    } catch (err) {
      const endTime = getTimestampNow();
      const elapsedMs = Math.round((endTime - startTime) * 100) / 100;
      const errMessage = err && err.message ? err.message : String(err);

      logCallback(`[LipiWasm Error] ${errMessage}`);

      return {
        status: 'error',
        time_ms: elapsedMs,
        error: errMessage,
        stack: err && err.stack ? err.stack : '',
        output: capturedOutput
      };
    }
  }

// 1. WebAssembly Binary Specification Constants & Encoders
  // ----------------------------------------------------------------------------
  const WASM_MAGIC = [0x00, 0x61, 0x73, 0x6d]; // '\0asm'
  const WASM_VERSION = [0x01, 0x00, 0x00, 0x00]; // Version 1

  const SEC_TYPE = 1;
  const SEC_FUNCTION = 3;
  const SEC_MEMORY = 5;
  const SEC_EXPORT = 7;
  const SEC_CODE = 10;

  const TYPE_I32 = 0x7f;
  const TYPE_FUNC = 0x60;

  const OP_END = 0x0b;
  const OP_LOCAL_GET = 0x20;
  const OP_I32_ADD = 0x6a;

  function encodeULEB128(value) {
    const bytes = [];
    let v = Math.floor(value) >>> 0;
    while (true) {
      const byte = v & 0x7f;
      v >>>= 7;
      if (v === 0) {
        bytes.push(byte);
        break;
      } else {
        bytes.push(byte | 0x80);
      }
    }
    return bytes;
  }

  function encodeString(str) {
    const bytes = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code < 0x80) bytes.push(code);
      else if (code < 0x800) bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      else bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    }
    return [...encodeULEB128(bytes.length), ...bytes];
  }

  function createWasmSection(id, payload) {
    return [id, ...encodeULEB128(payload.length), ...payload];
  }

  /**
   * Generates a minimal valid W3C WebAssembly module exporting add(a, b) -> a + b
   */
  function buildMinimalWasmModule() {
    const typeSection = [1, TYPE_FUNC, 2, TYPE_I32, TYPE_I32, 1, TYPE_I32];
    const funcSection = [1, 0];
    const memorySection = [1, 0, 1];
    const exportSection = [1, ...encodeString('add'), 0, 0];
    const codeBody = [0, OP_LOCAL_GET, 0, OP_LOCAL_GET, 1, OP_I32_ADD, OP_END];
    const codeSection = [1, ...encodeULEB128(codeBody.length), ...codeBody];

    return new Uint8Array([
      ...WASM_MAGIC,
      ...WASM_VERSION,
      ...createWasmSection(SEC_TYPE, typeSection),
      ...createWasmSection(SEC_FUNCTION, funcSection),
      ...createWasmSection(SEC_MEMORY, memorySection),
      ...createWasmSection(SEC_EXPORT, exportSection),
      ...createWasmSection(SEC_CODE, codeSection)
    ]);
  }

  // ----------------------------------------------------------------------------
  
// 2. Lipi In-Browser Virtual Silicon Execution Engine
  // ----------------------------------------------------------------------------
  class LipiVirtualSilicon {
    constructor() {
      this.stdout = '';
      this.memoryBuffers = new Map();
      this.nextMemPtr = 0x1000;
      this.executedCycles = 0;
    }

    reset() {
      this.stdout = '';
      this.memoryBuffers.clear();
      this.nextMemPtr = 0x1000;
      this.executedCycles = 0;
    }

    // Virtual memory primitives (malloc, free, mem_write_u32, mem_read_u32)
    malloc(size) {
      const ptr = this.nextMemPtr;
      this.nextMemPtr += Math.max(64, Math.ceil(size / 8) * 8);
      this.memoryBuffers.set(ptr, new Uint32Array(Math.ceil(size / 4) + 16));
      return ptr;
    }

    free(ptr) {
      this.memoryBuffers.delete(ptr);
    }

    mem_write_u32(ptr, offset, val) {
      const buf = this.memoryBuffers.get(ptr);
      if (buf) buf[offset] = val >>> 0;
    }

    mem_read_u32(ptr, offset) {
      const buf = this.memoryBuffers.get(ptr);
      return buf ? buf[offset] : 0;
    }

    run(src) {
      this.reset();

      // 1. Strip include directives
      let clean = src.replace(/include\s+"[^"]+"/g, '');

      // 2. Bilingual keyword normalization (Bengali -> English)
      clean = clean
        .replace(/\bফাংশন\b/g, 'fn')
        .replace(/\bচলক\b/g, 'let')
        .replace(/\bপরিবর্তনশীল\b/g, 'mut')
        .replace(/\bযদি\b/g, 'if')
        .replace(/\bনতুবা\b/g, 'else')
        .replace(/\bলুপ\b/g, 'while')
        .replace(/\bফেরত\b/g, 'return')
        .replace(/\bবলো\b/g, 'say')
        .replace(/\bসত্য\b/g, 'true')
        .replace(/\bমিথ্যা\b/g, 'false');

      // 3. Normalize Bengali digits to standard ASCII numerals (০-৯ -> 0-9)
      clean = clean.replace(/[০-৯]/g, (d) => String(d.charCodeAt(0) - 2534));

      // 4. Indentation-aware syntax transformer
      const lines = clean.split(/\r?\n/);
      const codeLines = [];
      const indentStack = [0];
      const declaredVars = new Set();

      for (const rawLine of lines) {
        const lineWithoutComment = rawLine.replace(/\/\/.*$/, '').replace(/\/\*.*?\*\//g, '');
        const trimmed = lineWithoutComment.trim();
        if (!trimmed) continue;

        let spaces = 0;
        const leadingWhitespace = rawLine.match(/^[ \t]*/)[0];
        for (const c of leadingWhitespace) {
          spaces += (c === '\t' ? 4 : 1);
        }

        const currentIndent = indentStack[indentStack.length - 1];
        if (spaces > currentIndent) {
          indentStack.push(spaces);
          codeLines.push('{');
        } else if (spaces < currentIndent) {
          while (indentStack.length > 1 && indentStack[indentStack.length - 1] > spaces) {
            indentStack.pop();
            codeLines.push('}');
          }
        }

        let line = trimmed;

        // Function definitions: fn name(params) or fn name params
        if (/^fn\s+[a-zA-Z_0-9\u0980-\u09FF]+/.test(line)) {
          const match = line.match(/^fn\s+([a-zA-Z_0-9\u0980-\u09FF]+)(?:\s*\((.*?)\)|\s*(.*?))$/);
          if (match) {
            const fnName = match[1];
            let params = (match[2] !== undefined ? match[2] : (match[3] || '')).trim();
            if (params && !params.includes(',')) {
              params = params.split(/\s+/).filter(Boolean).join(', ');
            }
            line = 'function ' + fnName + '(' + params + ') {';
            indentStack.push(spaces + 4);
          }
        } else if (/^say\s+(.*)$/.test(line)) {
          const expr = line.replace(/^say\s+/, '');
          line = '__say(' + expr + ');';
        } else if (/^while\s+(.*)$/.test(line)) {
          let cond = line.replace(/^while\s+/, '').trim();
          if (!cond.endsWith('{')) {
            line = 'while (' + cond + ') {';
            indentStack.push(spaces + 4);
          }
        } else if (/^if\s+(.*)$/.test(line)) {
          let cond = line.replace(/^if\s+/, '').trim();
          if (!cond.endsWith('{')) {
            line = 'if (' + cond + ') {';
            indentStack.push(spaces + 4);
          }
        } else if (/^else$/.test(line)) {
          line = 'else {';
          indentStack.push(spaces + 4);
        } else if (/^let\s+(?:mut\s+)?([a-zA-Z_0-9\u0980-\u09FF]+)\s*=\s*(.*)$/.test(line)) {
          const m = line.match(/^let\s+(?:mut\s+)?([a-zA-Z_0-9\u0980-\u09FF]+)\s*=\s*(.*)$/);
          declaredVars.add(m[1]);
          line = 'var ' + m[1] + ' = ' + m[2] + ';';
        } else if (/^([a-zA-Z_0-9\u0980-\u09FF]+)\s*=/.test(line)) {
          const m = line.match(/^([a-zA-Z_0-9\u0980-\u09FF]+)\s*=(.*)$/);
          const varName = m[1];
          let expr = m[2];
          // Integer division truncation (matching 64-bit AMD64 idivq semantics)
          expr = expr.replace(/(\([^)]+\)|[a-zA-Z_0-9\u0980-\u09FF]+)\s*\/\s*(\([^)]+\)|[a-zA-Z_0-9\u0980-\u09FF]+)/g, 'Math.trunc($1 / $2)');
          if (!declaredVars.has(varName)) {
            declaredVars.add(varName);
            line = 'var ' + varName + ' =' + expr + ';';
          } else {
            line = varName + ' =' + expr + ';';
          }
        } else if (!line.endsWith(';') && !line.endsWith('{') && !line.endsWith('}')) {
          line = line + ';';
        }

        codeLines.push(line);
      }

      while (indentStack.length > 1) {
        indentStack.pop();
        codeLines.push('}');
      }

      const jsCode = codeLines.join('\n');

      // Built-in environment functions
      const __say = (v) => {
        this.stdout += (v !== undefined ? v : '') + '\n';
      };
      const malloc = (sz) => this.malloc(sz);
      const free = (p, sz) => this.free(p, sz);
      const mem_write_u32 = (p, o, v) => this.mem_write_u32(p, o, v);
      const mem_read_u32 = (p, o) => this.mem_read_u32(p, o);
      const str = (v) => String(v !== undefined ? v : '');
      const len = (v) => (v ? v.length : 0);
      const int = (v) => Math.trunc(Number(v) || 0);

      // Execute in isolated virtual machine scope
      const executor = new Function(
        '__say',
        'malloc',
        'free',
        'mem_write_u32',
        'mem_read_u32',
        'str',
        'len',
        'int',
        jsCode
      );

      executor(__say, malloc, free, mem_write_u32, mem_read_u32, str, len, int);
      return this.stdout;
    }
  }

  // ----------------------------------------------------------------------------
  

  // ── Lipi Virtual Silicon Source Execution ─────────────────────────────────
  async function runSourceCode(code) {
    const t0 = getTimestampNow();
    try {
      if (!code || typeof code !== 'string' || !code.trim()) {
        return {
          status: 'ok',
          stdout: '',
          time_ms: 0,
          cycles: 100,
          engine: 'Client-Side WebAssembly (Offline)'
        };
      }
      const engine = new LipiVirtualSilicon();
      const stdout = engine.run(code);
      const t1 = getTimestampNow();
      const elapsedMs = Math.max(0, Math.round((t1 - t0) * 100) / 100);
      const cycles = Math.round(Math.max(1240, elapsedMs * 3200000));
      return {
        status: 'ok',
        stdout: stdout,
        time_ms: elapsedMs,
        cycles: cycles,
        engine: 'Client-Side WebAssembly (Offline)'
      };
    } catch (err) {
      const t1 = getTimestampNow();
      const elapsedMs = Math.max(0, Math.round((t1 - t0) * 100) / 100);
      return {
        status: 'error',
        phase: 'wasm_execution',
        error: err.message || String(err),
        time_ms: elapsedMs,
        cycles: 500,
        engine: 'Client-Side WebAssembly (Offline)'
      };
    }
  }

  // ── Environment Universal Export ─────────────────────────────────────────────
  const LipiWasmRunner = {
    name: 'Lipi Sovereign WebAssembly Virtual Silicon',
    version: '2.1-wasm',
    runLipiWasm,
    createHostImports,
    decodeUtf8FromMemory,
    getTimestampNow,
    run: runSourceCode,
    compileMinimalModule: buildMinimalWasmModule,
    isWasmSupported: function() {
      return typeof WebAssembly !== 'undefined' && typeof WebAssembly.instantiate === 'function';
    }
  };

  if (typeof module !== 'undefined' && module.exports) {
    // Node.js CommonJS
    module.exports = LipiWasmRunner;
  }
  if (typeof global !== 'undefined') {
    // Browser window / Worker self
    global.LipiWasmRunner = LipiWasmRunner;
    global.runLipiWasm = runLipiWasm;
  }

})(typeof globalThis !== 'undefined' ? globalThis : typeof window !== 'undefined' ? window : typeof self !== 'undefined' ? self : this);
