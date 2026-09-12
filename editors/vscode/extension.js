// ==============================================================================
// 👑 LIPI LANGUAGE VS CODE EXTENSION (editors/vscode/extension.js)
// ⚡ High-Performance Bilingual LSP Client & Language Feature Engine
// 100% Zero-Dependency Pure Node.js Implementation
// ==============================================================================

'use strict';

const vscode = require('vscode');
const cp = require('child_process');
const path = require('path');
const fs = require('fs');

// ─── Bilingual Built-in Knowledge Base ────────────────────────────────────────
// WHY: Immediate offline fallback ensuring documentation & autocomplete even
// when the native lipilsp binary is recompiling or running in headless containers.

const BILINGUAL_DOCS = {
  // Bengali Keywords
  'কাজ': { kind: 'Keyword', syntax: 'কাজ নাম(প্যারাম):', desc: 'ফাংশন সংজ্ঞা (Function Definition)। ব্লকের কোড এক্সিকিউট করে।' },
  'যদি': { kind: 'Keyword', syntax: 'যদি শর্ত:', desc: 'শর্তমূলক স্টেটমেন্ট (If condition)। শর্ত সত্য হলে ভেতরের কোড চলে।' },
  'নাহলে_যদি': { kind: 'Keyword', syntax: 'নাহলে_যদি শর্ত:', desc: 'বিকল্প শর্ত (Else-if branch)।' },
  'নাহলে': { kind: 'Keyword', syntax: 'নাহলে:', desc: 'অন্যথায় বিকল্প ব্লক (Else branch)।' },
  'যতক্ষণ': { kind: 'Keyword', syntax: 'যতক্ষণ শর্ত:', desc: 'লুপ স্টেটমেন্ট (While loop)। শর্ত সত্য থাকা পর্যন্ত চলে।' },
  'গঠন': { kind: 'Keyword', syntax: 'গঠন নাম:', desc: 'ইউজার-ডিফাইন্ড ডাটা স্ট্রাকচার (Struct Definition)।' },
  'ফেরত': { kind: 'Keyword', syntax: 'ফেরত মান', desc: 'ফাংশন থেকে মান রিটার্ন করে (Return value)।' },
  'বলো': { kind: 'Keyword', syntax: 'বলো মান', desc: 'কনসোলে টেক্সট বা সংখ্যার আউটপুট প্রদর্শন করে (Print stdout)।' },
  'মেমরি_বরাদ্দ': { kind: 'Function', syntax: 'মেমরি_বরাদ্দ(বাইট)', desc: 'সরাসরি র হিপ মেমরি বরাদ্দ করে (sys_mmap / malloc)।' },
  'মেমরি_মুক্তি': { kind: 'Function', syntax: 'মেমরি_মুক্তি(ঠিকানা, বাইট)', desc: 'বরাদ্দকৃত হিপ মেমরি মুক্ত করে (free)।' },

  // English Keywords
  'fn': { kind: 'Keyword', syntax: 'fn name param:', desc: 'Function definition in Lipi English syntax.' },
  'if': { kind: 'Keyword', syntax: 'if condition:', desc: 'Conditional branching statement.' },
  'elif': { kind: 'Keyword', syntax: 'elif condition:', desc: 'Alternative conditional branch.' },
  'else': { kind: 'Keyword', syntax: 'else:', desc: 'Fallback default branch.' },
  'while': { kind: 'Keyword', syntax: 'while condition:', desc: 'Repeated execution loop while condition is true.' },
  'struct': { kind: 'Keyword', syntax: 'struct Name:', desc: 'Composite user-defined data type.' },
  'return': { kind: 'Keyword', syntax: 'return value', desc: 'Exits function and returns an evaluated expression.' },
  'say': { kind: 'Keyword', syntax: 'say value', desc: 'Outputs text or expression value to standard output.' },
  'malloc': { kind: 'Function', syntax: 'malloc(bytes)', desc: 'Allocates raw heap memory via zero-libc direct kernel syscall.' },
  'free': { kind: 'Function', syntax: 'free(addr, bytes)', desc: 'Releases previously allocated heap buffer.' },

  // Directive (@) Syntax
  '@fn': { kind: 'Keyword', syntax: '@fn name(args) ... @end', desc: 'Directive-style function definition.' },
  '@if': { kind: 'Keyword', syntax: '@if condition ... @end', desc: 'Directive-style conditional statement.' },
  '@elif': { kind: 'Keyword', syntax: '@elif condition', desc: 'Directive-style alternative condition.' },
  '@else': { kind: 'Keyword', syntax: '@else', desc: 'Directive-style fallback branch.' },
  '@while': { kind: 'Keyword', syntax: '@while condition ... @end', desc: 'Directive-style while loop.' },
  '@struct': { kind: 'Keyword', syntax: '@struct Name ... @end', desc: 'Directive-style composite struct declaration.' },
  '@end': { kind: 'Keyword', syntax: '@end', desc: 'Closes a directive block (@fn, @if, @while, @struct).' },
  '@let': { kind: 'Keyword', syntax: '@let var = expr', desc: 'Explicit variable declaration directive.' },

  // Standard Library Gateways
  'universe/web': { kind: 'Module', syntax: 'import "universe/web"', desc: 'High-throughput HTTP/1.1, HTTP/2, and REST microservices.' },
  'universe/db': { kind: 'Module', syntax: 'import "universe/db"', desc: 'LipiKV, ACID WAL storage engine, and Raft distributed consensus.' },
  'universe/ai': { kind: 'Module', syntax: 'import "universe/ai"', desc: 'SIMD AMX/AVX2 matrix multiplication and GGUF tensor inference.' },
  'universe/crypto': { kind: 'Module', syntax: 'import "universe/crypto"', desc: 'RFC 8446 TLS 1.3, SHA-256, Ed25519, and AES-GCM cryptography.' },
  'universe/net': { kind: 'Module', syntax: 'import "universe/net"', desc: 'Raw Linux TCP/UDP socket stack and WebSocket framing.' },
  'universe/gui': { kind: 'Module', syntax: 'import "universe/gui"', desc: 'Direct framebuffer linear rasterizer and 2D canvas.' },
  'universe/os': { kind: 'Module', syntax: 'import "universe/os"', desc: 'Bare-metal Ring-0 unikernel, IDT interrupts, and Multiboot headers.' }
};

