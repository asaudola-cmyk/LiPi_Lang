#!/usr/bin/env bash
# ==============================================================================
# 📜 লিপি প্রি-প্রসেসর (Lipi Preprocessor)
# লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
# File: src/compiler/preprocessor.sh
#
# WHY এই script প্রয়োজন:
#   bin/lipic (C bootstrap) এ কিছু সীমাবদ্ধতা আছে:
#   - নাহলে_যদি chain কাজ করে না
#   - Template strings {variable} কাজ করে না
#   এই preprocessor সেগুলো fix করে তারপর lipic এ পাঠায়।
#
# ব্যবহার (Usage):
#   ./src/compiler/preprocessor.sh input.lp | ./bin/lipic /dev/stdin -o output
#   OR:
#   ./src/compiler/preprocessor.sh input.lp output_file
#
# WHY এটা temporary:
#   Compiler 2.0 সম্পূর্ণ হলে এই workaround আর দরকার হবে না।
# ==============================================================================

set -euo pipefail

LIPI_VERSION="প্রথম ১.০"
PREPROCESSOR_VERSION="1.0.0"

INPUT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

# ─── ইনপুট validation ──────────────────────────────────────────────────────
if [[ -z "$INPUT_FILE" ]]; then
    echo "❌ ব্যবহার: $0 <input.lp> [output_binary]" >&2
    echo "   উদাহরণ: $0 app.lp && ./app" >&2
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "❌ ফাইল পাওয়া যায়নি: $INPUT_FILE" >&2
    exit 1
fi

# Find lipic binary
LIPIC="${LIPIC:-./bin/lipic}"
if [[ ! -x "$LIPIC" ]]; then
    LIPIC="$(which lipic 2>/dev/null || true)"
    if [[ -z "$LIPIC" ]]; then
        echo "❌ lipic compiler পাওয়া যায়নি। PATH এ lipic যোগ করুন।" >&2
        exit 1
    fi
fi

# ─── STEP 1: নাহলে_যদি → nested নাহলে { যদি ... } ──────────────────────────
# WHY: lipic এ নাহলে_যদি কাজ করে না। প্রতিটি নাহলে_যদি কে
# নাহলে { যদি ... } এ রূপান্তর করতে হবে।
#
# Pattern: "} নাহলে_যদি CONDITION {"
# Replace: "} নাহলে {\n    যদি CONDITION {"
#
# NOTE: এই sed replacement simple single-line cases handle করে।
# Multi-condition complex patterns এর জন্য Compiler 2.0 দরকার।

preprocess_elif() {
    local file="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/lipi_preprocess_XXXXXX.lp)
    
    # Pass 1: নাহলে_যদি → নাহলে { যদি
    # WHY: We track depth to properly close the extra } at end
    python3 - "$file" "$tmpfile" << 'PYEOF'
import sys, re

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
output_lines = []
elif_depth = 0  # Track extra { from else-if conversion

i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    
    # Detect "} নাহলে_যদি CONDITION {"
    # Bengali: নাহলে_যদি = else-if
    if 'নাহলে_যদি' in line:
        # Find the leading whitespace
        leading = len(line) - len(line.lstrip())
        indent = ' ' * leading
        
        # Split on নাহলে_যদি
        # Pattern: } নাহলে_যদি COND {
        # Output:  } নাহলে {\n    যদি COND {
        
        # Replace নাহলে_যদি with নাহলে {\n<indent>    যদি
        new_line = line.replace('নাহলে_যদি', 'নাহলে {\n' + indent + '    যদি', 1)
        output_lines.append(new_line)
        elif_depth += 1
    else:
        # Check if this is a closing } that needs extra }
        output_lines.append(line)
    
    i += 1

# Write output
with open(output_file, 'w', encoding='utf-8') as f:
    f.write('\n'.join(output_lines))

print(f"  ✔ Preprocessor: নাহলে_যদি patterns converted", file=sys.stderr)
PYEOF

    echo "$tmpfile"
}

