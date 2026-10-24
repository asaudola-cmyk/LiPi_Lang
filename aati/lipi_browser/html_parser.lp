// ==============================================================================
// 👑 LIPI SOVEREIGN WEB BROWSER: STREAMING HTML5 TOKENIZER & DOM SYNTHESIZER
// ⚡ Module: aati/lipi_browser/html_parser.lp
// 🏛️ Architecture: Zero-C, Zero-WebKit, Zero-Blink Pure LiPi DOM Engine
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/memory.lp"
include "utso/string.lp"

// ── 1. DOM Node Types & Structures ───────────────────────────────────────────

DOM_NODE_ELEMENT = 1
DOM_NODE_TEXT    = 2
DOM_NODE_COMMENT = 3
DOM_NODE_ROOT    = 4

struct BrowserDOMNode
    dom_node_type
    dom_tag
    dom_id
    dom_class_name
    dom_style_attr
    dom_text_content
    dom_children
    dom_parent

fn browser_dom_node_new node_type tag text
    node = BrowserDOMNode()
    node.dom_node_type = node_type
    node.dom_tag = tag
    node.dom_id = ""
    node.dom_class_name = ""
    node.dom_style_attr = ""
    node.dom_text_content = text
    node.dom_children = list()
    node.dom_parent = 0
    return node

fn browser_dom_append_child parent child
    if parent == 0 or child == 0 return 0 end
    push(parent.dom_children, child)
    child.dom_parent = parent
    return 1

// ── 2. Void Tags & Character Entities ─────────────────────────────────────────

fn html_is_void_tag tag
    t = str_to_lower(tag)
    if t == "area" or t == "base" or t == "br" or t == "col" or t == "embed" or t == "hr" or t == "img" or t == "input" or t == "link" or t == "meta" or t == "param" or t == "source" or t == "track" or t == "wbr"
        return 1
    end
    return 0

fn html_decode_entities raw_str
    s = raw_str
    s = str_replace(s, "&nbsp;", " ")
    s = str_replace(s, "&lt;", "<")
    s = str_replace(s, "&gt;", ">")
    s = str_replace(s, "&amp;", "&")
    s = str_replace(s, "&quot;", "\"")
    return s

// ── 3. Tag & Attribute Tokenization ───────────────────────────────────────────

fn html_parse_attributes tag_content node
    // Parses attributes from e.g. 'div id="main" class="container card" style="color: red;"'
    s_len = len(tag_content)
    i = 0
    // Skip tag name
    while i < s_len and char_at(tag_content, i) != " " and char_at(tag_content, i) != "\t" and char_at(tag_content, i) != "\n"
        i = i + 1
    end

    while i < s_len
        // Skip leading whitespace
        while i < s_len and (char_at(tag_content, i) == " " or char_at(tag_content, i) == "\t" or char_at(tag_content, i) == "\n")
            i = i + 1
        end
        if i >= s_len break end

        // Parse attribute name
        attr_name = ""
        while i < s_len and char_at(tag_content, i) != "=" and char_at(tag_content, i) != " " and char_at(tag_content, i) != "/" and char_at(tag_content, i) != ">"
            attr_name = attr_name + char_at(tag_content, i)
            i = i + 1
        end

        // Skip whitespace around '='
        while i < s_len and (char_at(tag_content, i) == " " or char_at(tag_content, i) == "\t")
            i = i + 1
        end

        attr_val = ""
        if i < s_len and char_at(tag_content, i) == "="
            i = i + 1
            while i < s_len and (char_at(tag_content, i) == " " or char_at(tag_content, i) == "\t")
                i = i + 1
            end
            if i < s_len
                q = char_at(tag_content, i)
                if q == "\"" or q == "'"
                    i = i + 1
                    while i < s_len and char_at(tag_content, i) != q
                        attr_val = attr_val + char_at(tag_content, i)
                        i = i + 1
                    end
                    if i < s_len i = i + 1 end
                else
                    // Unquoted attribute value
                    while i < s_len and char_at(tag_content, i) != " " and char_at(tag_content, i) != "\t" and char_at(tag_content, i) != ">" and char_at(tag_content, i) != "/"
                        attr_val = attr_val + char_at(tag_content, i)
                        i = i + 1
                    end
                end
            end
        end

        // Assign known DOM attributes
        attr_l = str_to_lower(attr_name)
        if attr_l == "id"
            node.dom_id = attr_val
        elif attr_l == "class"
            node.dom_class_name = attr_val
        elif attr_l == "style"
            node.dom_style_attr = attr_val
        end
    end
    return 1