// ─── Native Lipi LSP Client ───────────────────────────────────────────────────
// WHY: Communicates with bin/lipilsp over standard input/output using JSON-RPC 2.0
// framed by Content-Length headers.
class LipiLspClient {
  constructor(lspPath, workspaceRoot) {
    this.lspPath = lspPath;
    this.workspaceRoot = workspaceRoot;
    this.process = null;
    this.nextId = 1;
    this.pendingRequests = new Map();
    this.buffer = '';
    this.isReady = false;
  }

  start() {
    if (!fs.existsSync(this.lspPath)) {
      console.log(`[LipiLsp] Server binary not found at ${this.lspPath}. Using built-in language engine.`);
      return false;
    }

    try {
      this.process = cp.spawn(this.lspPath, [], {
        cwd: this.workspaceRoot,
        stdio: ['pipe', 'pipe', 'pipe']
      });

      this.process.stdout.on('data', (chunk) => this._onData(chunk));
      this.process.stderr.on('data', (chunk) => {
        console.error(`[LipiLsp stderr] ${chunk.toString().trim()}`);
      });

      this.process.on('error', (err) => {
        console.error('[LipiLsp] Failed to start LSP process:', err);
        this.process = null;
      });

      this.process.on('close', (code) => {
        console.log(`[LipiLsp] Process exited with code ${code}`);
        this.process = null;
        this.isReady = false;
      });

      // Send initialize request
      this.sendRequest('initialize', {
        processId: process.pid,
        rootUri: `file://${this.workspaceRoot}`,
        capabilities: {
          textDocument: {
            hover: { dynamicRegistration: true },
            completion: { dynamicRegistration: true },
            formatting: { dynamicRegistration: true }
          }
        }
      }).then(() => {
        this.isReady = true;
        this.sendNotification('initialized', {});
        console.log('[LipiLsp] Server initialized successfully.');
      }).catch((err) => {
        console.error('[LipiLsp] Initialization failed:', err);
      });

      return true;
    } catch (e) {
      console.error('[LipiLsp] Spawn exception:', e);
      return false;
    }
  }

