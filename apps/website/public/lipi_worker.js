// ==============================================================================
// 👑 LIPI SOVEREIGN WEBASSEMBLY BACKGROUND WORKER (lipi_worker.js)
// ⚡ Off-Thread Pure Client-Side Execution | 0% C | 0% Emscripten | 0% External Libs
// 🏛️ File: apps/website/public/lipi_worker.js
//
// WHY: WebAssembly programs in Lipi can perform computationally heavy tasks
//      (e.g., recursive algorithms, raymarching, linear algebra, compiler passes).
//      Running them on the browser main thread would block the UI event loop and
//      cause frame drops. This dedicated WebWorker runs all WASM computations
//      asynchronously off the main thread, streaming output tokens in real-time
//      and posting completion results with zero UI hitching.
// ==============================================================================

(function () {
  'use strict';

  // ── Universal Worker Global Scope Resolver ──────────────────────────────────
  // WHY: Determines the appropriate execution context whether running inside a
  //      browser DedicatedWorker ('self'), ServiceWorker, SharedWorker, or
  //      Node.js 'worker_threads' harness.
  const workerScope = typeof self !== 'undefined'
    ? self
    : (typeof globalThis !== 'undefined' ? globalThis : (typeof global !== 'undefined' ? global : this));

  // ── Node.js worker_threads Bridge ───────────────────────────────────────────
  let nodeParentPort = null;
  if (typeof process !== 'undefined' && process.versions && process.versions.node) {
    try {
      const wt = require('worker_threads');
      if (wt.parentPort) {
        nodeParentPort = wt.parentPort;
      }
    } catch (_) {
      // Not running in Node worker_threads, ignore
    }
  }

  // ── Universal Message Dispatcher ─────────────────────────────────────────────
  // WHY: Sends messages safely to the parent thread across all environments.
  function sendWorkerMessage(message) {
    if (nodeParentPort) {
      nodeParentPort.postMessage(message);
    } else if (typeof workerScope.postMessage === 'function') {
      workerScope.postMessage(message);
    }
  }

  // ── Import / Bind Lipi WASM Runner ──────────────────────────────────────────
  // WHY: We dynamically resolve or import the sovereign wasm_runner.js engine.
  //      In browser WebWorkers, importScripts synchronously loads wasm_runner.js.
  //      In Node.js worker_threads or test harnesses, it falls back to require().
  function ensureRunnerLoaded() {
    if (workerScope.LipiWasmRunner && typeof workerScope.LipiWasmRunner.runLipiWasm === 'function') {
      return workerScope.LipiWasmRunner;
    }

    if (typeof workerScope.importScripts === 'function') {
      try {
        workerScope.importScripts('wasm_runner.js');
      } catch (err) {
        try {
          workerScope.importScripts('/wasm_runner.js');
        } catch (innerErr) {
          console.warn('[LipiWorker] Failed to importScripts wasm_runner.js:', innerErr);
        }
      }
    } else if (typeof require === 'function') {
      try {
        const path = require('path');
        const runnerPath = path.resolve(__dirname, 'wasm_runner.js');
        workerScope.LipiWasmRunner = require(runnerPath);
      } catch (nodeErr) {
        console.warn('[LipiWorker Node] Failed to require wasm_runner.js:', nodeErr);
      }
    }

    return workerScope.LipiWasmRunner || null;
  }

  // ── Core Task Dispatcher ─────────────────────────────────────────────────────
  // WHY: Handles inbound messages from the parent thread, executes WebAssembly
  //      binaries, streams real-time stdout output, and posts results back.
  async function handleMessageEvent(event) {
    const data = (event && event.data) ? event.data : event;
    if (!data || typeof data !== 'object') {
      sendWorkerMessage({
        type: 'ERROR',
        error: 'Invalid message payload: expected an object'
      });
      return;
    }

    const messageType = data.type || (data.action === 'RUN_WASM' ? 'RUN_SOURCE' : (data.wasmBytes ? 'RUN' : 'UNKNOWN'));
    const msgId = data.id || null;

    // 1. Health Ping / Pong Protocol
    // WHY: Confirms worker responsiveness without initiating expensive execution.
    if (messageType === 'PING') {
      sendWorkerMessage({
        type: 'PONG',
        id: msgId,
        timestamp: Date.now()
      });
      return;
    }

    // 2. Reset Protocol
    // WHY: Acknowledges readiness state.
    if (messageType === 'RESET') {
      sendWorkerMessage({
        type: 'RESET_OK',
        id: msgId
      });
      return;
    }

    // 3. WebAssembly Binary Execution Protocol (RUN)
    // WHY: Directly executes compiled .wasm binary bytecode off the main thread.
    if (messageType === 'RUN') {
      const runner = ensureRunnerLoaded();
      if (!runner || typeof runner.runLipiWasm !== 'function') {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: 'LipiWasmRunner engine is not loaded in worker scope'
        });
        return;
      }

      const rawBytes = data.wasmBytes;
      if (!rawBytes) {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: 'Missing required parameter: wasmBytes'
        });
        return;
      }

      // Convert raw byte input to Uint8Array
      let binaryPayload = null;
      if (rawBytes instanceof Uint8Array) {
        binaryPayload = rawBytes;
      } else if (rawBytes instanceof ArrayBuffer) {
        binaryPayload = new Uint8Array(rawBytes);
      } else if (Array.isArray(rawBytes)) {
        binaryPayload = new Uint8Array(rawBytes);
      } else if (typeof Buffer !== 'undefined' && Buffer.isBuffer && Buffer.isBuffer(rawBytes)) {
        binaryPayload = new Uint8Array(rawBytes.buffer, rawBytes.byteOffset, rawBytes.byteLength);
      } else {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: 'Unsupported wasmBytes type: must be Uint8Array, ArrayBuffer, or Array of numbers'
        });
        return;
      }

      // Live streaming callback to relay stdout back to the caller
      const streamCallback = function (outputChunk) {
        sendWorkerMessage({
          type: 'OUTPUT',
          id: msgId,
          text: outputChunk
        });
      };

      const options = {
        entryPoint: data.entryPoint || null,
        args: Array.isArray(data.args) ? data.args : []
      };

      try {
        const runReport = await runner.runLipiWasm(binaryPayload, streamCallback, options);

        if (runReport.status === 'error') {
          sendWorkerMessage({
            type: 'ERROR',
            id: msgId,
            error: runReport.error,
            stack: runReport.stack || '',
            stats: {
              time_ms: runReport.time_ms,
              entryPoint: runReport.entryPoint,
              status: 'error'
            }
          });
        } else {
          sendWorkerMessage({
            type: 'DONE',
            id: msgId,
            result: runReport.result,
            stats: {
              time_ms: runReport.time_ms,
              entryPoint: runReport.entryPoint,
              outputCount: (runReport.output || []).length,
              status: 'ok'
            }
          });
        }
      } catch (err) {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: err && err.message ? err.message : String(err),
          stack: err && err.stack ? err.stack : ''
        });
      }
      return;
    }

    // 4. Source Code Execution Protocol (for backwards compatibility with playground)
    if (messageType === 'RUN_SOURCE' || messageType === 'RUN_WASM') {
      const runner = ensureRunnerLoaded();
      if (!runner || typeof runner.run !== 'function') {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: 'Lipi Virtual Silicon source runner not available'
        });
        return;
      }

      try {
        const sourceResult = await runner.run(data.code || '');
        sendWorkerMessage({
          type: 'WASM_RESULT',
          id: msgId,
          result: sourceResult
        });
      } catch (srcErr) {
        sendWorkerMessage({
          type: 'ERROR',
          id: msgId,
          error: srcErr && srcErr.message ? srcErr.message : String(srcErr)
        });
      }
      return;
    }

    // 5. Unknown Action Trap
    sendWorkerMessage({
      type: 'ERROR',
      id: msgId,
      error: `Unknown action type: '${messageType}'`
    });
  }

  // ── Attach Event Listeners ───────────────────────────────────────────────────
  if (nodeParentPort) {
    nodeParentPort.on('message', function (msg) {
      handleMessageEvent({ data: msg });
    });
  } else if (typeof workerScope.addEventListener === 'function') {
    workerScope.addEventListener('message', handleMessageEvent);
  } else if (typeof workerScope.onmessage !== 'undefined' || 'onmessage' in workerScope) {
    workerScope.onmessage = handleMessageEvent;
  }

  // Announce worker readiness
  sendWorkerMessage({ type: 'READY', timestamp: Date.now() });

})();
