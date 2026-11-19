// ==============================================================================
// 👑 LIPI LANGUAGE VS CODE EXTENSION (editors/vscode/src/extension.ts)
// ⚡ High-Performance Bilingual LSP Client & Language Feature Engine
// 100% Zero-Dependency Native VS Code Integration (Synchronized with extension.js)
// ==============================================================================

import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

interface BilingualDocEntry {
  kind: 'Keyword' | 'Function' | 'Module';
  syntax: string;
  desc: string;
}

const BILINGUAL_DOCS: Record<string, BilingualDocEntry> = {
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
  'match': { kind: 'Keyword', syntax: 'match expr ... end', desc: 'Pattern matching switch across cases and wildcards.' },
  'try': { kind: 'Keyword', syntax: 'try ... catch e ... end', desc: 'Structured exception handling block with stack unwinding.' },
  'throw': { kind: 'Keyword', syntax: 'throw expr', desc: 'Raises an exception handled by enclosing try/catch frames.' },
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

  // Standard Library Gateways (utso/)
  'utso/web': { kind: 'Module', syntax: 'import "utso/web"', desc: 'High-throughput HTTP/1.1, HTTP/2, and REST microservices.' },
  'utso/db': { kind: 'Module', syntax: 'import "utso/db"', desc: 'LipiKV, ACID WAL storage engine, and Raft distributed consensus.' },
  'utso/ai': { kind: 'Module', syntax: 'import "utso/ai"', desc: 'SIMD AMX/AVX2 matrix multiplication and GGUF tensor inference.' },
  'utso/crypto': { kind: 'Module', syntax: 'import "utso/crypto"', desc: 'RFC 8446 TLS 1.3, SHA-256, Ed25519, and AES-GCM cryptography.' },
  'utso/net': { kind: 'Module', syntax: 'import "utso/net"', desc: 'Raw Linux TCP/UDP socket stack and RFC 6455 WebSocket framing.' },
  'utso/gui': { kind: 'Module', syntax: 'import "utso/gui"', desc: 'Direct framebuffer linear rasterizer and 2D canvas.' },
  'utso/os': { kind: 'Module', syntax: 'import "utso/os"', desc: 'Bare-metal Ring-0 unikernel, CLONE_VM threads, futexes, and Multiboot.' }
};

interface PendingRpc {
  resolve: (value: any) => void;
  reject: (err: Error) => void;
}

class LipiLspClient {
  public readonly lspPath: string;
  public readonly workspaceRoot: string;
  public isReady = false;
  private proc: cp.ChildProcessWithoutNullStreams | null = null;
  private nextId = 1;
  private pendingRequests = new Map<number, PendingRpc>();
  private buffer = Buffer.alloc(0);

  constructor(lspPath: string, workspaceRoot: string) {
    this.lspPath = lspPath;
    this.workspaceRoot = workspaceRoot;
  }

  start(): boolean {
    if (!fs.existsSync(this.lspPath)) {
      console.log(`[LipiLsp] Server binary not found at ${this.lspPath}. Using built-in language engine.`);
      return false;
    }

    try {
      this.proc = cp.spawn(this.lspPath, [], {
        cwd: this.workspaceRoot,
        stdio: ['pipe', 'pipe', 'pipe']
      });

      this.proc.stdout.on('data', (chunk: Buffer) => this._onData(chunk));
      this.proc.stderr.on('data', (chunk: Buffer) => {
        console.error(`[LipiLsp stderr] ${chunk.toString().trim()}`);
      });
      this.proc.on('error', (err: Error) => {
        console.error('[LipiLsp] Failed to start LSP process:', err);
        this.proc = null;
      });
      this.proc.on('close', (code: number | null) => {
        console.log(`[LipiLsp] Process exited with code ${code}`);
        this.proc = null;
        this.isReady = false;
      });

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
      }).catch((err: Error) => {
        console.error('[LipiLsp] Initialization failed:', err);
      });

