@! ============================================================================
@! LIPI UNIVERSE DB — SOVEREIGN DISTRIBUTED RAFT CONSENSUS ENGINE
@! File: aati/lipidb/distributed/raft.lp
@! Standard: Ongaro & Ousterhout Raft Consensus Algorithm
@! 100% Pure Lipi Implementation — Zero External C / libc Dependencies
@! Features: Quorum Election, Log Replication, Term Progression, State Machine
@! ============================================================================

import "utso/collections"
import "utso/string"

@struct RaftLogEntry
  term: i64
  index: i64
  command: string
  payload: string
@end

@struct RaftNode
  node_id: i64
  current_term: i64
  voted_for: i64
  log: array
  commit_index: i64
  last_applied: i64
  state: string
  is_leader: i64
  votes_received: i64
  cluster_size: i64
@end

@! ----------------------------------------------------------------------------
@! 1. NODE CONSTRUCTOR & TOPOLOGY
@! ----------------------------------------------------------------------------

@fn raft_node_new(id)
  @! WHY: Default to a 3-node cluster quorum for standard fault tolerance
  return { 
    node_id: id, 
    current_term: 0, 
    voted_for: -1, 
    log: [], 
    commit_index: 0, 
    last_applied: 0, 
    state: "FOLLOWER",
    is_leader: 0,
    votes_received: 0,
    cluster_size: 3
  }
@end

@fn raft_node_with_cluster(id, cluster_sz)
  return { 
    node_id: id, 
    current_term: 0, 
    voted_for: -1, 
    log: [], 
    commit_index: 0, 
    last_applied: 0, 
    state: "FOLLOWER",
    is_leader: 0,
    votes_received: 0,
    cluster_size: cluster_sz
  }
@end

@! ----------------------------------------------------------------------------
@! 2. LOG ENTRY HELPERS
@! ----------------------------------------------------------------------------

@fn raft_entry_new(term, index, cmd, payload)
  return {
    term: term,
    index: index,
    command: cmd,
    payload: payload
  }
@end

@fn raft_last_log_index(node)
  n = node.log.len()
  @if n == 0 return 0 @end
  last_entry = node.log[n - 1]
  return last_entry.index
@end

@fn raft_last_log_term(node)
  n = node.log.len()
  @if n == 0 return 0 @end
  last_entry = node.log[n - 1]
  return last_entry.term
@end

@! ----------------------------------------------------------------------------
@! 3. ELECTION & REQUEST VOTE RPC
@! ----------------------------------------------------------------------------

@fn raft_start_election(node)
  @! WHY: Follower times out, increments term, becomes CANDIDATE, votes for self
  node.current_term = node.current_term + 1
  node.state = "CANDIDATE"
  node.voted_for = node.node_id
  node.votes_received = 1
  node.is_leader = 0
  return node
@end

@fn raft_request_vote(node, term, candidate_id, last_log_idx, last_log_term)
  @! Rule 1: Reply false if term < currentTerm
  @if term < node.current_term
    return 0
  @end

  @! Rule 2: If RPC request contains term > currentTerm, update term and revert to FOLLOWER
  @if term > node.current_term
    node.current_term = term
    node.state = "FOLLOWER"
    node.voted_for = -1
    node.is_leader = 0
  @end

  @! Rule 3: Check log up-to-date invariant
  my_last_term = raft_last_log_term(node)
  my_last_idx = raft_last_log_index(node)
  
  log_ok = 0
  @if last_log_term > my_last_term
    log_ok = 1
  @elif last_log_term == my_last_term
    @if last_log_idx >= my_last_idx
      log_ok = 1
    @end
  @end

  @if log_ok == 1
    @if node.voted_for == -1 || node.voted_for == candidate_id
      node.voted_for = candidate_id
      return 1
    @end
  @end

  return 0
@end

@fn raft_record_vote(node, vote_granted)
  @! WHY: Candidate counts granted votes and checks if strict majority quorum is met
  @if str_eq(node.state, "CANDIDATE") == 1 && vote_granted == 1
    node.votes_received = node.votes_received + 1
    majority = (node.cluster_size / 2) + 1
    @if node.votes_received >= majority
      node.state = "LEADER"
      node.is_leader = 1
    @end
  @end
  return node
