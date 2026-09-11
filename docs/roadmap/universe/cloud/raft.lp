@! ============================================================================
@! MAYA UNIVERSE CLOUD - RAFT DISTRIBUTED CONSENSUS
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! Raft Node State
@fn raft_node_new(id, peers)
  return {
    id: id,
    peers: peers,
    state: "FOLLOWER", @! FOLLOWER, CANDIDATE, LEADER
    current_term: 0,
    voted_for: 0,
    log: [],
    commit_index: 0,
    last_applied: 0,
    votes_received: 0
  }
@end

@! Start Election
@fn raft_start_election(node)
  node.state = "CANDIDATE"
  node.current_term = node.current_term + 1
  node.voted_for = node.id
  node.votes_received = 1
  
  @! Send RequestVote RPCs to all peers
  @for peer in node.peers
    @! network_send(peer, { type: "RequestVote", term: node.current_term, candidateId: node.id })
  @end
  
  return node
@end

@! Handle RequestVote
@fn raft_handle_request_vote(node, req)
  @if req.term > node.current_term
    node.current_term = req.term
    node.state = "FOLLOWER"
    node.voted_for = 0
  @end
  
  @if (node.voted_for == 0 || node.voted_for == req.candidateId) && (req.term >= node.current_term)
    node.voted_for = req.candidateId
    return { node: node, vote_granted: 1 }
  @end
  
  return { node: node, vote_granted: 0 }
@end
