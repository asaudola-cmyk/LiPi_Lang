#!/usr/bin/env python3
# ==============================================================================
# 🛡️ LIPI ADVANCED NETWORK & PROTOCOL ATTACK PENETRATION SUITE
# WHY: Simulates 10 distinct classes of network attacks against Lipi Web Server:
# TCP Connection Floods, Slowloris, RUDY Slow-POST, Buffer/Header Overflows,
# Raw Binary & TLS Fuzzing, HTTP Smuggling, Concurrency Spikes, and DB Fuzzing.
# ==============================================================================

import socket
import time
import subprocess
import os
import sys
import threading
import urllib.request
import urllib.error

TEST_PORT = 8099
SERVER_BIN = "apps/website/lipi_server"
TARGET_HOST = "127.0.0.1"

# ANSI Colors
CYAN = "\033[38;2;0;255;204m"
GREEN = "\033[1;32m"
YELLOW = "\033[1;33m"
RED = "\033[1;31m"
NC = "\033[0m"
BOLD = "\033[1m"

def log_header(title):
    print(f"\n{BOLD}▶ {title}{NC}")

def send_raw(payload, timeout=2.0):
    """Opens raw TCP socket, sends payload, and returns response bytes."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect((TARGET_HOST, TEST_PORT))
        s.sendall(payload)
        resp = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            resp += chunk
        s.close()
        return resp
    except Exception as e:
        s.close()
        return f"ERROR: {e}".encode()

def main():
    print(f"{CYAN}╔════════════════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║  🛡️ LIPI ADVANCED NETWORK ATTACK & EXPLOIT PENETRATION SUITE           ║{NC}")
    print(f"{CYAN}║  ⚡ 10 Comprehensive Network Attack Classes | Empirical Resilience     ║{NC}")
    print(f"{CYAN}╚════════════════════════════════════════════════════════════════════════╝{NC}\n")

    # 1. Compile server binary if needed
    print(f"{YELLOW}[প্রস্তুতি] সার্ভার বাইনারি সংকলন করা হচ্ছে...{NC}")
    subprocess.run(["./bin/lipc", "apps/website/server.lp", "-o", SERVER_BIN], check=True, stdout=subprocess.DEVNULL)

    # Free test port
    subprocess.run(["fuser", "-k", f"{TEST_PORT}/tcp"], stderr=subprocess.DEVNULL)
    time.sleep(0.3)

    # 2. Launch server process
    print(f"{YELLOW}[ধাপ ০] টেস্ট সার্ভার শুরু করা হচ্ছে (Port: {TEST_PORT})...{NC}")
    server_proc = subprocess.Popen([SERVER_BIN, str(TEST_PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.8)

    # Verify server is responding
    try:
        req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
        if req.status != 200:
            print(f"{RED}❌ সার্ভার স্টার্ট হতে ব্যর্থ হয়েছে!{NC}")
            server_proc.kill()
            sys.exit(1)
    except Exception as ex:
        print(f"{RED}❌ সার্ভার কানেকশন এরর: {ex}{NC}")
        server_proc.kill()
        sys.exit(1)

    print(f"{GREEN}✔ সার্ভার সচল ও পেন-টেস্টিংয়ের জন্য প্রস্তুত।{NC}\n")

    findings = []
    passes = []

    try:
        # ======================================================================
        # ATTACK 1: Rapid TCP Connect / Disconnect Flood (SYN/RST flood simulation)
        # ======================================================================
        log_header("অ্যাটাক ১: Rapid TCP Connection Flood (১০০টি তাৎক্ষণিক কানেকশন)")
        flood_errors = 0
        t0 = time.time()
        for i in range(100):
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(0.5)
                s.connect((TARGET_HOST, TEST_PORT))
                s.close()
            except Exception:
                flood_errors += 1
        t_flood = time.time() - t0

        # Test if server is still alive
        alive = True
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
            if req.status != 200: alive = False
        except Exception:
            alive = False

        if alive and flood_errors == 0:
            print(f"  {GREEN}✔ PASS: ১০০টি কানেকশন সফলভাবে হ্যান্ডেলড ({t_flood:.3f}s), সার্ভার অক্ষত।{NC}")
            passes.append("Rapid TCP Connect Flood Resilient")
        else:
            print(f"  {RED}❌ FAIL: কানেকশন ফ্লাডে সার্ভার ব্যহত (ব্যর্থ কানেকশন: {flood_errors}, এলাইভ: {alive}){NC}")
            findings.append(("HIGH", "Rapid TCP Connection Exhaustion", "সার্ভার দ্রুত কানেকশন সাইকেলে ড্রপ করতে পারে"))

        # ======================================================================
        # ATTACK 2: Slowloris Attack (Partial Headers with High Delay)
        # ======================================================================
        log_header("অ্যাটাক ২: Slowloris Attack (অসম্পূর্ণ হেডার পাঠিয়ে সকেট ঝুলিয়ে রাখা)")
        slow_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        slow_sock.connect((TARGET_HOST, TEST_PORT))
        slow_sock.sendall(b"GET / HTTP/1.1\r\nHost: localhost\r\nUser-Agent: Slowloris\r\n")
        
        # While slowloris socket is hanging, attempt concurrent request
        time.sleep(0.1)
        conc_start = time.time()
        conc_success = False
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/api/status", timeout=2)
            if req.status == 200:
                conc_success = True
        except Exception:
            conc_success = False
        conc_latency = (time.time() - conc_start) * 1000
        slow_sock.close()

        if conc_success:
            print(f"  {GREEN}✔ PASS: স্লোলোরিস অ্যাটাকের মুখেও কনকারেন্ট রিকোয়েস্ট সফল ({conc_latency:.1f}ms latency)।{NC}")
            passes.append("Slowloris Attack Resilient")
        else:
            print(f"  {RED}❌ FAIL: স্লোলোরিস কানেকশনের কারণে অন্যান্য কনকারেন্ট রিকোয়েস্ট ব্লকড!{NC}")
            findings.append(("HIGH", "Slowloris Starvation Vulnerability", "অসম্পূর্ণ রিকোয়েস্ট অন্যান্য ক্লায়েন্টকে ব্লক করে"))

        # ======================================================================
        # ATTACK 3: Slow POST (R-U-Dead-Yet / RUDY) Attack
        # ======================================================================
        log_header("অ্যাটাক ৩: RUDY Slow POST Attack (বড় Content-Length কিন্তু ডেটা না পাঠানো)")
        rudy_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        rudy_sock.connect((TARGET_HOST, TEST_PORT))
        # Claim 10,000 bytes but only send 10 bytes and stall
        rudy_sock.sendall(b"POST /api/run HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10000\r\nContent-Type: application/json\r\n\r\n{\"code\":")
        time.sleep(0.1)
        
        rudy_conc_ok = False
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
            if req.status == 200:
                rudy_conc_ok = True
        except Exception:
            rudy_conc_ok = False
        rudy_sock.close()

        if rudy_conc_ok:
            print(f"  {GREEN}✔ PASS: স্লো পোস্ট চলাকালেও সার্ভার স্বাভাবিকভাবে সাড়াদান করেছে।{NC}")
            passes.append("Slow POST (RUDY) Resilient")
        else:
            print(f"  {RED}❌ FAIL: স্লো পোস্টের কারণে সার্ভার হ্যাং হয়েছে!{NC}")
            findings.append(("MEDIUM", "Slow POST Blocking", "অসম্পূর্ণ POST বডি সার্ভার ড্রপ করেনি"))

        # ======================================================================
        # ATTACK 4: Massive Buffer & Header Overflow Bombing (100KB Header)
        # ======================================================================
        log_header("অ্যাটাক ৪: Massive Buffer & Header Bombing (১০০,০০০ বাইট হেডার বোম্ব)")
        huge_header = b"GET / HTTP/1.1\r\nHost: localhost\r\n" + (b"X-Bomb: " + (b"A" * 90000) + b"\r\n\r\n")
        resp_bomb = send_raw(huge_header, timeout=3.0)

        # Verify server didn't crash
        crash = False
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
            if req.status != 200: crash = True
        except Exception:
            crash = True

        if not crash:
            print(f"  {GREEN}✔ PASS: ১০০KB বাফার বোম্বিংয়ে সার্ভার ক্র্যাশ করেনি, স্বাভাবিকভাবে ড্রপ করেছে।{NC}")
            passes.append("Buffer Overflow / Header Bomb Resilient")
        else:
            print(f"  {RED}❌ FAIL: বাফার বোম্বিংয়ে সার্ভার ক্র্যাশ বা ফ্রিজ করেছে!{NC}")
            findings.append(("CRITICAL", "Buffer Bomb Denial of Service", "বড় পেলোড সার্ভার ক্র্যাশ করেছে"))

        # ======================================================================
        # ATTACK 5: Raw Binary Fuzzing & TLS Handshake to Plaintext Port
        # ======================================================================
        log_header("অ্যাটাক ৫: Raw Binary Fuzzing & TLS ClientHello on Plaintext HTTP")
        # SSLv3 / TLS 1.2 ClientHello header simulation
        tls_hello = b"\x16\x03\x01\x00\x55\x01\x00\x00\x51\x03\x03" + (os.urandom(32)) + b"\x00\x00\x04\x00\x2f\x00\x35"
        resp_tls = send_raw(tls_hello, timeout=2.0)

        # Random garbage bytes
        garbage = os.urandom(1024)
        resp_garbage = send_raw(garbage, timeout=2.0)

        # Check server health
        survived = True
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
            if req.status != 200: survived = False
        except Exception:
            survived = False

        if survived:
            print(f"  {GREEN}✔ PASS: TLS হ্যান্ডশেক ও রেন্ডম বাইনারি ফাজিংয়ে কোনো মেমরি ফল্ট বা ক্র্যাশ হয়নি।{NC}")
            passes.append("Binary & TLS Fuzzing Resilient")
        else:
            print(f"  {RED}❌ FAIL: বাইনারি ফাজিংয়ে সার্ভার ক্ষতিগ্রস্ত হয়েছে!{NC}")
            findings.append(("HIGH", "Binary Stream Crash", "নন-টেক্সট বাইনারি স্ট্রিমে সার্ভার ক্র্যাশ করেছে"))

        # ======================================================================
        # ATTACK 6: Null-Byte Injection & URI Poisoning
        # ======================================================================
        log_header("অ্যাটাক ৬: Null-Byte Injection & URL Poisoning (%00 / \\0)")
        null_payload = b"GET /style.css\x00.php HTTP/1.1\r\nHost: localhost\r\n\r\n"
        resp_null = send_raw(null_payload, timeout=2.0)

        if b"root:" not in resp_null and b"500 Internal" not in resp_null:
            print(f"  {GREEN}✔ PASS: নাল-বাইট ইনজেকশন হ্যান্ডলিং সুরক্ষিত (কোনো ফাইল লিক বা ফল্ট নেই)।{NC}")
            passes.append("Null-Byte Injection Safe")
        else:
            print(f"  {RED}❌ FAIL: নাল-বাইট ইনজেকশনে অপ্রত্যাশিত রেসপন্স!{NC}")
            findings.append(("MEDIUM", "Null Byte Handling", "নাল বাইট প্রসেসিংয়ে সমস্যা"))

        # ======================================================================
        # ATTACK 7: High-Concurrency Burst Pressure (৫০টি প্যারালাল থ্রেড)
        # ======================================================================
        log_header("অ্যাটাক ৭: Concurrency Burst Pressure (৫০টি কনকারেন্ট রিকোয়েস্ট)")
        burst_success = 0
        burst_errors = 0
        lock = threading.Lock()

        def worker():
            nonlocal burst_success, burst_errors
            try:
                r = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/api/status", timeout=3)
                if r.status == 200:
                    with lock: burst_success += 1
                else:
                    with lock: burst_errors += 1
            except Exception:
                with lock: burst_errors += 1

        threads = [threading.Thread(target=worker) for _ in range(50)]
        t_burst_start = time.time()
        for t in threads: t.start()
        for t in threads: t.join()
        t_burst = time.time() - t_burst_start

        rate = burst_success / t_burst if t_burst > 0 else 0
        print(f"  • সফল: {GREEN}{burst_success}{NC} / ৫০ | ব্যর্থ: {RED if burst_errors > 0 else GREEN}{burst_errors}{NC} | সময়: {t_burst:.3f}s ({rate:.1f} req/s)")

        if burst_errors == 0:
            print(f"  {GREEN}✔ PASS: কনকারেন্ট বার্স্ট ১০০% সফলভাবে পরিবেশিত।{NC}")
            passes.append("High-Concurrency Burst Resilient")
        else:
            print(f"  {YELLOW}⚠️ WARNING: {burst_errors}টি রিকোয়েস্ট ড্রপ হয়েছে (সিঙ্গেল-থ্রেডেড প্রসেসিং সীমা)।{NC}")
            findings.append(("LOW", "Concurrency Pressure Drops", f"৫০টি কনকারেন্ট রিকোয়েস্টে {burst_errors}টি ড্রপ হয়েছে"))

        # ======================================================================
        # ATTACK 8: Malformed HTTP Methods & Protocol Version Fuzzing
        # ======================================================================
        log_header("অ্যাটাক ৮: Malformed HTTP Methods & Protocol Fuzzing")
        fuzz_methods = [
            b"HACK / HTTP/1.1\r\nHost: localhost\r\n\r\n",
            b"PROPFIND /webdav HTTP/1.1\r\nHost: localhost\r\n\r\n",
            b"GET\r\n\r\n",
            b"FOOBARBAZQUX / HTTP/9.9\r\nHost: localhost\r\n\r\n",
            b"TRACK / HTTP/1.1\r\nHost: localhost\r\n\r\n",
            b"DEBUG / HTTP/1.1\r\nHost: localhost\r\n\r\n",
        ]
        all_handled = True
        for m in fuzz_methods:
            res = send_raw(m, timeout=1.5)
            # Should return 404, 400, or gracefully close
            if not res and b"ERROR" in res:
                all_handled = False

        # Verify server is still healthy
        try:
            req = urllib.request.urlopen(f"http://{TARGET_HOST}:{TEST_PORT}/healthz", timeout=2)
            if req.status != 200: all_handled = False
        except Exception:
            all_handled = False

        if all_handled:
            print(f"  {GREEN}✔ PASS: ম্যালফর্মড মেথড ও প্রোটোকল ফাজিংয়ে সার্ভার নিরাপদ।{NC}")
            passes.append("Malformed Methods / Protocol Resilient")
        else:
            print(f"  {RED}❌ FAIL: ম্যালফর্মড মেথডে সার্ভার ক্র্যাশ বা হ্যাং করেছে!{NC}")
            findings.append(("MEDIUM", "Method Fuzzing Instability", "অস্বাভাবিক মেথডে সার্ভার আনরেস্পন্সিভ"))

        # ======================================================================
        # ATTACK 9: Database API Boundary & Format String Fuzzing
        # ======================================================================
        log_header("অ্যাটাক ৯: Database API Boundary, Overflow & Format String Fuzzing")
        db_attacks = [
            "/api/db/add?val=-99999999999999999999999999",
            "/api/db/add?val=NaN",
            "/api/db/add?val=%s%s%s%n%x",
            "/api/db/delete?id=-999",
            "/api/db/delete?id=99999999999999",
            "/api/db/delete?id=abc'OR'1'='1",
            "/api/db/update?id=1&val=%00",
            "/api/db/update?id=-1&val=500",
            "/api/db/update?id=1&val=-500"
        ]
        db_fuzz_ok = True
        for endpoint in db_attacks:
            try:
                url = f"http://{TARGET_HOST}:{TEST_PORT}{endpoint}"
                req = urllib.request.Request(url, method="POST")
                with urllib.request.urlopen(req, timeout=2) as r:
                    body = r.read().decode()
            except urllib.error.HTTPError as he:
                pass
            except Exception:
                db_fuzz_ok = False

        # Verify DB integrity
        db_size = os.path.getsize("apps/website/data/sovereign_store.db")
        if db_fuzz_ok and db_size <= 256:
            print(f"  {GREEN}✔ PASS: ডাটাবেজ ফাজিং সফলভাবে হ্যান্ডেলড (ফাইল সাইজ: {db_size}B, কোনো করাপশন নেই)।{NC}")
            passes.append("Database API Fuzzing Safe")
        else:
            print(f"  {RED}❌ FAIL: ডাটাবেজ ফাজিংয়ে মেমরি বা ফাইল সাইজ করাপশন হয়েছে (সাইজ: {db_size}B)!{NC}")
            findings.append(("HIGH", "Database Fuzzing Corruption", "নেগেটিভ বা ওভারফ্লো ইনপুটে ডাটাবেজ অস্বাভাবিক আচরণ করেছে"))

        # ======================================================================
        # ATTACK 10: Sandbox Evasion & Syscall Obfuscation Testing
        # ======================================================================
        log_header("অ্যাটাক ১০: Sandbox Bypass & Syscall Obfuscation Attempt")
        evasion_payloads = [
            '{"code": "say \\"syscall(1, 1, 0, 0)\\""}', # Literal string containing syscall in say
            '{"code": "syscall (2, \\"/etc/passwd\\", 0)"}', # Syscall with space
            '{"code": "sys"+"call(2, \\"/etc/passwd\\", 0)"}',
            '{"code": "include \\"//etc//passwd\\""}',
            '{"code": "include \\"../server.lp\\""}'
        ]
        evasion_blocked = True
        for pl in evasion_payloads:
            try:
                url = f"http://{TARGET_HOST}:{TEST_PORT}/api/run"
                req = urllib.request.Request(url, data=pl.encode(), headers={"Content-Type": "application/json"}, method="POST")
                with urllib.request.urlopen(req, timeout=2) as r:
                    resp_data = r.read().decode()
                    # If it executed a raw syscall to /etc/passwd without error, that's an evasion
                    if "SYS_OPEN" in resp_data or "root:" in resp_data:
                        evasion_blocked = False
            except urllib.error.HTTPError:
                pass
            except Exception:
                pass

        if evasion_blocked:
            print(f"  {GREEN}✔ PASS: স্যান্ডবক্স ইভেশন ও বাইপাস চেষ্টা সফলভাবে প্রতিহত।{NC}")
            passes.append("Sandbox Evasion Mitigation Safe")
        else:
            print(f"  {RED}❌ FAIL: স্যান্ডবক্স অবফাসকেশনে বাইপাস সম্ভব হয়েছে!{NC}")
            findings.append(("CRITICAL", "Sandbox Syscall Evasion", "অবফাসকেটেড সিসকল স্যান্ডবক্স পার্সার এড়িয়ে গেছে"))

    finally:
        print(f"\n{YELLOW}[ক্লিনআপ] টেস্ট সার্ভার প্রসেস বন্ধ করা হচ্ছে...{NC}")
        server_proc.kill()
        subprocess.run(["fuser", "-k", f"{TEST_PORT}/tcp"], stderr=subprocess.DEVNULL)
        time.sleep(0.3)

    # Summary Report
    print(f"\n{CYAN}╔════════════════════════════════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║  📊 অ্যাডভান্সড নেটওয়ার্ক অ্যাটাক টেস্ট সারাংশ                         ║{NC}")
    print(f"{CYAN}╚════════════════════════════════════════════════════════════════════════╝{NC}")
    print(f"  • সফলভাবে প্রতিহত অ্যাটাক সংখ্যা: {GREEN}{len(passes)}{NC} / 10")
    print(f"  • সনাক্তকৃত সম্ভাব্য সমস্যা / উইকনেস: {RED if findings else GREEN}{len(findings)}{NC}\n")

    for sev, name, desc in findings:
        color = RED if sev in ["CRITICAL", "HIGH"] else YELLOW
        print(f"  [{color}{sev}{NC}] {name}: {desc}")

    if not findings:
        print(f"  {GREEN}🎉 অভিনন্দন! সার্ভারটি সকল ১০টি নেটওয়ার্ক ও প্রোটোকল অ্যাটাকে শতভাগ রেজিলিয়েন্ট!{NC}")

if __name__ == "__main__":
    main()