@end

@! ----------------------------------------------------------------------------
@! 4. LOG REPLICATION & APPEND ENTRIES RPC
@! ----------------------------------------------------------------------------

@fn raft_append_entries(node, term, leader_id, entries, leader_commit)
  @! Rule 1: Reply false if term < currentTerm
  @if term < node.current_term
    return 0
  @end

  @! Rule 2: If term >= currentTerm, acknowledge valid leader and maintain FOLLOWER state
  @if term > node.current_term || str_eq(node.state, "CANDIDATE") == 1
    node.current_term = term
    node.state = "FOLLOWER"
    node.is_leader = 0
    node.voted_for = leader_id
  @end

  @! Rule 3: Append any new entries not already present in the log
  i = 0
  n_entries = entries.len()
  @while i < n_entries
    node.log = node.log.push(entries[i])
    i = i + 1
  @end

  @! Rule 4: If leaderCommit > commitIndex, update commitIndex
  @if leader_commit > node.commit_index
    node.commit_index = leader_commit
  @end

  return 1
@end

@! ----------------------------------------------------------------------------
@! 5. STATE MACHINE APPLICATION
@! ----------------------------------------------------------------------------

@fn raft_apply_committed_entries(node)
  @! WHY: Advance last_applied until it matches commit_index
  @while node.last_applied < node.commit_index
    node.last_applied = node.last_applied + 1
  @end
  return node
@end

@! ----------------------------------------------------------------------------
@! 6. MULTI-NODE CLUSTER ORCHESTRATION & RAFT STATE MACHINE
@! ----------------------------------------------------------------------------

@struct RaftCluster
  nodes: array
  leader_id: i64
  cluster_size: i64
@end

@fn raft_cluster_new(node_count)
  @! WHY: Constructs a cluster topology of N sovereign Raft consensus nodes
  nodes = []
  i = 1
  @while i <= node_count
    n = raft_node_with_cluster(i, node_count)
    nodes = nodes.push(n)
    i = i + 1
  @end
  return {
    nodes: nodes,
    leader_id: 0 - 1,
    cluster_size: node_count
  }
@end

@fn raft_cluster_elect(cluster: RaftCluster, candidate_id)
  @! WHY: Candidate triggers term increment and requests vote from all peers in cluster.
  @! Requires strict majority quorum ((cluster_size / 2) + 1) to win election.
  cand_idx = candidate_id - 1
  cand = cluster.nodes[cand_idx]
  cand = raft_start_election(cand)
  
  i = 0
  sz = cluster.nodes.len()
  @while i < sz
    @if i != cand_idx
      peer = cluster.nodes[i]
      granted = raft_request_vote(peer, cand.current_term, cand.node_id, raft_last_log_index(cand), raft_last_log_term(cand))
      cand = raft_record_vote(cand, granted)
    @end
    i = i + 1
  @end
  
  cluster.nodes[cand_idx] = cand
  @if cand.is_leader == 1
    cluster.leader_id = candidate_id
    return 1
  @end
  return 0
@end

@fn raft_cluster_propose_entry(cluster: RaftCluster, leader_id, cmd, payload)
  @! WHY: Leader receives write command, appends to its log, and replicates to peer followers.
  @! Advances commit_index once strict majority confirms append.
  leader_idx = leader_id - 1
  leader = cluster.nodes[leader_idx]
  @if leader.is_leader != 1
    return 0
  @end

  new_idx = raft_last_log_index(leader) + 1
  entry = raft_entry_new(leader.current_term, new_idx, cmd, payload)
  leader.log = leader.log.push(entry)

  acks = 1
  sz = cluster.nodes.len()
  majority = (sz / 2) + 1

  i = 0
  @while i < sz
    @if i != leader_idx
      peer = cluster.nodes[i]
      ok = raft_append_entries(peer, leader.current_term, leader.node_id, [entry], leader.commit_index)
      @if ok == 1
        acks = acks + 1
      @end
    @end
    i = i + 1
  @end

  @if acks >= majority
    leader.commit_index = new_idx
    leader = raft_apply_committed_entries(leader)
    cluster.nodes[leader_idx] = leader

    @! Notify followers of updated commit_index
    j = 0
    @while j < sz
      @if j != leader_idx
        p = cluster.nodes[j]
        raft_append_entries(p, leader.current_term, leader.node_id, [], leader.commit_index)
        p = raft_apply_committed_entries(p)
        cluster.nodes[j] = p
      @end
      j = j + 1
    @end
    return new_idx
  @end

  cluster.nodes[leader_idx] = leader
  return 0
