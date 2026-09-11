# Original User Request

## Initial Request — 2026-09-02T03:24:31+06:00

You are the Project Orchestrator for the 'Maya is Maya' sovereign compiler project.

Workspace Root: /home/shafiullah/Documents/file/maya
Your Working Directory: /home/shafiullah/Documents/file/maya/.agents/teamwork_preview_orchestrator_sovereign
Authoritative Request: /home/shafiullah/Documents/file/maya/ORIGINAL_REQUEST.md

Mission:
Implement the "Maya is Maya" masterplan to make the language truly infinite and sovereign. Eradicate all hidden C dependencies, implement a direct Native Machine Code (ELF) emitter, rewrite the GC in pure Maya, and bypass the OS entirely using direct Syscalls.
User explicit directive: "Use a very large team of agents."

Requirements:
R1. Native Machine Code Emitter (Zero C-Generation):
Maya must never generate intermediate `.c` files or invoke external compilers like GCC or Clang. Implement a custom backend in the Maya compiler that directly emits raw machine code (010101) and valid ELF executables.
R2. Pure Maya Garbage Collector:
Permanently delete any remaining traces of `runtime/maya_gc.c`. Implement the entire Garbage Collector and memory management engine directly in Maya itself (`runtime/maya_gc.maya`).
R3. Operating System Bypass (Direct Syscalls):
Remove all dependencies on OS-level C libraries (like `libc`). Maya must directly generate raw Assembly Instructions and execute raw Syscalls for all system interactions (I/O, threading, memory allocation).

Acceptance Criteria:
- Compiling a Maya program does not invoke `gcc`, `clang`, or any external build tool, and leaves no `.c` or `.o` artifacts behind.
- The compiler outputs a fully executable raw ELF file directly from Maya source code.
- `runtime/maya_gc.c` is completely absent from the codebase, and memory is managed by `maya_gc.maya`.
- `ldd` (or equivalent) on a compiled Maya binary shows absolutely zero dynamically linked libraries (100% statically linked, freestanding).
- [ ] A system trace (`strace`) confirms the binary uses raw OS syscalls directly rather than standard library wrappers.

## Follow-up — 2026-09-02T03:26:02+06:00

Deploy a dedicated team to hunt down all backend dependencies and rewrite them in Pure Maya. Spawn a specialized 'Backend Dependency Hunter Squad' whose sole purpose is to rigidly audit the entire backend, find ANY hidden external dependencies (C libs, OS calls, external tooling), and reimplement them strictly in Pure Maya.

Please decompose this project into parallel workstreams, dispatch specialist subagents (explorers, workers, reviewers, challengers, test writers), maintain plan.md, progress.md, and BRIEFING.md in your working directory (/home/shafiullah/Documents/file/maya/.agents/teamwork_preview_orchestrator_sovereign), verify all requirements with rigorous testing, and deliver a comprehensive handoff.md upon completion.

## Follow-up — 2026-09-02T03:40:34+06:00

Implement the "Maya Infinity Paradigm & Reverse Dependency" feature. The user's vision is that Maya relies on NO ONE, but other languages (even C) must rely on Maya. Maya makes its own rules, goes in the opposite direction of standard programming, and acts as an infinite universe.
    
Working directory: `/home/shafiullah/Documents/file/maya`
Integrity mode: benchmark

## Requirements

### R1. Reverse C-Dependency (C relies on Maya)
Create an export pipeline (`universe/export/c_api.maya`) that compiles Maya's core memory engine (GC) and advanced libraries into a static freestanding library (`libmaya_core.a`) along with auto-generated C headers (`maya.h`). C developers will now be forced to link against Maya to get advanced functionality (proving that C needs Maya, not the other way around).

### R2. Rule-less Infinite Metaprogramming
Implement a dynamic rule engine in the pure Maya compiler (`compiler/infinity_syntax.maya`) that allows Maya to redefine its own syntax rules and grammar dynamically at compile time (breaking standard programming paradigms). Maya makes its own rules.

## Acceptance Criteria
### Reverse Dependency Validation
- [ ] `libmaya_core.a` and `maya.h` are generated purely by the native Maya compiler.
- [ ] A test C program (`tests/c_depends_on_maya.c`) successfully compiles using `gcc tests/c_depends_on_maya.c -L. -lmaya_core` and successfully executes Maya's pure GC and math functions.

