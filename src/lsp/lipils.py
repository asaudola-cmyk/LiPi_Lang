#!/usr/bin/env python3
"""
==============================================================================
🏛️ lipils — Lipi Language Server Protocol (LSP) Engine
⚡ Version: প্রথম ১.০ (First 1.0) — Sovereign
File: src/lsp/lipils.py

WHY: Developers need modern IDE integration (VS Code, Neovim, Emacs, Helix)
     with real-time syntax error reporting, bilingual code completion, and
     rich Bengali/English hover documentation. lipils implements the official
     Language Server Protocol 3.17 standard over JSON-RPC 2.0.
==============================================================================
"""

from __future__ import annotations
import sys
import os
import json
import re
from typing import Dict, List, Any, Optional

# Add project root to sys.path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from src.runtime.lexer import Lexer, LexError, KEYWORDS, TT
from src.runtime.parser import Parser, ParseError

# ─────────────────────────────────────────────────────────────────────────────
# Bilingual Documentation & Autocomplete Registry
# ─────────────────────────────────────────────────────────────────────────────

COMPLETIONS = [
    # English keywords
    {"label": "fn", "kind": 14, "detail": "Function declaration", "documentation": "fn name(arg1, arg2)\n    return val", "insertText": "fn ${1:name}(${2:params})\n    ${0}"},
    {"label": "if", "kind": 14, "detail": "Conditional statement", "documentation": "if condition\n    statement", "insertText": "if ${1:condition}\n    ${0}"},
    {"label": "else", "kind": 14, "detail": "Else block", "documentation": "else\n    statement", "insertText": "else\n    ${0}"},
    {"label": "elif", "kind": 14, "detail": "Else-if conditional", "documentation": "elif condition\n    statement", "insertText": "elif ${1:condition}\n    ${0}"},
    {"label": "say", "kind": 3, "detail": "Print to stdout with newline", "documentation": "say expression", "insertText": "say ${1:expr}"},
    {"label": "show", "kind": 3, "detail": "Print to stdout", "documentation": "show expression", "insertText": "show ${1:expr}"},
    {"label": "print", "kind": 3, "detail": "Print to stdout", "documentation": "print expression", "insertText": "print ${1:expr}"},
    {"label": "while", "kind": 14, "detail": "While loop", "documentation": "while condition\n    body", "insertText": "while ${1:condition}\n    ${0}"},
    {"label": "repeat", "kind": 14, "detail": "Repeat count times", "documentation": "repeat 5\n    say 'hello'", "insertText": "repeat ${1:count}\n    ${0}"},
    {"label": "return", "kind": 14, "detail": "Return from function", "documentation": "return value", "insertText": "return ${1:value}"},
    {"label": "struct", "kind": 7, "detail": "Define data structure", "documentation": "struct Point\n    x\n    y", "insertText": "struct ${1:Name}\n    ${2:field1}\n    ${3:field2}"},
    {"label": "include", "kind": 14, "detail": "Import file", "documentation": 'include "std/core/io.lp"', "insertText": 'include "${1:path}.lp"'},
    {"label": "for", "kind": 14, "detail": "Range loop", "documentation": "for i in 1..10\n    say i", "insertText": "for ${1:i} in ${2:1}..${3:10}\n    ${0}"},
    {"label": "break", "kind": 14, "detail": "Break from loop", "documentation": "break"},
    {"label": "continue", "kind": 14, "detail": "Continue next iteration", "documentation": "continue"},
    {"label": "true", "kind": 21, "detail": "Boolean true", "documentation": "Boolean literal true"},
    {"label": "false", "kind": 21, "detail": "Boolean false", "documentation": "Boolean literal false"},
    {"label": "null", "kind": 21, "detail": "Null value", "documentation": "Represents null or empty value"},

    # Bengali keywords (বাংলা কিওয়ার্ড)
    {"label": "কাজ", "kind": 14, "detail": "ফাংশন ডিক্লেয়ারেশন (fn)", "documentation": "কাজ নাম(ক, খ)\n    ফেরত ক + খ", "insertText": "কাজ ${1:নাম}(${2:প্যারামিটার})\n    ${0}"},
    {"label": "যদি", "kind": 14, "detail": "শর্তমূলক স্টেটমেন্ট (if)", "documentation": "যদি শর্ত\n    বিবৃতি", "insertText": "যদি ${1:শর্ত}\n    ${0}"},
    {"label": "নাহলে", "kind": 14, "detail": "নাহলে ব্লক (else)", "documentation": "নাহলে\n    বিবৃতি", "insertText": "নাহলে\n    ${0}"},
    {"label": "নাহলে_যদি", "kind": 14, "detail": "অন্যথায় যদি (elif)", "documentation": "নাহলে_যদি শর্ত\n    বিবৃতি", "insertText": "নাহলে_যদি ${1:শর্ত}\n    ${0}"},
    {"label": "বলো", "kind": 3, "detail": "আউটপুট প্রদর্শন (say)", "documentation": 'বলো "হ্যালো বিশ্ব!"', "insertText": "বলো ${1:মান}"},
    {"label": "দেখাও", "kind": 3, "detail": "আউটপুট প্রদর্শন (show)", "documentation": "দেখাও মান", "insertText": "দেখাও ${1:মান}"},
    {"label": "যতক্ষণ", "kind": 14, "detail": "লুপ স্টেটমেন্ট (while)", "documentation": "যতক্ষণ শর্ত\n    কাজ", "insertText": "যতক্ষণ ${1:শর্ত}\n    ${0}"},
    {"label": "বার", "kind": 14, "detail": "পুনরাবৃত্তি লুপ (repeat)", "documentation": '৫ বার বলো "জয় লিপি!"', "insertText": "${1:৫} বার বলো ${2:মান}"},
    {"label": "ফেরত", "kind": 14, "detail": "মান ফেরত দেওয়া (return)", "documentation": "ফেরত ফলাফল", "insertText": "ফেরত ${1:মান}"},
    {"label": "গঠন", "kind": 7, "detail": "স্ট্রাকচার ঘোষণা (struct)", "documentation": "গঠন বিন্দু\n    ক\n    খ", "insertText": "গঠন ${1:নাম}\n    ${2:ক্ষেত্র১}\n    ${3:ক্ষেত্র২}"},
    {"label": "অন্তর্ভুক্ত", "kind": 14, "detail": "মডিউল অন্তর্ভুক্তকরণ (include)", "documentation": 'অন্তর্ভুক্ত "std/core/io.lp"', "insertText": 'অন্তর্ভুক্ত "${1:পথ}.lp"'},
    {"label": "প্রতিটি", "kind": 14, "detail": "লুপ স্টেটমেন্ট (for/each)", "documentation": "প্রতিটি উপাদান ভেতরে তালিকা", "insertText": "প্রতিটি ${1:আইটেম} ভেতরে ${2:তালিকা}\n    ${0}"},
    {"label": "থামো", "kind": 14, "detail": "লুপ সমাপ্তি (break)", "documentation": "থামো"},
    {"label": "চালিয়ে_যাও", "kind": 14, "detail": "পরবর্তী পুনরাবৃত্তি (continue)", "documentation": "চালিয়ে_যাও"},
    {"label": "সত্য", "kind": 21, "detail": "বুলিয়ান সত্য (true)", "documentation": "বুলিয়ান সত্য মান"},
    {"label": "মিথ্যা", "kind": 21, "detail": "বুলিয়ান মিথ্যা (false)", "documentation": "বুলিয়ান মিথ্যা মান"},
    {"label": "শূন্য", "kind": 21, "detail": "নাল মান (null)", "documentation": "শূন্য বা নাল মান"},

    # Standard Library Builtins
    {"label": "len", "kind": 3, "detail": "fn(x) -> int", "documentation": "Returns string length or item count.\nস্ট্রিং বা তালিকার দৈর্ঘ্য প্রদান করে।"},
    {"label": "দৈর্ঘ্য", "kind": 3, "detail": "কাজ(মান) -> সংখ্যা", "documentation": "স্ট্রিং বা স্ট্রাকটের দৈর্ঘ্য/আকার প্রদান করে।"},
    {"label": "abs", "kind": 3, "detail": "fn(n) -> int", "documentation": "Returns absolute value of a number.\nসংখ্যার পরমমান প্রদান করে।"},
    {"label": "max", "kind": 3, "detail": "fn(a, b) -> int", "documentation": "Returns maximum value.\nসর্বোচ্চ মান প্রদান করে।"},
    {"label": "min", "kind": 3, "detail": "fn(a, b) -> int", "documentation": "Returns minimum value.\nসর্বনিম্ন মান প্রদান করে।"},
    {"label": "str", "kind": 3, "detail": "fn(x) -> string", "documentation": "Converts value to string.\nযেকোনো মানকে স্ট্রিংয়ে রূপান্তর করে।"},
    {"label": "int", "kind": 3, "detail": "fn(x) -> int", "documentation": "Converts value to 64-bit integer.\nপূর্ণসংখ্যায় রূপান্তর করে।"},
    {"label": "type", "kind": 3, "detail": "fn(x) -> string", "documentation": "Returns type name of value.\nমানের ধরন প্রদান করে।"},
]