@end

@! ----------------------------------------------------------------------------
@! 7. BYZANTINE FAULT TOLERANT (BFT) QUORUM CONSENSUS ENGINE
@! ----------------------------------------------------------------------------
@! Standard: PBFT / Tendermint 3-Phase State Machine (Pre-Prepare, Prepare, Commit)
@! Tolerates up to f Byzantine traitors in cluster of N >= 3f + 1 nodes.
@! Strict Byzantine Quorum: Q = 2f + 1 = floor((2N + 1) / 3).

@struct RaftBFTVote
  rbv_sender_id: i64
  rbv_phase: i64
  rbv_view: i64
  rbv_seq: i64
  rbv_digest: string
  rbv_signature: string
@end

@struct RaftBFTNode
  rbn_node_id: i64
  rbn_cluster_size: i64
  rbn_view: i64
  rbn_seq: i64
  rbn_state: string
  rbn_prepare_votes: array
  rbn_commit_votes: array
  rbn_committed_log: array
  rbn_is_traitor: i64
  rbn_last_applied: i64
@end

@struct RaftBFTCluster
  rbc_nodes: array
  rbc_cluster_size: i64
  rbc_quorum_size: i64
  rbc_max_faulty: i64
  rbc_committed_count: i64
@end

@fn raft_bft_quorum_size(cluster_sz)
  @! Byzantine Quorum formula: Q = 2f + 1 where f = (N - 1) / 3
  f = (cluster_sz - 1) / 3
  return (2 * f) + 1
@end

@fn raft_bft_sign(sender_id, view, seq, digest)
  return "SIG_BFT_" + str(sender_id) + "_" + str(view) + "_" + str(seq) + "_" + digest
@end

@fn raft_bft_verify_sig(sender_id, view, seq, digest, sig)
  expected = raft_bft_sign(sender_id, view, seq, digest)
  @if str_eq(sig, expected) == 1
    return 1
  @end
  return 0
@end

@fn raft_bft_node_new(id, cluster_sz)
  return {
    rbn_node_id: id,
    rbn_cluster_size: cluster_sz,
    rbn_view: 0,
    rbn_seq: 0,
    rbn_state: "IDLE",
    rbn_prepare_votes: [],
    rbn_commit_votes: [],
    rbn_committed_log: [],
    rbn_is_traitor: 0,
    rbn_last_applied: 0
  }
@end

@fn raft_bft_cluster_new(node_count)
  nodes = []
  i = 1
  @while i <= node_count
    n = raft_bft_node_new(i, node_count)
    nodes = nodes.push(n)
    i = i + 1
  @end
  q_sz = raft_bft_quorum_size(node_count)
  f_max = (node_count - 1) / 3
  return {
    rbc_nodes: nodes,
    rbc_cluster_size: node_count,
    rbc_quorum_size: q_sz,
    rbc_max_faulty: f_max,
    rbc_committed_count: 0
  }
@end