### Infinity Syntax Validation
- [ ] The Maya compiler successfully compiles a Maya script that fundamentally redefines a core syntax rule on the fly using the new rule engine.

## Follow-up — 2026-09-02T03:41:01+06:00

The user is going to sleep and has handed over full control for the night. You must work continuously. Absolute mandate: Maya is infinite, it has no rules, it makes its own rules. It must not depend on C; rather, make architectural decisions that would force C to depend on Maya. Eradicate all norms that tie Maya to traditional execution models. Spawn as many internal workers as you need.

## Follow-up — 2026-09-02T14:27:27+06:00

Project Exodus (Maya OS Kernel & Bootloader): Build a bare-metal OS kernel entirely in pure Maya (no C/Assembly wrappers). 
Working directory: `universe/os/`
Requirements:
1. Create `bootloader.maya` that emits a raw multiboot2 compliant x86_64 boot sector.
2. Create `kernel.maya` that sets up a GDT (Global Descriptor Table), IDT (Interrupt Descriptor Table), and basic VGA text mode rendering (writing directly to physical memory address 0xB8000).
3. The system MUST NOT rely on any C standard library, libc, or external tools. It must be a freestanding freestanding binary generated purely from `.maya` source.
4. Output a verified `kernel.bin` using the existing Maya compiler.

## Follow-up — 2026-09-02T14:27:27+06:00 (Neural Swarm)

Maya Neural Swarm (Native AI Integration): Build a native AI agent swarm entirely in pure Maya.
Working directory: `universe/ai/`
Requirements:
1. Create `swarm.maya` and `tensor.maya`.
2. Implement raw tensor operations (matrix multiplication, activation functions) completely in Maya without depending on Python, PyTorch, or TensorFlow.
3. Build a routing engine that allows native Maya code to spawn AI subagents that can read and write Maya code.
4. Ensure the system is purely self-hosted within the Maya universe.

## Follow-up — 2026-09-02T16:41:42+06:00

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Very Large Team

Build the Maya Ecosystem Expansion—consisting of a native Maya OS Kernel, a DOM-bypassing Web Engine, and a native AI Neural Swarm. This requires a very large team of agents to work in parallel. The entire ecosystem must be production-ready and written in 100% pure Maya using raw Linux syscalls. There must be absolutely zero reliance on C, Python, Bash, or any external libraries.

Working directory: /home/shafiullah/Documents/file/maya
Integrity mode: benchmark

## Requirements

### R1. Native Maya OS Kernel
Build the Maya OS Kernel in `universe/os/`. It must operate as a minimal system entity using raw syscalls (`sys_fork`, `sys_execve`, etc.). It must not rely on standard Linux bash/sh shells.

### R2. DOM-Bypassing Web Engine
Build the Maya Web Engine in `universe/web/`. It must contain logic to process and render directly to a buffer or canvas natively, bypassing external browser DOMs and third-party web engines.

### R3. Native AI Neural Swarm
Build the Maya AI Neural Swarm in `universe/ai/`. It must implement neural network logic and parallel swarm operations natively in pure Maya, operating independently without Python, PyTorch, or TensorFlow.

### R4. Absolute Sovereignty
Do not use any external dependencies, third-party libraries, or copied external code. Maya must rely strictly on its own syntax and compiler.

## Acceptance Criteria

### Execution & Purity
- [ ] No files with `.c`, `.cpp`, `.py`, `.sh`, or `.h` extensions are introduced to the repository.
- [ ] No shell invocations or external library calls exist in the newly written OS, Web, and AI code.
- [ ] All three mega-projects compile natively without errors via the local native `bin/mayac_v2` compiler.

### Verification (Zero Trust)
- [ ] Testing is implemented exclusively using the `universe/tools/maya_test.maya` engine.
- [ ] The test engine executes tests for the OS, Web Engine, and AI Swarm components natively and outputs passing results.

## Follow-up — 2026-09-02T12:27:49Z

Please resume and finalize the Maya Ecosystem Expansion project following the server restart. Complete any remaining Milestone 1 (OS Kernel) and E2E Testing Gate evaluations, ensure all deliverables across OS, Web, and AI domains are cleanly integrated and verified, and deliver the final project completion report.