HOVER_DOCS: Dict[str, str] = {
    "say": "### `say` / `বলো` (Console Output)\nPrints expressions to stdout followed by a newline.\n\n```lipi\nsay 'Hello, World!'\n```",
    "বলো": "### `বলো` / `say` (কনসোল আউটপুট)\nপ্রদত্ত অভিব্যক্তি কনসোলে প্রিন্ট করে এবং একটি নতুন লাইন যুক্ত করে।\n\n```lipi\nবলো 'স্বাগতম লিপি ২.০ তে!'\n```",
    "show": "### `show` (Console Output)\nPrints expressions to stdout followed by a newline.",
    "দেখাও": "### `দেখাও` (কনসোল আউটপুট)\nপ্রদত্ত মান কনসোলে আউটপুট হিসেবে প্রদর্শন করে।",
    "print": "### `print` (Console Output)\nPrints expressions to stdout.",
    "fn": "### `fn` / `কাজ` (Function Declaration)\nDefines a callable function with parameters.\n\n```lipi\nfn add(a, b)\n    return a + b\n```",
    "কাজ": "### `কাজ` / `fn` (ফাংশন ঘোষণা)\nএকটি পুনরায় ব্যবহারযোগ্য কোড ব্লক বা ফাংশন তৈরি করে।\n\n```lipi\nকাজ যোগফল(ক, খ)\n    ফেরত ক + খ\n```",
    "if": "### `if` / `যদি` (Conditional Branch)\nExecutes block if condition is true.\n\n```lipi\nif x > 10\n    say 'Greater'\n```",
    "যদি": "### `যদি` / `if` (শর্তমূলক শাখা)\nশর্ত সত্য হলে সংশ্লিষ্ট কোড ব্লক কার্যকর করে।\n\n```lipi\nযদি বয়স >= ১৮\n    বলো 'প্রাপ্তবয়স্ক'\n```",
    "else": "### `else` / `নাহলে` (Else Branch)\nExecutes if condition was false.",
    "নাহলে": "### `নাহলে` / `else` (বিকল্প শাখা)\nপূর্ববর্তী শর্ত মিথ্যা হলে এই ব্লকটি কার্যকর হয়।",
    "elif": "### `elif` / `নাহলে_যদি` (Else-If Branch)",
    "নাহলে_যদি": "### `নাহলে_যদি` / `elif` (পরবর্তী শর্তমূলক বিকল্প)",
    "while": "### `while` / `যতক্ষণ` (While Loop)\nRepeats block while condition holds true.",
    "যতক্ষণ": "### `যতক্ষণ` / `while` (যতক্ষণ পর্যন্ত লুপ)\nযতক্ষণ শর্তটি সত্য থাকবে, ততক্ষণ লুপের ভেতরের কোড চলতে থাকবে।",
    "repeat": "### `repeat` (Repetition Loop)\nRepeats a statement or block N times.\n\n```lipi\nrepeat 3 say 'Lipi'\n```",
    "বার": "### `বার` (পুনরাবৃত্তি লুপ)\nকোনো কাজ নির্দিষ্ট সংখ্যক বার চালানোর জন্য ব্যবহৃত হয়।\n\n```lipi\n৩ বার বলো 'বাংলাদেশ'\n```",
    "return": "### `return` / `ফেরত` (Function Return)\nReturns a value from the current function.",
    "ফেরত": "### `ফেরত` / `return` (ফাংশন ফলাফল)\nফাংশন থেকে একটি নির্দিষ্ট মান কলারের কাছে ফেরত পাঠায়।",
    "struct": "### `struct` / `গঠন` (Structure)\nDefines a user-defined composite data structure.",
    "গঠন": "### `গঠন` / `struct` (ইউজার-ডিফাইন্ড টাইপ)\nকাস্টম ডেটা টাইপ বা স্ট্রাকচার তৈরি করার সিনট্যাক্স।",
    "include": "### `include` / `অন্তর্ভুক্ত` (File Inclusion)\nIncludes another Lipi file or standard library module.",
    "অন্তর্ভুক্ত": "### `অন্তর্ভুক্ত` / `include` (মডিউল যুক্তকরণ)\nঅন্য কোনো লিপি ফাইল বা স্ট্যান্ডার্ড লাইব্রেরি কোডে যুক্ত করে।",
    "len": "### `len(x)` / `দৈর্ঘ্য(x)` (Length)\nReturns length of string, list, or struct.",
    "দৈর্ঘ্য": "### `দৈর্ঘ্য(x)` / `len(x)` (আকার ও দৈর্ঘ্য)\nস্ট্রিং, অ্যারে বা স্ট্রাকটের উপাদানের সংখ্যা প্রদান করে।",
    "abs": "### `abs(n)` (Absolute Value)\nReturns the non-negative magnitude of integer `n`.",
}