// ── 4. Streaming HTML Parser & DOM Construction ───────────────────────────────

fn html_parse_document html_str
    root = browser_dom_node_new(DOM_NODE_ROOT, "root", "")
    current_parent = root
    s_len = len(html_str)
    i = 0

    while i < s_len
        ch = char_at(html_str, i)

        if ch == "<"
            // Check if comment: <!-- ... -->
            if i + 3 < s_len and char_at(html_str, i + 1) == "!" and char_at(html_str, i + 2) == "-" and char_at(html_str, i + 3) == "-"
                i = i + 4
                while i + 2 < s_len and not (char_at(html_str, i) == "-" and char_at(html_str, i + 1) == "-" and char_at(html_str, i + 2) == ">")
                    i = i + 1
                end
                i = i + 3
            elif i + 1 < s_len and char_at(html_str, i + 1) == "/"
                // End tag: </tag>
                i = i + 2
                end_tag = ""
                while i < s_len and char_at(html_str, i) != ">"
                    if char_at(html_str, i) != " " and char_at(html_str, i) != "\t"
                        end_tag = end_tag + char_at(html_str, i)
                    end
                    i = i + 1
                end
                if i < s_len i = i + 1 end

                // Ascend to parent in DOM tree
                if current_parent != 0 and current_parent.dom_parent != 0
                    current_parent = current_parent.dom_parent
                end
            else
                // Start tag or self-closing tag: <tag attrs...>
                i = i + 1
                tag_content = ""
                while i < s_len and char_at(html_str, i) != ">"
                    tag_content = tag_content + char_at(html_str, i)
                    i = i + 1
                end
                if i < s_len i = i + 1 end

                is_self_closing = 0
                tc_len = len(tag_content)
                if tc_len > 0 and char_at(tag_content, tc_len - 1) == "/"
                    is_self_closing = 1
                    tag_content = str_slice(tag_content, 0, tc_len - 1)
                end

                // Extract tag name
                tag_name = ""
                k = 0
                while k < len(tag_content) and char_at(tag_content, k) != " " and char_at(tag_content, k) != "\t"
                    tag_name = tag_name + char_at(tag_content, k)
                    k = k + 1
                end
                tag_name = str_to_lower(tag_name)

                // Ignore DOCTYPE
                if tag_name != "!doctype" and len(tag_name) > 0
                    elem_node = browser_dom_node_new(DOM_NODE_ELEMENT, tag_name, "")
                    html_parse_attributes(tag_content, elem_node)
                    browser_dom_append_child(current_parent, elem_node)

                    if html_is_void_tag(tag_name) == 0 and is_self_closing == 0
                        // For <style> or <script>, read raw body until </style>
                        if tag_name == "style" or tag_name == "script"
                            raw_body = ""
                            close_marker = "</" + tag_name + ">"
                            m_len = len(close_marker)
                            while i < s_len
                                if i + m_len <= s_len and str_to_lower(str_slice(html_str, i, i + m_len)) == close_marker
                                    i = i + m_len
                                    break
                                end
                                raw_body = raw_body + char_at(html_str, i)
                                i = i + 1
                            end
                            elem_node.dom_text_content = raw_body
                        else
                            current_parent = elem_node
                        end
                    end
                end
            end
        else
            // Text node accumulation
            text_buf = ""
            while i < s_len and char_at(html_str, i) != "<"
                text_buf = text_buf + char_at(html_str, i)
                i = i + 1
            end

            decoded = html_decode_entities(text_buf)
            // Trim leading/trailing whitespace checks
            trimmed = str_trim(decoded)
            if len(trimmed) > 0
                text_node = browser_dom_node_new(DOM_NODE_TEXT, "text", decoded)
                browser_dom_append_child(current_parent, text_node)
            end
        end
    end

    return root

// ── 5. DOM Query Traversal Primitives ─────────────────────────────────────────

fn html_find_by_id root target_id
    if root == 0 return 0 end
    if root.dom_id == target_id return root end
    c_idx = 0
    while c_idx < len(root.dom_children)
        child = root.dom_children[c_idx]
        found = html_find_by_id(child, target_id)
        if found != 0 return found end
        c_idx = c_idx + 1
    end
    return 0

fn html_collect_by_tag root target_tag result_list
    if root == 0 return 0 end
    if root.dom_tag == target_tag
        push(result_list, root)
    end
    c_idx = 0
    while c_idx < len(root.dom_children)
        html_collect_by_tag(root.dom_children[c_idx], target_tag, result_list)
        c_idx = c_idx + 1
    end
    return len(result_list)