      return true;
    } catch (e) {
      console.error('[LipiLsp] Spawn exception:', e);
      return false;
    }
  }

  stop(): void {
    if (this.proc) {
      try {
        this.proc.kill();
      } catch (_e) {}
      this.proc = null;
      this.isReady = false;
    }
  }

  sendRequest(method: string, params: unknown): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.proc || !this.proc.stdin.writable) {
        return reject(new Error('LSP process not available'));
      }
      const id = this.nextId++;
      const body = JSON.stringify({ jsonrpc: '2.0', id, method, params });
      const header = `Content-Length: ${Buffer.byteLength(body, 'utf8')}\r\n\r\n`;
      this.pendingRequests.set(id, { resolve, reject });
      this.proc.stdin.write(header + body);

      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`LSP Request ${method} timed out`));
        }
      }, 3000);
    });
  }

  sendNotification(method: string, params: unknown): void {
    if (!this.proc || !this.proc.stdin.writable) return;
    const body = JSON.stringify({ jsonrpc: '2.0', method, params });
    const header = `Content-Length: ${Buffer.byteLength(body, 'utf8')}\r\n\r\n`;
    this.proc.stdin.write(header + body);
  }

  private _onData(chunk: Buffer): void {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const headerEnd = this.buffer.indexOf('\r\n\r\n');
      if (headerEnd === -1) break;
      const headerText = this.buffer.subarray(0, headerEnd).toString('utf8');
      const match = headerText.match(/Content-Length:\s*(\d+)/i);
      if (!match) {
        this.buffer = this.buffer.subarray(headerEnd + 4);
        continue;
      }
      const contentLength = parseInt(match[1], 10);
      const bodyStart = headerEnd + 4;
      if (this.buffer.length < bodyStart + contentLength) break;

      const bodyText = this.buffer.subarray(bodyStart, bodyStart + contentLength).toString('utf8');
      this.buffer = this.buffer.subarray(bodyStart + contentLength);
      try {
        const json = JSON.parse(bodyText);
        if (json.id && this.pendingRequests.has(json.id)) {
          const pending = this.pendingRequests.get(json.id)!;
          this.pendingRequests.delete(json.id);
          if (json.error) {
            pending.reject(new Error(json.error.message || 'LSP Error'));
          } else {
            pending.resolve(json.result);
          }
        }
      } catch (err) {
        console.error('[LipiLsp] Failed to parse JSON-RPC response:', err);
      }
    }
  }
}

function resolveLspBinary(workspaceRoot: string, configuredPath?: string): string {
  const candidates = [
    configuredPath ? (path.isAbsolute(configuredPath) ? configuredPath : path.join(workspaceRoot, configuredPath)) : '',
    path.join(workspaceRoot, 'bin', 'lipilsp'),
    path.join(process.env.HOME || '', '.lipi', 'bin', 'lipilsp'),
    '/usr/local/bin/lipilsp',
    '/usr/bin/lipilsp'
  ].filter(Boolean);
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return path.join(workspaceRoot, 'bin', 'lipilsp');
}

let lspClient: LipiLspClient | null = null;
let diagnosticCollection: vscode.DiagnosticCollection | null = null;