# ─── STEP 2: Template strings {variable} → concat ──────────────────────────
# WHY: lipic এ "স্বাগতম {নাম}!" কাজ করে না।
# এটাকে "স্বাগতম " + নাম + "!" এ রূপান্তর করতে হবে।
preprocess_templates() {
    local file="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/lipi_template_XXXXXX.lp)
    
    python3 - "$file" "$tmpfile" << 'PYEOF'
import sys, re

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r', encoding='utf-8') as f:
    content = f.read()

def replace_template(match):
    full_str = match.group(0)
    # Find {variable} patterns inside the string
    parts = re.split(r'\{(\w+)\}', full_str[1:-1])  # remove outer quotes
    if len(parts) == 1:
        return full_str  # no templates, return as-is
    
    # Build concat expression
    result_parts = []
    for j, part in enumerate(parts):
        if j % 2 == 0:  # literal string part
            if part:
                result_parts.append(f'"{part}"')
        else:  # variable name
            result_parts.append(part)
    
    return ' + '.join(result_parts)

# Only process strings that contain {identifier} pattern
processed = re.sub(r'"[^"]*\{[a-zA-Z\u0980-\u09FF_][a-zA-Z0-9\u0980-\u09FF_]*\}[^"]*"',
                   replace_template, content)

with open(output_file, 'w', encoding='utf-8') as f:
    f.write(processed)

print("  ✔ Preprocessor: template strings converted", file=sys.stderr)
PYEOF

    echo "$tmpfile"
}

# ─── STEP 3: Warnings for unsupported syntax ────────────────────────────────
check_unsupported() {
    local file="$1"
    local warned=0
    
    # Check for array of objects (known segfault)
    if grep -qP '\[\s*\{' "$file" 2>/dev/null; then
        echo "  ⚠️  সতর্কতা: Array of objects [{...}] segfault করতে পারে।" >&2
        echo "     বিকল্প: প্রতিটি field এর জন্য আলাদা variable ব্যবহার করুন।" >&2
        warned=1
    fi
    
    # Check for প্রতিটি ... ভেতরে (for-each)
    if grep -qP 'প্রতিটি\s+\w+\s+ভেতরে' "$file" 2>/dev/null; then
        echo "  ⚠️  সতর্কতা: প্রতিটি...ভেতরে segfault করতে পারে।" >&2
        echo "     বিকল্প: যতক্ষণ loop ব্যবহার করুন।" >&2
        warned=1
    fi
    
    # Check for চেষ্টা...ধরো
    if grep -qP 'চেষ্টা\s*\{' "$file" 2>/dev/null; then
        echo "  ⚠️  সতর্কতা: চেষ্টা...ধরো বর্তমানে সমর্থিত নয়।" >&2
        echo "     বিকল্প: Guard clause (যদি error_condition { ফেরত -১ }) ব্যবহার করুন।" >&2
        warned=1
    fi
    
    return $warned
}

# ─── MAIN PIPELINE ──────────────────────────────────────────────────────────
echo "🔧 লিপি প্রি-প্রসেসর ($LIPI_VERSION) — প্রক্রিয়াকরণ শুরু: $INPUT_FILE" >&2

# Step 1: elif conversion
PROCESSED=$(preprocess_elif "$INPUT_FILE")

# Step 2: template strings
PROCESSED2=$(preprocess_templates "$PROCESSED")
rm -f "$PROCESSED"

# Step 3: warnings
check_unsupported "$PROCESSED2" || true

# Step 4: Compile
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "  ⚙️  কম্পাইল করা হচ্ছে: $INPUT_FILE → $OUTPUT_FILE" >&2
    "$LIPIC" "$PROCESSED2" -o "$OUTPUT_FILE"
    COMPILE_EXIT=$?
    rm -f "$PROCESSED2"
    
    if [[ $COMPILE_EXIT -eq 0 ]]; then
        echo "  ✅ সফলভাবে কম্পাইল হয়েছে: $OUTPUT_FILE" >&2
    else
        echo "  ❌ কম্পাইল ব্যর্থ (exit: $COMPILE_EXIT)" >&2
        exit $COMPILE_EXIT
    fi
else
    # Output to stdout for piping
    cat "$PROCESSED2"
    rm -f "$PROCESSED2"
fi