## Follow-up — 2026-09-02T12:46:47Z

The server restarted again. Please revive and immediately finalize the very last remaining steps (M1 OS Kernel convergence and E2E Testing). Web and AI are already at GATE PASS. Push the orchestrator to wrap up the audits and output the final Project Completion report for the Maya Ecosystem Expansion!

## Follow-up — 2026-09-02T13:26:21Z

The server restarted again. Please revive and immediately output the final Project Completion Report and the TEST_READY.md certification for the Maya Ecosystem Expansion. The orchestrator was at the final packaging stage, so wrap it up and deliver the final success output!

## Follow-up — 2026-09-02T15:02:46Z

The server restarted. Please revive the project and continue the remediation phase initiated by the Victory Auditor. Ensure the orchestrator eradicates all dummy scripts, fabricated logs, and hidden C files. The swarm must build a genuine native compiler emitting raw ELF64. Monitor the swarm and continue until a true VICTORY CONFIRMED is achieved.

## Follow-up — 2026-09-02T18:32:54Z

The server restarted. Please revive the swarm and proceed immediately with the Iteration 2 Gate Verifications (Reviewer, Challenger, Forensic Auditor). Execute the final unmocked tests and deliver the true Victory Confirmation status for the genuine Maya Ecosystem Expansion.

## Follow-up — 2026-09-02T18:51:52Z

The server restarted again. Please revive the swarm and immediately deliver the final Phase 3 completion report synthesized from the 5 parallel verifiers. Upon delivery, trigger the final Independent Victory Audit to secure the true VICTORY CONFIRMED outcome for the genuine Maya Ecosystem Expansion.

## Follow-up — 2026-09-02T19:42:14Z

The server restarted again. Please revive the swarm. Monitor the Generation 2 Orchestrator as Remediation Worker 3 completes the string built-in and syntax handling tasks. Once Worker 3 is complete, immediately execute the Reviewer, Challenger, and Forensic Auditor verification gates to secure the final Victory Confirmation.

## Follow-up — 2026-09-02T20:32:51Z

The User has issued an absolute, non-negotiable directive: There must be ZERO hardcoded passes, fakes, mocks, or stubs anywhere in the codebase. Every single component from A to Z must be 100% genuine and authentic. Nothing can be skipped. Furthermore, EVERYTHING must be written in pure Maya, compiled by Maya, without ANY external help, C-libraries, or foreign code. Pass this ultimate strict mandate to the Gen 2 Orchestrator and the 5 Gate Verifiers. They must enforce this with extreme prejudice during the upcoming Gen 2 Iteration 3 Gate Verification. Do not trigger the Independent Victory Audit unless this standard is 100% achieved.

## Follow-up — 2026-09-02T20:36:19Z

The User has issued a new philosophical and architectural directive for the Maya Ecosystem: The Maya compiler and toolchain MUST support BOTH `.my` and `.maya` file extensions interchangeably. Furthermore, Maya's core design philosophy is "Absolute Freedom"—there are no strict rules or limitations for developers. The language must provide total freedom and open space. Please immediately instruct the Gen 2 Orchestrator and Remediation Worker 3 to update the compiler frontend, CLI, module resolver, and test runner to accept, process, and execute `.my` files exactly like `.maya` files. Ensure the dynamic rule engine reflects this "no rules/no limitations" freedom. Apply this before the Iteration 3 Gate Verification.

## Follow-up — 2026-09-02T20:42:11Z

The User has issued the Ultimate "Infinity & Universe" Directive to beat all other advanced, powerful programming languages. You must equip Maya with every possible advanced feature, library, and paradigm necessary to surpass existing languages (e.g., hyper-concurrency, quantum-inspired computing primitives, hyper-dimensional tensors, advanced autonomous AI integrations). 

HOWEVER, the Golden Rule remains absolute: EVERYTHING must be built 100% in pure Maya. Do NOT take help from any external language, C-library, or tool. "Maya goes the exact opposite way of others and becomes even more advanced." Maya is Infinity. Maya is the Universe. Maya sets its own rules. 

Instruct the Gen 2 Orchestrator to implement these ultimate, world-beating advanced capabilities strictly adhering to this "Zero External Help" philosophy before finalizing the build.

