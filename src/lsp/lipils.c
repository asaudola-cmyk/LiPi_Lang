/* ==============================================================================
 * 🏛️ lipils — Lipi Native Language Server Protocol (LSP) Engine
 * ⚡ Version: প্রথম ১.০ (First 1.0) — Sovereign Native Binary (Zero Python)
 * File: src/lsp/lipils.c
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_BUF 65536

static void send_lsp_response(const char* body) {
    size_t len = strlen(body);
    printf("Content-Length: %zu\r\n\r\n%s", len, body);
    fflush(stdout);
}

static const char* COMPLETIONS_JSON = 
"["
"{\"label\":\"fn\",\"kind\":14,\"detail\":\"Function declaration\",\"documentation\":\"fn name(args)\\n    return val\",\"insertText\":\"fn ${1:name}(${2:params})\\n    ${0}\"},"
"{\"label\":\"if\",\"kind\":14,\"detail\":\"Conditional statement\",\"documentation\":\"if condition\\n    statement\",\"insertText\":\"if ${1:condition}\\n    ${0}\"},"
"{\"label\":\"else\",\"kind\":14,\"detail\":\"Else block\",\"documentation\":\"else\\n    statement\",\"insertText\":\"else\\n    ${0}\"},"
"{\"label\":\"elif\",\"kind\":14,\"detail\":\"Else-if conditional\",\"documentation\":\"elif condition\\n    statement\",\"insertText\":\"elif ${1:condition}\\n    ${0}\"},"
"{\"label\":\"say\",\"kind\":3,\"detail\":\"Print to stdout\",\"documentation\":\"say expr\",\"insertText\":\"say ${1:expr}\"},"
"{\"label\":\"print\",\"kind\":3,\"detail\":\"Print to stdout\",\"documentation\":\"print expr\",\"insertText\":\"print ${1:expr}\"},"
"{\"label\":\"while\",\"kind\":14,\"detail\":\"While loop\",\"documentation\":\"while condition\\n    body\",\"insertText\":\"while ${1:condition}\\n    ${0}\"},"
"{\"label\":\"for\",\"kind\":14,\"detail\":\"Range loop\",\"documentation\":\"for i in 1..10\",\"insertText\":\"for ${1:i} in ${2:1}..${3:10}\\n    ${0}\"},"
"{\"label\":\"repeat\",\"kind\":14,\"detail\":\"Repeat loop\",\"documentation\":\"repeat count\",\"insertText\":\"repeat ${1:5}\\n    ${0}\"},"
"{\"label\":\"return\",\"kind\":14,\"detail\":\"Return value\",\"documentation\":\"return val\",\"insertText\":\"return ${1:val}\"},"
"{\"label\":\"struct\",\"kind\":7,\"detail\":\"Struct definition\",\"documentation\":\"struct Name\\n    field1\\n    field2\",\"insertText\":\"struct ${1:Name}\\n    ${2:field1}\\n    ${3:field2}\"},"
"{\"label\":\"কাজ\",\"kind\":14,\"detail\":\"ফাংশন ঘোষণা (fn)\",\"documentation\":\"কাজ নাম(ক, খ)\\n    ফেরত ক + খ\",\"insertText\":\"কাজ ${1:নাম}(${2:প্যারামিটার})\\n    ${0}\"},"
"{\"label\":\"যদি\",\"kind\":14,\"detail\":\"শর্ত সাপেক্ষ (if)\",\"documentation\":\"যদি শর্ত\\n    বিবৃতি\",\"insertText\":\"যদি ${1:শর্ত}\\n    ${0}\"},"
"{\"label\":\"নাহলে\",\"kind\":14,\"detail\":\"নাহলে ব্লক (else)\",\"documentation\":\"নাহলে\\n    বিবৃতি\",\"insertText\":\"নাহলে\\n    ${0}\"},"
"{\"label\":\"নাহলে_যদি\",\"kind\":14,\"detail\":\"অন্যথায় যদি (elif)\",\"documentation\":\"নাহলে_যদি শর্ত\\n    বিবৃতি\",\"insertText\":\"নাহলে_যদি ${1:শর্ত}\\n    ${0}\"},"
"{\"label\":\"বলো\",\"kind\":3,\"detail\":\"আউটপুট প্রিন্ট (say)\",\"documentation\":\"বলো 'হ্যালো লিপি'\",\"insertText\":\"বলো ${1:মান}\"},"
"{\"label\":\"দেখাও\",\"kind\":3,\"detail\":\"আউটপুট প্রদর্শন (show)\",\"documentation\":\"দেখাও মান\",\"insertText\":\"দেখাও ${1:মান}\"},"
"{\"label\":\"যতক্ষণ\",\"kind\":14,\"detail\":\"লুপ (while)\",\"documentation\":\"যতক্ষণ শর্ত\\n    কাজ\",\"insertText\":\"যতক্ষণ ${1:শর্ত}\\n    ${0}\"},"
"{\"label\":\"বার\",\"kind\":14,\"detail\":\"পুনরাবৃত্তি (repeat)\",\"documentation\":\"৫ বার বলো 'লিপি'\",\"insertText\":\"${1:৫} বার বলো ${2:মান}\"},"
"{\"label\":\"ফেরত\",\"kind\":14,\"detail\":\"মান ফেরত (return)\",\"documentation\":\"ফেরত ফলাফল\",\"insertText\":\"ফেরত ${1:মান}\"},"
"{\"label\":\"গঠন\",\"kind\":7,\"detail\":\"স্ট্রাকচার (struct)\",\"documentation\":\"গঠন বিন্দু\\n    ক\\n    খ\",\"insertText\":\"গঠন ${1:নাম}\\n    ${2:ক্ষেত্র১}\\n    ${3:ক্ষেত্র২}\"},"
"{\"label\":\"প্রতিটি\",\"kind\":14,\"detail\":\"রেঞ্জ লুপ (for)\",\"documentation\":\"প্রতিটি উপাদান ভেতরে ১..১০\",\"insertText\":\"প্রতিটি ${1:i} ভেতরে ${2:১}..${3:১০}\\n    ${0}\"}"
"]";

static void handle_request(const char* body) {
    /* Extract request ID if present */
    char id_str[64] = "1";
    const char* id_pos = strstr(body, "\"id\":");
    if (id_pos) {
        id_pos += 5;
        while (*id_pos == ' ' || *id_pos == '\t') id_pos++;
        int i = 0;
        while ((isdigit(*id_pos) || *id_pos == '"') && i < 60) {
            if (*id_pos != '"') id_str[i++] = *id_pos;
            id_pos++;
        }
        id_str[i] = '\0';
    }

    /* Method: initialize */
    if (strstr(body, "\"method\":\"initialize\"")) {
        char resp[1024];
        snprintf(resp, sizeof(resp),
            "{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{"
            "\"capabilities\":{"
            "\"textDocumentSync\":1,"
            "\"completionProvider\":{\"resolveProvider\":false,\"triggerCharacters\":[\".\",\"(\",\")\",\" \"]},"
            "\"hoverProvider\":true"
            "}}}", id_str);
        send_lsp_response(resp);
        return;
    }

    /* Method: textDocument/completion */
    if (strstr(body, "\"method\":\"textDocument/completion\"")) {
        char resp[MAX_BUF];
        snprintf(resp, sizeof(resp),
            "{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":%s}",
            id_str, COMPLETIONS_JSON);
        send_lsp_response(resp);
        return;
    }

    /* Method: textDocument/hover */
    if (strstr(body, "\"method\":\"textDocument/hover\"")) {
        char resp[1024];
        snprintf(resp, sizeof(resp),
            "{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":{"
            "\"contents\":{\"kind\":\"markdown\",\"value\":\"**লিপি ২.০ (Lipi)**\\n\\nSovereign bilingual programming language keyword.\"}"
            "}}", id_str);
        send_lsp_response(resp);
        return;
    }

    /* Method: shutdown */
    if (strstr(body, "\"method\":\"shutdown\"")) {
        char resp[256];
        snprintf(resp, sizeof(resp), "{\"jsonrpc\":\"2.0\",\"id\":%s,\"result\":null}", id_str);
        send_lsp_response(resp);
        return;
    }

    /* Method: exit */
    if (strstr(body, "\"method\":\"exit\"")) {
        exit(0);
    }
}

int main(void) {
    char header_line[512];
    while (fgets(header_line, sizeof(header_line), stdin)) {
        if (strncmp(header_line, "Content-Length:", 15) == 0) {
            int content_len = atoi(header_line + 15);
            /* Skip headers until empty line */
            while (fgets(header_line, sizeof(header_line), stdin)) {
                if (strcmp(header_line, "\r\n") == 0 || strcmp(header_line, "\n") == 0) break;
            }
            if (content_len > 0) {
                char* body = (char*)malloc(content_len + 1);
                if (body) {
                    size_t read_bytes = fread(body, 1, content_len, stdin);
                    body[read_bytes] = '\0';
                    handle_request(body);
                    free(body);
                }
            }
        }
    }
    return 0;
}
