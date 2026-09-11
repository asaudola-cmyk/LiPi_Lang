// ==============================================================================
// 👑 Test 73: Lipi SSA Dominator Tree & Minimal Phi-Placement Test
// ⚡ Features Tested:
//    1. Lengauer-Tarjan Immediate Dominator (idom) Tree Calculation
//    2. Cytron's Dominance Frontier (DF) Construction
//    3. Iterated Dominance Frontier (IDF) Minimal Phi-Node Placement
//    4. Dominance-Based Dead Block Pruning (DCE)
// ==============================================================================

import "src/compiler/ssa_ir.lp"
import "src/compiler/middleend/dominance.lp"

say "========================================================"
say "👑 Testing Lipi Sovereign SSA Dominator Tree Engine"
say "========================================================"

// Construct test CFG:
//       entry
//      /     \
//    then    else
//      \     /
//       join
//        |
//       exit
//     (dead_b - unreachable)

cfg = ir_func_new("test_flow", list("arg0"))

// Allocate blocks
b_entry = ir_func_entry(cfg) // label "entry"
b_then  = ir_func_new_block(cfg, "then")
b_else  = ir_func_new_block(cfg, "else")
b_join  = ir_func_new_block(cfg, "join")
b_exit  = ir_func_new_block(cfg, "exit")
b_dead  = ir_func_new_block(cfg, "dead")

lbl_entry = ir_block_label(b_entry)
lbl_then  = ir_block_label(b_then)
lbl_else  = ir_block_label(b_else)
lbl_join  = ir_block_label(b_join)
lbl_exit  = ir_block_label(b_exit)
lbl_dead  = ir_block_label(b_dead)

// Wire CFG edges (Predecessors & Successors)
// entry -> then, else
push(ir_block_succs(b_entry), lbl_then)
push(ir_block_succs(b_entry), lbl_else)

push(ir_block_preds(b_then), lbl_entry)
push(ir_block_succs(b_then), lbl_join)

push(ir_block_preds(b_else), lbl_entry)
push(ir_block_succs(b_else), lbl_join)

// then, else -> join
push(ir_block_preds(b_join), lbl_then)
push(ir_block_preds(b_join), lbl_else)
push(ir_block_succs(b_join), lbl_exit)

// join -> exit
push(ir_block_preds(b_exit), lbl_join)

// ── Test Part 1: Lengauer-Tarjan Immediate Dominator Tree ─────────────────────
say "[1/3] Computing Immediate Dominators (idom) via Lengauer-Tarjan..."

idom_map = compute_dominators(cfg)

idom_then = ssa_map_get(idom_map, lbl_then, "")
idom_else = ssa_map_get(idom_map, lbl_else, "")
idom_join = ssa_map_get(idom_map, lbl_join, "")
idom_exit = ssa_map_get(idom_map, lbl_exit, "")

if idom_then != lbl_entry or idom_else != lbl_entry
    say "FAILED: idom of then/else must be entry!"
    exit(1)
say "  ✔ idom(then) = entry, idom(else) = entry"

if idom_join != lbl_entry
    say "FAILED: idom of join must be entry, got:"
    say idom_join
    exit(1)
say "  ✔ idom(join) = entry (diamond confluence correctly dominated by entry)"

if idom_exit != lbl_join
    say "FAILED: idom of exit must be join, got:"
    say idom_exit
    exit(1)
say "  ✔ idom(exit) = join"

// ── Test Part 2: Dominance Frontier & Minimal Phi Placement ───────────────────
say "[2/3] Computing Dominance Frontier & Minimal Phi Placement..."

df_map = compute_dominance_frontier(cfg, idom_map)

df_then = ssa_map_get(df_map, lbl_then, list())
df_else = ssa_map_get(df_map, lbl_else, list())

// Both then and else should have join in their Dominance Frontier
has_join_then = 0
if len(df_then) > 0 and get(df_then, 0) == lbl_join has_join_then = 1

has_join_else = 0
if len(df_else) > 0 and get(df_else, 0) == lbl_join has_join_else = 1

if has_join_then == 0 or has_join_else == 0
    say "FAILED: DF(then) and DF(else) must contain join block!"
    exit(1)
say "  ✔ DF(then) contains join, DF(else) contains join"

// Compute phi placement for variable defined in both branches
var_defs = list(lbl_then, lbl_else)
phi_locations = compute_phi_placement(cfg, df_map, var_defs)

if len(phi_locations) != 1 or get(phi_locations, 0) != lbl_join
    say "FAILED: Phi-function must be placed exclusively at join block!"
    exit(1)
say "  ✔ Minimal SSA Phi-node placed precisely at join block: " + get(phi_locations, 0)

// ── Test Part 3: Dominance-Based Dead Block Pruning (DCE) ─────────────────────
say "[3/3] Pruning Unreachable Dead Code via Dominator Tree..."

pruned = dce_prune_unreachable_blocks(cfg, idom_map)
if pruned != 1
    say "FAILED: Expected 1 pruned unreachable block, got:"
    say pruned
    exit(1)

if ir_block_is_dead(b_dead) != 1
    say "FAILED: Unreachable block was not marked dead!"
    exit(1)
say "  ✔ Unreachable dead block (" + lbl_dead + ") successfully pruned from CFG"

say ""
say "========================================================"
say "🎉 ALL SSA DOMINATOR TREE & PHI TESTS PASSED! 👑"
say "========================================================"
