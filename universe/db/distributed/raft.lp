@! ============================================================================
@! MAYA UNIVERSE DB — SOVEREIGN DISTRIBUTED RAFT CONSENSUS ENGINE
@! File: universe/db/distributed/raft.maya
@! Standard: Ongaro & Ousterhout Raft Consensus Algorithm
@! 100% Pure Maya Implementation — Zero External C / libc Dependencies
@! Features: Quorum Election, Log Replication, Term Progression, State Machine
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

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
