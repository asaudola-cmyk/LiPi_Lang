@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: MARKDOWN PARSER & HTML/ANSI RENDERER
@! File: tests/e2e/tier4_applications/test_app_markdown_parser.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct MDBlock
  kind: 0        @! 1=Heading, 2=Paragraph, 3=List, 4=Quote, 5=CodeBlock
  level: 0       @! 1..6 for Heading
  content: ""
  items: 0       @! array of strings for list
  lang: ""        @! for code block
@end

@fn parse_inline_html(text)
  out = ""
  len = str_len(text)
  pos = 0

  @while pos < len
    c = char_at(text, pos)

    @! Bold **...**
    @if c == char_code("*") && pos + 1 < len && char_at(text, pos + 1) == char_code("*")
      pos = pos + 2
      end_pos = pos
      @while end_pos + 1 < len && !(char_at(text, end_pos) == char_code("*") && char_at(text, end_pos + 1) == char_code("*"))
        end_pos = end_pos + 1
      @end
      bold_txt = str_substr(text, pos, end_pos)
      out = out + "<strong>" + bold_txt + "</strong>"
      pos = end_pos + 2
    @elif c == char_code("`")
      @! Inline code `...`
      pos = pos + 1
      end_pos = pos
      @while end_pos < len && char_at(text, end_pos) != char_code("`")
        end_pos = end_pos + 1
      @end
      code_txt = str_substr(text, pos, end_pos)
      out = out + "<code>" + code_txt + "</code>"
      pos = end_pos + 1
    @else
      out = out + from_char(c)
      pos = pos + 1
    @end
  @end

  return out
@end

@fn split_lines(src)
  lines = []
  len = str_len(src)
  pos = 0
  @while pos < len
    next_nl = pos
    @while next_nl < len && char_at(src, next_nl) != char_code("\n")
      next_nl = next_nl + 1
    @end
    line = str_substr(src, pos, next_nl)
    lines.push(line)
    pos = next_nl + 1
  @end
  return lines
@end

@fn parse_markdown_doc(doc_str)
  lines = split_lines(doc_str)
  blocks = []
  i = 0
  num_lines = lines.len()

  @while i < num_lines
    line = lines[i]
    line_len = str_len(line)

    @! 1. Code Block ```lang
    @if string_starts_with(line, "```") == 1
      lang = str_substr(line, 3, line_len)
      code_content = ""
      i = i + 1
      @while i < num_lines && string_starts_with(lines[i], "```") == 0
        @if str_len(code_content) > 0 code_content = code_content + "\n" @end
        code_content = code_content + lines[i]
        i = i + 1
      @end
      blocks.push({ kind: 5, level: 0, content: code_content, items: [], lang: lang })
      i = i + 1
    @elif string_starts_with(line, "### ") == 1
      blocks.push({ kind: 1, level: 3, content: str_substr(line, 4, line_len), items: [], lang: "" })
      i = i + 1
    @elif string_starts_with(line, "## ") == 1
      blocks.push({ kind: 1, level: 2, content: str_substr(line, 3, line_len), items: [], lang: "" })
      i = i + 1
    @elif string_starts_with(line, "# ") == 1
      blocks.push({ kind: 1, level: 1, content: str_substr(line, 2, line_len), items: [], lang: "" })
      i = i + 1
    @elif string_starts_with(line, "> ") == 1
      blocks.push({ kind: 4, level: 0, content: str_substr(line, 2, line_len), items: [], lang: "" })
      i = i + 1
    @elif string_starts_with(line, "- ") == 1 || string_starts_with(line, "* ") == 1
      list_items = []
      @while i < num_lines && (string_starts_with(lines[i], "- ") == 1 || string_starts_with(lines[i], "* ") == 1)
        item_txt = str_substr(lines[i], 2, str_len(lines[i]))
        list_items.push(item_txt)
        i = i + 1
      @end
      blocks.push({ kind: 3, level: 0, content: "", items: list_items, lang: "" })
    @elif line_len > 0
      blocks.push({ kind: 2, level: 0, content: line, items: [], lang: "" })
      i = i + 1
    @else
      i = i + 1
    @end
  @end

  return blocks
@end