# ─────────────────────────────────────────────────────────────────────────────
# LSP Diagnostic Analyzer
# ─────────────────────────────────────────────────────────────────────────────

def analyze_lipi_source(source: str, uri: str) -> List[Dict[str, Any]]:
    """
    Parses Lipi source code and returns a list of LSP Diagnostics for any syntax errors.
    """
    diagnostics: List[Dict[str, Any]] = []
    try:
        lexer = Lexer(source, uri)
        tokens = lexer.tokenize()
        parser = Parser(tokens)
        parser.parse()
    except LexError as e:
        match = re.search(r":(\d+):(\d+):\s*(.*)", str(e))
        line = int(match.group(1)) - 1 if match else 0
        col = int(match.group(2)) - 1 if match else 0
        msg = match.group(3) if match else str(e)
        diagnostics.append({
            "range": {
                "start": {"line": max(0, line), "character": max(0, col)},
                "end": {"line": max(0, line), "character": max(0, col + 5)}
            },
            "severity": 1,  # Error
            "source": "lipils",
            "message": f"লেক্সিক্যাল ত্রুটি: {msg}"
        })
    except ParseError as e:
        match = re.search(r"Line (\d+):\s*(.*)", str(e))
        line = int(match.group(1)) - 1 if match else 0
        msg = match.group(2) if match else str(e)
        diagnostics.append({
            "range": {
                "start": {"line": max(0, line), "character": 0},
                "end": {"line": max(0, line), "character": 80}
            },
            "severity": 1,  # Error
            "source": "lipils",
            "message": f"সিনট্যাক্স ত্রুটি: {msg}"
        })
    except Exception as e:
        diagnostics.append({
            "range": {
                "start": {"line": 0, "character": 0},
                "end": {"line": 0, "character": 1}
            },
            "severity": 1,
            "source": "lipils",
            "message": f"পার্সার ত্রুটি: {str(e)}"
        })
    return diagnostics