export function activate(context: vscode.ExtensionContext): void {
  console.log('👑 Lipi Sovereign Programming Language extension activating...');

  const workspaceRoot = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
    ? vscode.workspace.workspaceFolders[0].uri.fsPath
    : process.cwd();

  const config = vscode.workspace.getConfiguration('lipi');
  const lspPath = resolveLspBinary(workspaceRoot, config.get<string>('lsp.path'));

  diagnosticCollection = vscode.languages.createDiagnosticCollection('lipi');
  context.subscriptions.push(diagnosticCollection);

  if (config.get<boolean>('lsp.enabled', true)) {
    lspClient = new LipiLspClient(lspPath, workspaceRoot);
    lspClient.start();
  }

  context.subscriptions.push(
    vscode.languages.registerHoverProvider('lipi', {
      async provideHover(document, position) {
        const wordRange = document.getWordRangeAtPosition(position, /[@]?[a-zA-Z0-9_\u0980-\u09FF\/\.]+/);
        if (!wordRange) return null;
        const word = document.getText(wordRange);

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
          } catch (_e) {}
        }

        if (BILINGUAL_DOCS[word]) {
          const item = BILINGUAL_DOCS[word];
          const md = new vscode.MarkdownString();
          md.appendCodeblock(item.syntax, 'lipi');
          md.appendMarkdown(`**${item.kind}** — ${item.desc}\n\n*Lipi Sovereign First 1.0.0*`);
          return new vscode.Hover(md);
        }
        return null;
      }
    })
  );

  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider('lipi', {
      async provideCompletionItems(document, position) {
        if (lspClient && lspClient.isReady) {
          try {
            const res = await lspClient.sendRequest('textDocument/completion', {
              textDocument: { uri: document.uri.toString() },
              position: { line: position.line, character: position.character }
            });
            if (res && Array.isArray(res.items)) {
              return res.items.map((it: any) => {
                const ci = new vscode.CompletionItem(it.label);
                ci.detail = it.detail;
                ci.documentation = new vscode.MarkdownString(it.documentation || '');
                return ci;
              });
            }
          } catch (_e) {}
        }

        return Object.entries(BILINGUAL_DOCS).map(([key, val]) => {
          const item = new vscode.CompletionItem(key);
          item.detail = val.syntax;
          item.documentation = new vscode.MarkdownString(val.desc);
          item.kind = val.kind === 'Keyword'
            ? vscode.CompletionItemKind.Keyword
            : val.kind === 'Function'
              ? vscode.CompletionItemKind.Function
              : vscode.CompletionItemKind.Module;
          return item;
        });
      }
    }, '.', '@', '/', '"')
  );

  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider('lipi', {
      provideDocumentFormattingEdits(document) {
        const text = document.getText();
        const lines = text.split('\n');
        let indentLevel = 0;
        const formatted: string[] = [];

        for (let i = 0; i < lines.length; i++) {
          const line = lines[i].trim();
          if (line.length === 0) {
            formatted.push('');
            continue;
          }
          if (line.startsWith('@end') || line.startsWith('end') || line.startsWith('নাহলে') || line.startsWith('else') || line.startsWith('elif')) {
            indentLevel = Math.max(0, indentLevel - 1);
          }
          formatted.push('    '.repeat(indentLevel) + line);
          if (line.startsWith('@fn') || line.startsWith('@if') || line.startsWith('@while') || line.startsWith('@struct') ||
              line.startsWith('কাজ ') || line.startsWith('যদি ') || line.startsWith('যতক্ষণ ') || line.startsWith('গঠন ') ||
              line.startsWith('fn ') || line.startsWith('if ') || line.startsWith('while ') || line.startsWith('struct ') ||
              line.startsWith('নাহলে:') || line.startsWith('else:') || line.startsWith('elif ') || line.endsWith(':')) {
            indentLevel++;
          }
        }

        const fullRange = new vscode.Range(document.positionAt(0), document.positionAt(text.length));
        return [vscode.TextEdit.replace(fullRange, formatted.join('\n'))];
      }
    })
  );

  function validateDocument(document: vscode.TextDocument): void {
    if (document.languageId !== 'lipi' || !diagnosticCollection) return;
    const diagnostics: vscode.Diagnostic[] = [];
    const lines = document.getText().split('\n');
    const directiveStack: Array<{ line: number; tag: string }> = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('//') || line.startsWith('@!')) continue;
      if (line.startsWith('@fn') || line.startsWith('@if') || line.startsWith('@while') || line.startsWith('@struct')) {
        directiveStack.push({ line: i, tag: line.split(' ')[0] });
      } else if (line.startsWith('@end')) {
        if (directiveStack.length === 0) {
          diagnostics.push(new vscode.Diagnostic(new vscode.Range(i, 0, i, line.length), 'অপ্রত্যাশিত @end: কোনো উন্মুক্ত ব্লক খুঁজে পাওয়া যায়নি', vscode.DiagnosticSeverity.Error));
        } else {
          directiveStack.pop();
        }
      }
    }

    for (const openBlock of directiveStack) {
      diagnostics.push(new vscode.Diagnostic(
        new vscode.Range(openBlock.line, 0, openBlock.line, lines[openBlock.line].length),
        `অনাবৃত ${openBlock.tag} ব্লক: সমাপ্তির জন্য @end প্রয়োজন`,
        vscode.DiagnosticSeverity.Error
      ));
    }
    diagnosticCollection.set(document.uri, diagnostics);
  }

  context.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validateDocument));
  context.subscriptions.push(vscode.workspace.onDidChangeTextDocument(e => validateDocument(e.document)));
  context.subscriptions.push(vscode.workspace.onDidCloseTextDocument(doc => diagnosticCollection?.delete(doc.uri)));
  vscode.workspace.textDocuments.forEach(validateDocument);

  const runTerminal = (cmd: string) => {
    const terminal = vscode.window.terminals.find(t => t.name === 'Lipi Sovereign') || vscode.window.createTerminal('Lipi Sovereign');
    terminal.show();
    terminal.sendText(cmd);
  };

  context.subscriptions.push(
    vscode.commands.registerCommand('lipi.restartLsp', () => {
      if (lspClient) lspClient.stop();
      lspClient = new LipiLspClient(lspPath, workspaceRoot);
      const ok = lspClient.start();
      vscode.window.showInformationMessage(ok ? 'Lipi Language Server restarted.' : 'Using built-in Lipi language engine.');
    }),
    vscode.commands.registerCommand('lipi.runFile', () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('কোনো সক্রিয় লিপি ফাইল উন্মুক্ত নেই।');
        return;
      }
      runTerminal(`./bin/lipi run "${editor.document.fileName}"`);
    }),
    vscode.commands.registerCommand('lipi.buildFile', () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('কোনো সক্রিয় লিপি ফাইল উন্মুক্ত নেই।');
        return;
      }
      const filePath = editor.document.fileName;
      runTerminal(`./bin/lipi build "${filePath}" -o "${filePath.replace(/\.(lp|lipi|লিপি)$/, '')}"`);
    }),
    vscode.commands.registerCommand('lipi.build', () => runTerminal('./bin/lipi build')),
    vscode.commands.registerCommand('lipi.test', () => runTerminal('./bin/lipi test')),
    vscode.commands.registerCommand('lipi.run', () => runTerminal('./bin/lipi run'))
  );
}

export function deactivate(): void {
  if (lspClient) {
    lspClient.stop();
  }
}