@fn render_doc_to_html(blocks)
  html = ""
  i = 0
  len = blocks.len()

  @while i < len
    b = blocks[i]
    @if b.kind == 1  @! Heading
      tag = "h" + int_to_str(b.level)
      html = html + "<" + tag + ">" + parse_inline_html(b.content) + "</" + tag + ">\n"
    @elif b.kind == 2  @! Paragraph
      html = html + "<p>" + parse_inline_html(b.content) + "</p>\n"
    @elif b.kind == 3  @! List
      html = html + "<ul>\n"
      j = 0
      @while j < b.items.len()
        html = html + "  <li>" + parse_inline_html(b.items[j]) + "</li>\n"
        j = j + 1
      @end
      html = html + "</ul>\n"
    @elif b.kind == 4  @! Blockquote
      html = html + "<blockquote>" + parse_inline_html(b.content) + "</blockquote>\n"
    @elif b.kind == 5  @! CodeBlock
      html = html + "<pre><code class=\"language-" + b.lang + "\">" + b.content + "</code></pre>\n"
    @end
    i = i + 1
  @end

  return html
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 8: Markdown Parser & HTML Renderer")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  doc = "# Maya Compiler\nA **sovereign** language engine.\n## Key Features\n- Zero libc dependencies\n- LLVM 18 backend\n- Self-hosted architecture\n> Maya represents self-sovereign computation.\n```maya\nprintln(\"Hello World\")\n```"

  blocks = parse_markdown_doc(doc)

  @! T4.8.1: Heading Level 1 and Level 2 Parsing
  total = total + 1
  b0 = blocks[0]
  b2 = blocks[2]

  @if b0.kind == 1 && b0.level == 1 && b0.content == "Maya Compiler" && b2.kind == 1 && b2.level == 2 && b2.content == "Key Features"
    passed = passed + 1
    println("  [PASS] T4.8.1: Headings parsed (H1: 'Maya Compiler', H2: 'Key Features')")
  @else
    failed = failed + 1
    println("  [FAIL] T4.8.1: Heading parsing failed")
  @end

  @! T4.8.2: Paragraph with Inline Strong Formatting
  total = total + 1
  b1 = blocks[1]
  inline_h = parse_inline_html(b1.content)

  @if b1.kind == 2 && inline_h == "A <strong>sovereign</strong> language engine."
    passed = passed + 1
    println("  [PASS] T4.8.2: Paragraph parsed and inline bold formatted to '<strong>sovereign</strong>'")
  @else
    failed = failed + 1
    println("  [FAIL] T4.8.2: Inline formatting failed: " + inline_h)
  @end

  @! T4.8.3: Unordered Bullet List Parsing (3 items)
  total = total + 1
  b3 = blocks[3]

  @if b3.kind == 3 && b3.items.len() == 3 && b3.items[0] == "Zero libc dependencies" && b3.items[2] == "Self-hosted architecture"
    passed = passed + 1
    println("  [PASS] T4.8.3: Unordered list parsed with exact 3 bullet items")
  @else
    failed = failed + 1
    println("  [FAIL] T4.8.3: List parsing failed")
  @end

  @! T4.8.4: Blockquote and Code Block Language/Content Extraction
  total = total + 1
  b4 = blocks[4]
  b5 = blocks[5]

  @if b4.kind == 4 && b4.content == "Maya represents self-sovereign computation." && b5.kind == 5 && b5.lang == "maya" && b5.content == "println(\"Hello World\")"
    passed = passed + 1
    println("  [PASS] T4.8.4: Blockquote and fenced code block (lang='maya', content='println(\"Hello World\")')")
  @else
    failed = failed + 1
    println("  [FAIL] T4.8.4: Blockquote/Code block failed")
  @end

  @! T4.8.5: Full Document HTML Rendering
  total = total + 1
  rendered_html = render_doc_to_html(blocks)

  @if string_starts_with(rendered_html, "<h1>Maya Compiler</h1>") == 1 && string_contains(rendered_html, "<pre><code class=\"language-maya\">") == 1
    passed = passed + 1
    println("  [PASS] T4.8.5: Full document rendered to standards-compliant HTML with tags (<h1>, <ul>, <blockquote>, <pre><code>)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.8.5: HTML rendering failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 8 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 8 (Markdown Parser & Renderer) PASSED")
    return 0
  @else
    println("✗ Scenario 8 (Markdown Parser & Renderer) FAILED")
    return 1
  @end
@end