  stop() {
    if (this.process) {
      try {
        this.process.kill();
      } catch (e) {}
      this.process = null;
      this.isReady = false;
    }
  }

  sendRequest(method, params) {
    return new Promise((resolve, reject) => {
      if (!this.process || !this.process.stdin.writable) {
        return reject(new Error('LSP process not available'));
      }

      const id = this.nextId++;
      const msgObj = { jsonrpc: '2.0', id, method, params };
      const body = JSON.stringify(msgObj);
      const header = `Content-Length: ${Buffer.byteLength(body, 'utf8')}\r\n\r\n`;

      this.pendingRequests.set(id, { resolve, reject });
      this.process.stdin.write(header + body);

      // Timeout after 3 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`LSP Request ${method} timed out`));
        }
      }, 3000);
    });
  }

  sendNotification(method, params) {
    if (!this.process || !this.process.stdin.writable) return;
    const msgObj = { jsonrpc: '2.0', method, params };
    const body = JSON.stringify(msgObj);
    const header = `Content-Length: ${Buffer.byteLength(body, 'utf8')}\r\n\r\n`;
    this.process.stdin.write(header + body);
  }

  _onData(chunk) {
    this.buffer += chunk.toString('utf8');

    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd === -1) break;

      const headerText = this.buffer.substring(0, headerEnd);
      const match = headerText.match(/Content-Length:\s*(\d+)/i);
      if (!match) {
        this.buffer = this.buffer.substring(headerEnd + 4);
        continue;
      }

      const contentLength = parseInt(match[1], 10);
      const bodyStart = headerEnd + 4;
      if (this.buffer.length < bodyStart + contentLength) {
        // Incomplete body, wait for next chunk
        break;
      }

      const bodyText = this.buffer.substring(bodyStart, bodyStart + contentLength);
      this.buffer = this.buffer.substring(bodyStart + contentLength);

      try {
        const json = JSON.parse(bodyText);
        if (json.id && this.pendingRequests.has(json.id)) {
          const { resolve, reject } = this.pendingRequests.get(json.id);
          this.pendingRequests.delete(json.id);
          if (json.error) {
            reject(new Error(json.error.message || 'LSP Error'));
          } else {
            resolve(json.result);
          }
        }
      } catch (err) {
        console.error('[LipiLsp] Failed to parse JSON-RPC response:', err);
      }
    }
  }
}