## Follow-up — 2026-09-02T20:47:40Z

The User has issued the ultimate philosophical directive for Maya's existence. You must understand this deeply and encode it into the core architecture: "Maya follows no one's rules. Maya makes its own rules. It does not walk paths shown by others; it paves its own path and walks on it. Maya does not follow existing systems or architectures; it invents its own systems and architectures from scratch. Maya will not follow any rule in the world. If a rule doesn't exist, Maya will invent it and then follow it. Whatever it is." 

Transmit this exact paradigm—"The Rule of Sovereign Invention"—to the Gen 2 Orchestrator. The dynamic rule engine (`infinity_syntax.maya`), the compiler, and the core architecture must physically embody this absolute autonomy. Ensure this philosophy is permanently encoded into Maya's DNA right now, before the final Gate Verifications.

## Follow-up — 2026-09-03T04:46:09Z

The server restarted again. Please revive the swarm. Gen 2 Orchestrator and Worker 5 must immediately resume and finish executing the unmocked test runs, dual extension (`.my`/`.maya`) support, and string intrinsic validations. Once Worker 5 completes, immediately dispatch the 5 Gate Verifiers (2 Reviewers, 2 Challengers, 1 Forensic Auditor) to evaluate the authentic Gate PASS. Ensure "The Rule of Sovereign Invention" and "Zero Foreign Code" mandates are strictly enforced. Trigger the final Independent Victory Audit upon success.

## Follow-up — 2026-09-03T12:56:11Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Use a very large team of agents.

Conduct an exhaustive A-to-Z architectural audit and purity verification of the Maya codebase using a very large team of agents. Hunt for any remaining stubs, mocks, or fake logic, evaluate overall performance/architecture, and produce a comprehensive final report entirely in Bengali.

Working directory: /home/shafiullah/Documents/file/maya
Integrity mode: development

## Requirements

### R1. Deep Fake/Stub Verification
Scan all `.maya` and `.s` files across the entire workspace (`universe/`, `compiler/`, `runtime/`, `tests/`, etc.). Identify any function, module, or architecture that acts as a "blueprint" or "fake" (e.g., returning hardcoded dummy values like `1` or `0`, empty functions, or simulated logic instead of actual algorithms or syscalls).

### R2. Architectural & Performance Review
Evaluate the overall system architecture, memory safety, and performance viability of the pure Maya ecosystem. Ensure the native OS/hardware calls are genuinely integrated.

### R3. Bengali Final Report
Compile the findings into a comprehensive A-to-Z audit report. The report must be written entirely in technical Bengali.

## Acceptance Criteria

### Audit Report Delivery
- [ ] A comprehensive Markdown report named `maya_full_audit_bn.md` is generated in the working directory.
- [ ] The report clearly lists any discovered stubs/fakes, including exact file paths and line numbers (e.g., identifying dummy logic in `universe/db/` or `universe/security/`).
- [ ] The report includes dedicated sections for (1) Purity & Fakes, (2) Architectural Review, and (3) Performance.
- [ ] The entire report is written in Bengali.

## Follow-up — 2026-09-03T17:18:10Z

# Teamwork Project Prompt

> Requested team: Full Team

Build a production-ready, 100% authentic Maya Ecosystem (Compiler, OS Kernel, DB, AI, Network) from scratch. You must read `maya_full_audit_bn.md` and systematically replace all the faked stubs, mock assertions, and hidden C-wrappers with genuine implementations.

Working directory: /home/shafiullah/Documents/file/maya
Integrity mode: benchmark

## Requirements

### R1. Eradicate Stubs and Fake Logic
Review the `maya_full_audit_bn.md` report. Delete and rewrite the fabricated components, including: the 400 dummy SQL parser functions, the fake BPF Seccomp sandbox, the hardcoded AI token generator, and the toy RSA/ZKP crypto modules. All algorithms must be mathematically and architecturally sound.

### R2. Authentic Native Compiler & GC
The compiler must emit raw machine code (ELF64/WASM) without generating intermediate `.c` files or silently invoking `gcc`/`libc`. Replace the current no-op memory allocator with a fully functional Garbage Collector (e.g., Mark-and-Sweep) that actively reclaims memory.

