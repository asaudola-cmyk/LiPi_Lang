// ==============================================================================
// 🧪 LIPI REGRESSION TEST: PLANETARY MESH DHT & BYZANTINE FAULT TOLERANCE (BFT)
// ⚡ Module: tests/test_bft_planetary_mesh.lp
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/io.lp"
include "utso/string.lp"
include "aati/sovereign_mesh/src/mesh.lp"
include "aati/lipidb/distributed/raft.lp"

fn test_kademlia_dht_xor_routing
    say "[Mesh] Testing Kademlia DHT XOR Distance & Peer Routing..."
    
    // Test 1: XOR distance metric
    d1 = mesh_dht_distance(5, 5) // 5 ^ 5 = 0
    if d1 != 0
        say "FAIL: XOR distance between identical IDs must be 0, got " + str(d1)
        return 0
    end
    d2 = mesh_dht_distance(12, 10) // 12 ^ 10 = 1100 ^ 1010 = 0110 = 6
    if d2 != 6
        say "FAIL: Expected XOR distance 6, got " + str(d2)
        return 0
    end

    // Test 2: DHT Node & Peer Topology
    node = mesh_dht_node_new(100)
    mesh_dht_add_peer(node, 105, "10.0.0.5:9000") // d = 100 ^ 105 = 01100100 ^ 01101001 = 13
    mesh_dht_add_peer(node, 101, "10.0.0.1:9000") // d = 100 ^ 101 = 01100100 ^ 01100101 = 1
    mesh_dht_add_peer(node, 200, "10.0.0.9:9000") // d = 100 ^ 200 = 172
    mesh_dht_add_peer(node, 102, "10.0.0.2:9000") // d = 100 ^ 102 = 6

    if len(node.mdn_peers) != 4
        say "FAIL: Expected 4 peers in DHT routing table, got " + str(len(node.mdn_peers))
        return 0
    end

    // Test 3: Closest nodes query relative to target ID 100
    closest = mesh_dht_closest_nodes(node, 100, 2)
    if len(closest) != 2
        say "FAIL: Expected 2 closest nodes, got " + str(len(closest))
        return 0
    end

    p_first = closest[0]
    p_second = closest[1]
    // Closest to 100 should be 101 (distance 1), then 102 (distance 6)
    if p_first.mdp_id != 101
        say "FAIL: Expected closest node 101, got " + str(p_first.mdp_id)
        return 0
    end
    if p_second.mdp_id != 102
        say "FAIL: Expected second closest node 102, got " + str(p_second.mdp_id)
        return 0
    end

    say "  ✔ Kademlia XOR Metric: Bitwise topology and closest-peer ordering verified."
    return 1

fn test_dht_key_value_store
    say "[Mesh] Testing Decentralized DHT Key-Value Storage..."
    node = mesh_dht_node_new(500)
    mesh_dht_put(node, "consensus_proto", "bft_planetary")
    mesh_dht_put(node, "cluster_capacity", "1000000_tps")

    val1 = mesh_dht_get(node, "consensus_proto")
    if val1 != "bft_planetary"
        say "FAIL: DHT get mismatch for consensus_proto: " + val1
        return 0
    end

    val2 = mesh_dht_get(node, "cluster_capacity")
    if val2 != "1000000_tps"
        say "FAIL: DHT get mismatch for cluster_capacity: " + val2
        return 0
    end

    // Test key overwrite
    mesh_dht_put(node, "cluster_capacity", "2500000_tps")
    val3 = mesh_dht_get(node, "cluster_capacity")
    if val3 != "2500000_tps"
        say "FAIL: Key overwrite failed, got " + val3
        return 0
    end

    say "  ✔ DHT Storage: Key-value mapping and transactional updates verified."
    return 1