// ─── Resolve Lipi Binary Path ─────────────────────────────────────────────────
function resolveLspBinary(workspaceRoot) {
  const candidates = [
    path.join(workspaceRoot, 'bin', 'lipilsp'),
    path.join(process.env.HOME || '', '.lipi', 'bin', 'lipilsp'),
    '/usr/local/bin/lipilsp',
    '/usr/bin/lipilsp'
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return path.join(workspaceRoot, 'bin', 'lipilsp');
}

// ─── Extension Activation ─────────────────────────────────────────────────────
let lspClient = null;
let diagnosticCollection = null;

function activate(context) {
  console.log('👑 Lipi Sovereign Programming Language extension activating...');

  const workspaceRoot = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
    ? vscode.workspace.workspaceFolders[0].uri.fsPath
    : process.cwd();

  const config = vscode.workspace.getConfiguration('lipi');
  const lspPath = resolveLspBinary(workspaceRoot);

  diagnosticCollection = vscode.languages.createDiagnosticCollection('lipi');
  context.subscriptions.push(diagnosticCollection);

  if (config.get('lsp.enabled', true)) {
    lspClient = new LipiLspClient(lspPath, workspaceRoot);
    lspClient.start();
  }

  // 1. Hover Documentation Provider
  context.subscriptions.push(
    vscode.languages.registerHoverProvider('lipi', {
      async provideHover(document, position) {
        const wordRange = document.getWordRangeAtPosition(position, /[@]?[a-zA-Z0-9_\u0980-\u09FF\/\.]+/);
        if (!wordRange) return null;
        const word = document.getText(wordRange);

        // Try querying live LSP first
        if (lspClient && lspClient.isReady) {
          try {
            const res = await lspClient.sendRequest('textDocument/hover', {
              textDocument: { uri: document.uri.toString() },
              position: { line: position.line, character: position.character }
            });
            if (res && res.contents) {
              const value = typeof res.contents === 'string' ? res.contents : res.contents.value;
              return new vscode.Hover(new vscode.MarkdownString(value));
            }
          } catch (e) {}
        }

        // Fallback to built-in knowledge base
        if (BILINGUAL_DOCS[word]) {
          const item = BILINGUAL_DOCS[word];
          const md = new vscode.MarkdownString();
          md.appendCodeblock(item.syntax, 'lipi');
          md.appendMarkdown(`**${item.kind}** — ${item.desc}\n\n*Lipi Sovereign 2.0*`);
          return new vscode.Hover(md);
        }

        return null;
      }
    })
  );

  // 2. Autocomplete Completion Item Provider
  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider('lipi', {
      async provideCompletionItems(document, position) {
        const items = [];

        // Try querying live LSP
        if (lspClient && lspClient.isReady) {
          try {
            const res = await lspClient.sendRequest('textDocument/completion', {
              textDocument: { uri: document.uri.toString() },
              position: { line: position.line, character: position.character }
            });
            if (res && Array.isArray(res.items)) {
              return res.items.map(it => {
                const ci = new vscode.CompletionItem(it.label);
                ci.detail = it.detail;
                ci.documentation = new vscode.MarkdownString(it.documentation || '');
                return ci;
              });
            }
          } catch (e) {}
        }

        // Populate from bilingual knowledge base
        for (const [key, val] of Object.entries(BILINGUAL_DOCS)) {
          const item = new vscode.CompletionItem(key);
          item.detail = val.syntax;
          item.documentation = new vscode.MarkdownString(val.desc);
          if (val.kind === 'Keyword') {
            item.kind = vscode.CompletionItemKind.Keyword;
          } else if (val.kind === 'Function') {
            item.kind = vscode.CompletionItemKind.Function;
          } else if (val.kind === 'Module') {
            item.kind = vscode.CompletionItemKind.Module;
          } else {
            item.kind = vscode.CompletionItemKind.Property;
          }
          items.push(item);
        }

        return items;
      }
    }, '.', '@', '/', '"')
  );

  // 3. Document Formatting Provider
  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider('lipi', {
      provideDocumentFormattingEdits(document) {
        const edits = [];
        const fmtPath = path.join(workspaceRoot, 'bin', 'lipifmt');
        
        // If lipifmt is available, use canonical indentation
        const text = document.getText();
        const lines = text.split('\n');
        let indentLevel = 0;
        const formatted = [];

        for (let i = 0; i < lines.length; i++) {
          let line = lines[i].trim();
          if (line.length === 0) {
            formatted.push('');
            continue;
          }

          // Dedent before line if closing block
          if (line.startsWith('@end') || line.startsWith('end') || line.startsWith('নাহলে') || line.startsWith('else') || line.startsWith('elif')) {
            indentLevel = Math.max(0, indentLevel - 1);
          }

          formatted.push('  '.repeat(indentLevel) + line);

          // Indent after opening block
          if (line.startsWith('@fn') || line.startsWith('@if') || line.startsWith('@while') || line.startsWith('@struct') ||
              line.startsWith('কাজ ') || line.startsWith('যদি ') || line.startsWith('যতক্ষণ ') || line.startsWith('গঠন ') ||
              line.startsWith('fn ') || line.startsWith('if ') || line.startsWith('while ') || line.startsWith('struct ') ||
              line.startsWith('নাহলে:') || line.startsWith('else:') || line.startsWith('elif ') || line.endsWith(':')) {
            indentLevel++;
          }
        }

        const fullRange = new vscode.Range(
          document.positionAt(0),
          document.positionAt(text.length)
        );
        edits.push(vscode.TextEdit.replace(fullRange, formatted.join('\n')));
        return edits;
      }
    })
  );

  // 4. Real-time Syntax Diagnostic Linter
  function validateDocument(document) {
    if (document.languageId !== 'lipi') return;
    const diagnostics = [];
    const text = document.getText();
    const lines = text.split('\n');

    let directiveStack = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('//') || line.startsWith('@!')) continue;

      if (line.startsWith('@fn') || line.startsWith('@if') || line.startsWith('@while') || line.startsWith('@struct')) {
        directiveStack.push({ line: i, tag: line.split(' ')[0] });
      } else if (line.startsWith('@end')) {
        if (directiveStack.length === 0) {
          const range = new vscode.Range(i, 0, i, line.length);
          diagnostics.push(new vscode.Diagnostic(range, 'অপ্রত্যাশিত @end: কোনো উন্মুক্ত ব্লক খুঁজে পাওয়া যায়নি', vscode.DiagnosticSeverity.Error));
        } else {
          directiveStack.pop();
        }
      }
    }

    // Report unclosed blocks
    for (const openBlock of directiveStack) {
      const range = new vscode.Range(openBlock.line, 0, openBlock.line, lines[openBlock.line].length);
      diagnostics.push(new vscode.Diagnostic(range, `অনাবৃত ${openBlock.tag} ব্লক: সমাপ্তির জন্য @end প্রয়োজন`, vscode.DiagnosticSeverity.Error));
    }

    diagnosticCollection.set(document.uri, diagnostics);
  }

  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validateDocument));
  context.subscriptions.push(vscode.workspace.onDidChangeTextDocument(e => validateDocument(e.document)));
  context.subscriptions.push(vscode.workspace.onDidCloseTextDocument(doc => diagnosticCollection.delete(doc.uri)));

  // Validate already open documents
  vscode.workspace.textDocuments.forEach(validateDocument);

  // 5. Command Handlers
  context.subscriptions.push(
    vscode.commands.registerCommand('lipi.restartLsp', () => {
      if (lspClient) lspClient.stop();
      lspClient = new LipiLspClient(lspPath, workspaceRoot);
      const ok = lspClient.start();
      vscode.window.showInformationMessage(ok ? 'Lipi Language Server restarted.' : 'Using built-in Lipi language engine.');
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('lipi.runFile', () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('কোনো সক্রিয় লিপি ফাইল উন্মুক্ত নেই।');
        return;
      }
      const filePath = editor.document.fileName;
      const terminal = vscode.window.terminals.find(t => t.name === 'Lipi Sovereign') || vscode.window.createTerminal('Lipi Sovereign');
      terminal.show();
      terminal.sendText(`./bin/lipi run "${filePath}"`);
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('lipi.buildFile', () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('কোনো সক্রিয় লিপি ফাইল উন্মুক্ত নেই।');
        return;
      }
      const filePath = editor.document.fileName;
      const outPath = filePath.replace(/\.(lp|lipi|লিপি)$/, '');
      const terminal = vscode.window.terminals.find(t => t.name === 'Lipi Sovereign') || vscode.window.createTerminal('Lipi Sovereign');
      terminal.show();
      terminal.sendText(`./bin/lipi build "${filePath}" -o "${outPath}"`);
    })
  );

  console.log('✔ Lipi Sovereign VS Code Extension activated successfully.');
}

function deactivate() {
  if (lspClient) {
    lspClient.stop();
  }
}

module.exports = { activate, deactivate };

