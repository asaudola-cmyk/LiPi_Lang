#!/usr/bin/env bash
set -e

fail_count=0
pass_count=0

for d in aati/*/; do
    pkg="${d%/}"
    echo -n "Checking $pkg... "
    if ./bin/aati verify "$pkg" > /tmp/pkg_verify.log 2>&1; then
        echo "PASS"
        pass_count=$((pass_count + 1))
    else
        echo "FAIL"
        tail -n 6 /tmp/pkg_verify.log
        fail_count=$((fail_count + 1))
    fi
done

echo "=========================================="
echo "Results: $pass_count PASS, $fail_count FAIL (Total: $((pass_count + fail_count)))"
echo "=========================================="
exit $fail_count