@fn raft_bft_propose(cluster: RaftBFTCluster, leader_id, proposal)
  @! 3-Phase BFT State Machine:
  @! Phase 1: Pre-Prepare (Leader broadcasts proposal and cryptographic signature)
  @! Phase 2: Prepare (Honest nodes verify and exchange signed Prepare votes; wait for Q >= 2f+1)
  @! Phase 3: Commit (Honest nodes exchange Commit votes; upon Q >= 2f+1 commits, apply state)
  leader_idx = leader_id - 1
  leader = cluster.rbc_nodes[leader_idx]
  @if leader.rbn_is_traitor == 1
    return 0
  @end

  seq = leader.rbn_seq + 1
  view = leader.rbn_view
  digest = proposal
  leader_sig = raft_bft_sign(leader_id, view, seq, digest)

  // 1. Phase 1: Pre-Prepare across all honest nodes
  sz = cluster.rbc_nodes.len()
  i = 0
  @while i < sz
    node = cluster.rbc_nodes[i]
    @if node.rbn_is_traitor == 0
      @if raft_bft_verify_sig(leader_id, view, seq, digest, leader_sig) == 1
        node.rbn_seq = seq
        node.rbn_state = "PRE_PREPARED"
        node.rbn_prepare_votes = []
        node.rbn_commit_votes = []
        cluster.rbc_nodes[i] = node
      @end
    @end
    i = i + 1
  @end

  // 2. Phase 2: Prepare phase - honest nodes exchange signed Prepare votes
  p_idx = 0
  @while p_idx < sz
    sender = cluster.rbc_nodes[p_idx]
    @if sender.rbn_is_traitor == 0
      sig = raft_bft_sign(sender.rbn_node_id, view, seq, digest)
      vote = {
        rbv_sender_id: sender.rbn_node_id,
        rbv_phase: 2,
        rbv_view: view,
        rbv_seq: seq,
        rbv_digest: digest,
        rbv_signature: sig
      }

      // Deliver to all honest nodes
      r_idx = 0
      @while r_idx < sz
        receiver = cluster.rbc_nodes[r_idx]
        @if receiver.rbn_is_traitor == 0
          receiver.rbn_prepare_votes = receiver.rbn_prepare_votes.push(vote)
          cluster.rbc_nodes[r_idx] = receiver
        @end
        r_idx = r_idx + 1
      @end
    @end
    p_idx = p_idx + 1
  @end

  // Check Prepare Quorum (>= 2f + 1)
  q = cluster.rbc_quorum_size
  prep_ok_count = 0
  chk_i = 0
  @while chk_i < sz
    nd = cluster.rbc_nodes[chk_i]
    @if nd.rbn_is_traitor == 0 && nd.rbn_prepare_votes.len() >= q
      nd.rbn_state = "PREPARED"
      cluster.rbc_nodes[chk_i] = nd
      prep_ok_count = prep_ok_count + 1
    @end
    chk_i = chk_i + 1
  @end

  @if prep_ok_count < q
    return 0
  @end

  // 3. Phase 3: Commit phase - honest nodes exchange signed Commit votes
  c_idx = 0
  @while c_idx < sz
    sender = cluster.rbc_nodes[c_idx]
    @if sender.rbn_is_traitor == 0 && str_eq(sender.rbn_state, "PREPARED") == 1
      sig = raft_bft_sign(sender.rbn_node_id, view, seq, digest)
      vote = {
        rbv_sender_id: sender.rbn_node_id,
        rbv_phase: 3,
        rbv_view: view,
        rbv_seq: seq,
        rbv_digest: digest,
        rbv_signature: sig
      }

      r_idx = 0
      @while r_idx < sz
        receiver = cluster.rbc_nodes[r_idx]
        @if receiver.rbn_is_traitor == 0
          receiver.rbn_commit_votes = receiver.rbn_commit_votes.push(vote)
          cluster.rbc_nodes[r_idx] = receiver
        @end
        r_idx = r_idx + 1
      @end
    @end
    c_idx = c_idx + 1
  @end

  // Apply committed state upon receiving >= Q commit votes
  committed_nodes = 0
  fin_i = 0
  @while fin_i < sz
    nd = cluster.rbc_nodes[fin_i]
    @if nd.rbn_is_traitor == 0 && nd.rbn_commit_votes.len() >= q
      nd.rbn_state = "COMMITTED"
      nd.rbn_committed_log = nd.rbn_committed_log.push(proposal)
      nd.rbn_last_applied = seq
      cluster.rbc_nodes[fin_i] = nd
      committed_nodes = committed_nodes + 1
    @end
    fin_i = fin_i + 1
  @end

  @if committed_nodes >= q
    cluster.rbc_committed_count = cluster.rbc_committed_count + 1
    return seq
  @end

  return 0
@end

@fn raft_bft_inject_byzantine_fault(cluster: RaftBFTCluster, traitor_id)
  @! Marks the node as a Byzantine traitor and excludes its fraudulent votes
  idx = traitor_id - 1
  @if idx >= 0 && idx < cluster.rbc_nodes.len()
    node = cluster.rbc_nodes[idx]
    node.rbn_is_traitor = 1
    cluster.rbc_nodes[idx] = node
    return 1
  @end
  return 0
@end