fn test_crypto_identity_signing
    say "[Mesh] Testing Sovereign Payload Cryptographic Signing..."
    node_id = 42
    payload = "TRANSACTION_TRANSFER_100_SOV"

    sig = mesh_crypto_sign(node_id, payload)
    if len(sig) == 0
        say "FAIL: Generated signature is empty"
        return 0
    end

    // Verify valid signature
    ok = mesh_crypto_verify(node_id, payload, sig)
    if ok != 1
        say "FAIL: Legitimate signature failed verification"
        return 0
    end

    // Verify tampered payload fails verification
    tampered_ok = mesh_crypto_verify(node_id, "TRANSACTION_TRANSFER_999_SOV", sig)
    if tampered_ok != 0
        say "FAIL: Tampered payload should be rejected by signature validator"
        return 0
    end

    say "  ✔ Cryptographic Signing: Non-repudiation signature verification verified."
    return 1

fn test_bft_quorum_consensus
    say "[BFT] Testing Byzantine Quorum Consensus (3-Phase State Machine)..."
    // Cluster of N = 4 nodes tolerating f = 1 Byzantine traitor
    // Byzantine Quorum Q = 2f + 1 = 3
    q_sz = raft_bft_quorum_size(4)
    if q_sz != 3
        say "FAIL: Expected BFT quorum size 3 for 4-node cluster, got " + str(q_sz)
        return 0
    end

    cluster = raft_bft_cluster_new(4)
    if cluster.rbc_cluster_size != 4 or cluster.rbc_quorum_size != 3
        say "FAIL: Cluster initialization parameters mismatch"
        return 0
    end

    // Propose transaction from Leader (Node 1)
    seq = raft_bft_propose(cluster, 1, "TX_001_GENESIS_ROOT")
    if seq != 1
        say "FAIL: 3-phase consensus failed to commit sequence 1, got " + str(seq)
        return 0
    end

    // Verify that at least Q=3 honest nodes transitioned to COMMITTED state
    commit_count = 0
    i = 0
    while i < 4
        nd = cluster.rbc_nodes[i]
        if nd.rbn_state == "COMMITTED" and nd.rbn_last_applied == 1
            commit_count = commit_count + 1
        end
        i = i + 1
    end

    if commit_count < 3
        say "FAIL: Expected at least 3 nodes committed, got " + str(commit_count)
        return 0
    end

    say "  ✔ BFT 3-Phase State Machine: Pre-Prepare, Prepare, and Commit phases passed."
    return 1

fn test_byzantine_fault_isolation
    say "[BFT] Testing Byzantine Traitor Detection & Isolation..."
    cluster = raft_bft_cluster_new(4)

    // Inject Byzantine traitor on Node 4 (malicious equivocation / fault)
    raft_bft_inject_byzantine_fault(cluster, 4)

    // Leader proposes transaction; traitor node is ignored/ejected, but honest quorum of 3 succeeds!
    seq = raft_bft_propose(cluster, 1, "TX_002_RESILIENT_TRANSFER")
    if seq != 1
        say "FAIL: Cluster failed to reach Byzantine quorum despite f=1 fault, got " + str(seq)
        return 0
    end

    // Verify honest nodes 1, 2, 3 committed the proposal
    node1 = cluster.rbc_nodes[0]
    node2 = cluster.rbc_nodes[1]
    node3 = cluster.rbc_nodes[2]
    node4 = cluster.rbc_nodes[3]

    if node1.rbn_state != "COMMITTED" or node2.rbn_state != "COMMITTED" or node3.rbn_state != "COMMITTED"
        say "FAIL: Honest nodes failed to commit under Byzantine fault"
        return 0
    end
    if node4.rbn_is_traitor != 1
        say "FAIL: Byzantine node was not marked as traitor"
        return 0
    end

    say "  ✔ Byzantine Fault Tolerance: Traitor isolated and honest quorum committed safely."
    return 1

fn main
    say "===================================================================="
    say "👑 LIPI SOVEREIGN: PLANETARY MESH & BFT CLUSTER CONSENSUS TEST SUITE"
    say "===================================================================="
    if test_kademlia_dht_xor_routing() == 0 exit(1) end
    if test_dht_key_value_store() == 0 exit(1) end
    if test_crypto_identity_signing() == 0 exit(1) end
    if test_bft_quorum_consensus() == 0 exit(1) end
    if test_byzantine_fault_isolation() == 0 exit(1) end
    say "===================================================================="
    say "🎉 ALL PLANETARY MESH & BFT CONSENSUS TESTS PASSED (100% GREEN)!"
    say "===================================================================="
    return 0

main()