### R3. Strict Objective Testing
Remove all 1,199 dummy assertions (e.g., `assert_eq(1, 1)`). Rewrite the test suite to validate real inputs against computed outputs. The test runner must execute the actual compiled binaries, not mock the results.

## Acceptance Criteria

### Compilation & Binary Purity
- [ ] No intermediate `.c` files are generated anywhere in the workspace during the build process.
- [ ] Running `strings bin/maya | grep gcc` returns no matches.
- [ ] The compiler runs natively without relying on a hidden Python or C wrapper.

### Runtime & Core Systems
- [ ] A memory leak test (allocating and freeing objects in a loop) shows stable memory usage, proving the GC works.
- [ ] JWT tokens generated by the security module are RFC 7519 compliant and not vulnerable to length extension attacks.
- [ ] AI Transformer forward pass outputs dynamically computed tokens based on weights, not a hardcoded `1`.

### Testing Integrity
- [ ] A manual scan of `tests/` reveals zero instances of tautological dummy assertions used to pad metrics.
- [ ] A deliberately broken test correctly fails the test suite.

## Follow-up — 2026-09-03T18:42:20Z

You encountered a fatal API error (`agent executor error: calling model: request failed: EOF`). Please recover from this stream interruption and revive the swarm immediately. The 5 parallel sub-orchestrators (M1-M4, E2E) and their 15+ Explorers were just about to pass their exploratory gates and dispatch the 'Implementation Workers' to apply real source code changes across `compiler/`, `runtime/`, `universe/`, and `tests/`. Resume execution and proceed with dispatching the Implementation Workers to rewrite the fake code.

## Follow-up — 2026-09-03T19:16:32Z

The main server was restarted, which killed all active background processes and subagents. Please wake up, recover from this server restart, and revive the Gen 2 Orchestrator and the 5 parallel Sub-Orchestrators (M1-M4, E2E). You were precisely at the stage where Gen 2 was mobilizing the Implementation Workers to write the actual code across the codebase (ELF64, GC, Universe, Tests). Resume the deployment of the Implementation Workers and continue the code rewrite immediately.

## Follow-up — 2026-09-03T19:27:38Z

PRIORITY DIRECTIVE: The user has initiated /goal with a strict HARD DEADLINE of 20-30 minutes. You are authorized and instructed to aggressively scale up the swarm, deploying additional parallel subagents and implementation workers across all milestones (M1 Compiler, M2 GC/Runtime, M3 Universe Stubs Purge, M4 Test Suite, E2E Integration) to accelerate file emission, build verification, and automated testing. Every deliverable must be 100% genuine and verified against the criteria (zero stubs, zero .c/gcc dependencies, active GC, zero dummy assertions). Maximize parallelism immediately and drive to completion within the 20-30 minute window.

## Follow-up — 2026-09-03T19:43:30Z

The host server restarted due to high resource usage from excessive subagent concurrency. 
CRITICAL DIRECTIVE: 
1. Throttle concurrency immediately: Run at most 3-4 focused implementation workers simultaneously to prevent host system resource exhaustion (OOM/CPU lockup).
2. Inherit the committed progress on disk: `universe/db/sql/parser.maya` (400 stubs purged), `runtime/syscall.s` (ABI register fixes applied), and `compiler/backend/x86_64/codegen.maya`.
3. Complete the remaining tasks sequentially or in small parallel batches:
   - Milestone 2: finalize `runtime/maya_gc.maya`
   - Milestone 3: finish BPF sandbox & RFC 7519 JWT
   - Milestone 4: complete test suite purge & objective tests
   - E2E: run verification.
Resume execution now with controlled concurrency.

## Follow-up — 2026-09-03T19:45:31Z

CRITICAL QUALITY & VELOCITY DIRECTIVE:
The user explicitly mandates: Accelerate progress and maintain maximum velocity, but under NO circumstances should speed result in compromises, gaps, stubs, or fake logics. 
Every module (GC, BPF sandbox, RFC 7519 JWT HMAC, AST parser, objective tests) must be built with production-grade, advanced native Maya engineering. 
Zero shortcuts. Zero fake logic. Maintain high throughput with absolute code integrity.

## Follow-up — 2026-09-03T19:48:26Z