# ─────────────────────────────────────────────────────────────────────────────
# JSON-RPC Protocol Transport
# ─────────────────────────────────────────────────────────────────────────────

class LipiLanguageServer:
    def __init__(self):
        self.documents: Dict[str, str] = {}
        self.is_shutdown = False

    def read_message(self) -> Optional[Dict[str, Any]]:
        """Reads a JSON-RPC message from stdin with Content-Length header."""
        header_bytes = sys.stdin.buffer.readline()
        if not header_bytes:
            return None
        header = header_bytes.decode("latin1")
        content_length = 0
        while header and header != "\r\n" and header != "\n":
            if header.lower().startswith("content-length:"):
                content_length = int(header.split(":")[1].strip())
            header_bytes = sys.stdin.buffer.readline()
            header = header_bytes.decode("latin1")

        if content_length > 0:
            body = sys.stdin.buffer.read(content_length).decode("utf-8")
            return json.loads(body)
        return None

    def send_message(self, msg: Dict[str, Any]):
        """Sends a JSON-RPC message to stdout with Content-Length header."""
        body = json.dumps(msg, ensure_ascii=False)
        encoded = body.encode("utf-8")
        header = f"Content-Length: {len(encoded)}\r\n\r\n"
        sys.stdout.buffer.write(header.encode("latin1"))
        sys.stdout.buffer.write(encoded)
        sys.stdout.buffer.flush()

    def send_response(self, req_id: Any, result: Any = None, error: Any = None):
        res: Dict[str, Any] = {"jsonrpc": "2.0", "id": req_id}
        if error is not None:
            res["error"] = error
        else:
            res["result"] = result
        self.send_message(res)

    def publish_diagnostics(self, uri: str):
        source = self.documents.get(uri, "")
        diags = analyze_lipi_source(source, uri)
        notification = {
            "jsonrpc": "2.0",
            "method": "textDocument/publishDiagnostics",
            "params": {
                "uri": uri,
                "diagnostics": diags
            }
        }
        self.send_message(notification)

    def run(self):
        """Main JSON-RPC event loop."""
        while not self.is_shutdown:
            msg = self.read_message()
            if msg is None:
                break
            self.handle_message(msg)

    def handle_message(self, msg: Dict[str, Any]):
        method = msg.get("method")
        req_id = msg.get("id")
        params = msg.get("params", {})

        # 1. Lifecycle
        if method == "initialize":
            capabilities = {
                "textDocumentSync": 1,  # Full document sync
                "completionProvider": {
                    "resolveProvider": False,
                    "triggerCharacters": [".", " ", "(", "{"]
                },
                "hoverProvider": True,
            }
            self.send_response(req_id, {
                "capabilities": capabilities,
                "serverInfo": {
                    "name": "lipils",
                    "version": "প্রথম ১.০ (First 1.0) Sovereign"
                }
            })
            return

        if method == "initialized":
            return

        if method == "shutdown":
            self.is_shutdown = True
            self.send_response(req_id, None)
            return

        if method == "exit":
            sys.exit(0)

        # 2. Document Synchronization
        if method == "textDocument/didOpen":
            doc = params.get("textDocument", {})
            uri = doc.get("uri", "")
            self.documents[uri] = doc.get("text", "")
            self.publish_diagnostics(uri)
            return

        if method == "textDocument/didChange":
            uri = params.get("textDocument", {}).get("uri", "")
            changes = params.get("contentChanges", [])
            if changes:
                self.documents[uri] = changes[0].get("text", "")
                self.publish_diagnostics(uri)
            return

        if method == "textDocument/didSave":
            uri = params.get("textDocument", {}).get("uri", "")
            self.publish_diagnostics(uri)
            return

        if method == "textDocument/didClose":
            uri = params.get("textDocument", {}).get("uri", "")
            if uri in self.documents:
                del self.documents[uri]
            return

        # 3. Autocompletion
        if method == "textDocument/completion":
            self.send_response(req_id, {
                "isIncomplete": False,
                "items": COMPLETIONS
            })
            return

        # 4. Hover
        if method == "textDocument/hover":
            uri = params.get("textDocument", {}).get("uri", "")
            pos = params.get("position", {})
            line_idx = pos.get("line", 0)
            char_idx = pos.get("character", 0)

            content = self.documents.get(uri, "")
            lines = content.splitlines()
            hover_text = None

            if 0 <= line_idx < len(lines):
                target_line = lines[line_idx]
                matches = re.finditer(r'[\w\u0980-\u09FF]+', target_line)
                for m in matches:
                    if m.start() <= char_idx <= m.end():
                        word = m.group(0)
                        if word in HOVER_DOCS:
                            hover_text = HOVER_DOCS[word]
                        break

            if hover_text:
                self.send_response(req_id, {
                    "contents": {
                        "kind": "markdown",
                        "value": hover_text
                    }
                })
            else:
                self.send_response(req_id, None)
            return

        # Unknown request
        if req_id is not None:
            self.send_response(req_id, error={"code": -32601, "message": f"Method '{method}' not supported"})


def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("--version", "-v"):
            print("lipils — Lipi Language Server Protocol Engine")
            print("সংস্করণ: প্রথম ১.০ (First 1.0) — Sovereign")
            print("LSP Protocol: 3.17 | JSON-RPC 2.0")
            sys.exit(0)
        elif arg == "--check" and len(sys.argv) > 2:
            file_path = sys.argv[2]
            if not os.path.exists(file_path):
                print(f"Error: File '{file_path}' not found", file=sys.stderr)
                sys.exit(1)
            with open(file_path, "r", encoding="utf-8") as f:
                src = f.read()
            diags = analyze_lipi_source(src, file_path)
            if diags:
                print(f"Found {len(diags)} diagnostic issue(s):")
                for d in diags:
                    print(f"  Line {d['range']['start']['line']+1}: {d['message']}")
                sys.exit(1)
            else:
                print("✔ No syntax errors found. File is clean!")
                sys.exit(0)
        elif arg in ("--help", "-h"):
            print("Usage: lipils [--stdio] [--check <file.lp>] [--version]")
            sys.exit(0)

    # Default: Run stdio LSP server
    server = LipiLanguageServer()
    server.run()


if __name__ == "__main__":
    main()
