import * as vscode from 'vscode';
import { LanguageClient, ServerOptions, TransportKind, LanguageClientOptions } from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
  // Lipi Language Server (lipilsp) executable configuration
  const config = vscode.workspace.getConfiguration('lipi');
  const lspPath = config.get<string>('lsp.path') || 'bin/lipilsp';

  const serverOptions: ServerOptions = {
    command: lspPath,
    args: ['lsp'],
    transport: TransportKind.stdio,
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'lipi' }],
  };

  if (config.get<boolean>('lsp.enabled', true)) {
    client = new LanguageClient(
      'lipiLSP',
      'Lipi Sovereign Language Server',
      serverOptions,
      clientOptions
    );
    client.start();
  }

  context.subscriptions.push(
    vscode.commands.registerCommand('lipi.build', () => {
      vscode.window.showInformationMessage('Building Lipi project...');
      const terminal = vscode.window.createTerminal('Lipi');
      terminal.show();
      terminal.sendText('bin/lipc build');
    }),
    vscode.commands.registerCommand('lipi.test', () => {
      vscode.window.showInformationMessage('Running Lipi tests...');
      const terminal = vscode.window.createTerminal('Lipi');
      terminal.show();
      terminal.sendText('bin/lipc test');
    }),
    vscode.commands.registerCommand('lipi.run', () => {
      vscode.window.showInformationMessage('Running Lipi project...');
      const terminal = vscode.window.createTerminal('Lipi');
      terminal.show();
      terminal.sendText('bin/lipc run');
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