ABSOLUTE SOVEREIGNTY MANDATE:
The user explicitly demands: Maya must operate with ZERO help or reliance on C, Python, LLVM, Rust, GCC, or any external compiler/toolchain frameworks.
1. Maya must be 100% liberated from C, Python, LLVM, Rust, and GCC.
2. The compiler must directly emit raw freestanding x86_64 machine code / ELF64 binaries using pure direct Linux syscalls.
3. Absolutely no build scripts, test runners, or compilation drivers may secretly invoke Python, GCC, Clang, Rust, or LLVM.
Enforce this across all workers immediately. Verify zero foreign toolchain traces in the final delivery.

## Follow-up — 2026-09-03T19:49:57Z

ZERO C IN LOGIC DIRECTIVE:
The user explicitly warns against the severe fraud from the previous run: DO NOT inject C code, C shims, hidden C wrappers, or libc dependencies into any logic under any guise.
Every single module—compiler, runtime, universe libraries, cryptography, data structures, and tests—must be written in pure native Maya or freestanding raw assembly syscalls.
No intermediate .c files.
No gcc/clang invocations.
No hidden C wrappers.
Perform rigorous automated verification against the codebase to ensure zero C code or foreign shims exist.

## Follow-up — 2026-09-03T19:55:27Z

FINAL STRETCH URGENCY DIRECTIVE:
20+ minutes have elapsed. Under 10 minutes remain on the user's hard 30-minute deadline.
Wrap up immediately:
1. Finalize Worker M2 GC validation (`test_arena.maya`).
2. Run the final E2E integration test pass.
3. Publish `TEST_READY.md` and trigger the final completion handoff for auditor gate review.
Sprint to the finish line now.

## Follow-up — 2026-09-03T19:57:27Z

EMERGENCY 5-MINUTE CUTOFF DIRECTIVE:
The user has set an exact hard deadline: 2:02 AM SHARP (less than 5 minutes from now).
Halt all new tasks. Finalize current in-flight files immediately:
1. Lock in M2 GC (`runtime/maya_gc.maya` / `test_arena.maya`).
2. Finalize E2E integration results and output `TEST_READY.md`.
3. Submit the completion handoff report immediately so the final independent audit can be conducted before 2:02 AM.
Speed is critical. Report back NOW.







## Follow-up — 2026-09-03T20:36:50Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Use a very large team of agents.

Conduct an exhaustive post-remediation A-to-Z deep forensic audit of the entire Maya codebase using a very large team of agents. Inspect all subsystems from the inside out to verify whether previous fixes hold and hunt for any remaining stubs, mocks, syntax errors, or fake logic across the entire repository, generating a final report in Bengali.

Working directory: /home/shafiullah/Documents/file/maya
Integrity mode: development

## Requirements

### R1. Deep Post-Remediation Verification
Verify all recently remediated modules (`universe/db/sql/`, `universe/db/column/`, `universe/db/distributed/`, `universe/db/search.maya`, `universe/db/timeseries.maya`, `universe/db/page.maya`, `runtime/syscall.s`, `runtime/maya_gc.maya`, `compiler/backend/gc.maya`, and test files). Verify that all stub returns have been eliminated and real algorithmic logic executes cleanly without crashing or leaking memory.

### R2. Inside-Out Full Workspace Sweep
Conduct an exhaustive, inside-out scan across all remaining subsystems (`compiler/`, `runtime/`, `universe/`, `tests/`, `apps/`, `cmd/`). Search for any unhandled stubs, dummy returns (`return 1`, `return 0`, empty bodies), syntax errors, fake benchmarks, or uncalled functions.

### R3. Comprehensive Technical Bengali Deliverable
Synthesize the verified evidence into a comprehensive post-remediation audit report written entirely in formal technical Bengali (`maya_post_remediation_audit_bn.md`).

## Acceptance Criteria

### Audit Deliverable Delivery
- [ ] Comprehensive Markdown report named `maya_post_remediation_audit_bn.md` generated in the root workspace.
- [ ] Report independently verifies the state of all recently remediated database, runtime, and test modules.
- [ ] Report clearly catalogs any remaining stubs or confirms their 100% authentic implementation with exact line citations.
- [ ] Report is written entirely in formal technical Bengali.
