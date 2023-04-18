

  Solidity code:
  /// Voting with delegation.
  contract Ballot {
      // This declares a new complex type which will
      // be used for variables later.
      // It will represent a single voter.
      struct Voter {
          uint weight; // weight is accumulated by delegation
          bool voted;  // if true, that person already voted
          address delegate; // person delegated to
          uint vote;   // index of the voted proposal
      }

      // This is a type for a single proposal.
      struct Proposal {
          bytes32 name;   // short name (up to 32 bytes)
          uint voteCount; // number of accumulated votes
      }

      address public chairperson;

      // This declares a state variable that
      // stores a `Voter` struct for each possible address.
      mapping(address => Voter) public voters;

      // A dynamically-sized array of `Proposal` structs.
      Proposal[] public proposals;

      /// Create a new ballot to choose one of `proposalNames`.
      function Ballot(bytes32[] proposalNames) {
          chairperson = msg.sender;
          voters[chairperson].weight = 1;

          // For each of the provided proposal names,
          // create a new proposal object and add it
          // to the end of the array.
          for (uint i = 0; i < proposalNames.length; i++) {
              // `Proposal({...})` creates a temporary
              // Proposal object and `proposals.push(...)`
              // appends it to the end of `proposals`.
              proposals.push(Proposal({
                  name: proposalNames[i],
                  voteCount: 0
              }));
          }
      }

      // Give `voter` the right to vote on this ballot.
      // May only be called by `chairperson`.
      function giveRightToVote(address voter) {
          // If the argument of `require` evaluates to `false`,
          // it terminates and reverts all changes to
          // the state and to Ether balances. It is often
          // a good idea to use this if functions are
          // called incorrectly. But watch out, this
          // will currently also consume all provided gas
          // (this is planned to change in the future).
          require((msg.sender == chairperson) && !voters[voter].voted && (voters[voter].weight == 0));
          voters[voter].weight = 1;
      }

      /// Delegate your vote to the voter `to`.
      function delegate(address to) {
          // assigns reference
          Voter storage sender = voters[msg.sender];
          require(!sender.voted);

          // Self-delegation is not allowed.
          require(to != msg.sender);

          // Forward the delegation as long as
          // `to` also delegated.
          // In general, such loops are very dangerous,
          // because if they run too long, they might
          // need more gas than is available in a block.
          // In this case, the delegation will not be executed,
          // but in other situations, such loops might
          // cause a contract to get "stuck" completely.
          while (voters[to].delegate != address(0)) {
              to = voters[to].delegate;

              // We found a loop in the delegation, not allowed.
              require(to != msg.sender);
          }

          // Since `sender` is a reference, this
          // modifies `voters[msg.sender].voted`
          sender.voted = true;
          sender.delegate = to;
          Voter storage delegate = voters[to];
          if (delegate.voted) {
              // If the delegate already voted,
              // directly add to the number of votes
              proposals[delegate.vote].voteCount += sender.weight;
          } else {
              // If the delegate did not vote yet,
              // add to her weight.
              delegate.weight += sender.weight;
          }
      }

      /// Give your vote (including votes delegated to you)
      /// to proposal `proposals[proposal].name`.
      function vote(uint proposal) {
          Voter storage sender = voters[msg.sender];
          require(!sender.voted);
          sender.voted = true;
          sender.vote = proposal;

          // If `proposal` is out of the range of the array,
          // this will throw automatically and revert all
          // changes.
          proposals[proposal].voteCount += sender.weight;
      }

      /// @dev Computes the winning proposal taking all
      /// previous votes into account.
      function winningProposal() constant
              returns (uint winningProposal)
      {
          uint winningVoteCount = 0;
          for (uint p = 0; p < proposals.length; p++) {
              if (proposals[p].voteCount > winningVoteCount) {
                  winningVoteCount = proposals[p].voteCount;
                  winningProposal = p;
              }
          }
      }

      // Calls winningProposal() function to get the index
      // of the winner contained in the proposals array and then
      // returns the name of the winner
      function winnerName() constant
              returns (bytes32 winnerName)
      {
          winnerName = proposals[winningProposal()].name;
      }
  }

*)

contract ballot

export init, giveRightToVote, delegate, vote, winning_proposal, winner_name

type Voter = { .weight   : UInt
             , .voted    : Bool
             , .delegate : Option Address
             , .vote      : Option UInt }

type Proposal = { .name      : String
                , .voteCount : UInt }

type State = { .chairPerson : Address
             , .voters      : Map Address Voter
             , .proposals   : List Proposal }

fun init (proposalNames : List String) : State =
  { .chairPerson = @caller
  , .voters      = Map.empty with { @caller = init_voter }
  , .proposals   = List.map mk_proposal proposalNames }

fun giveRightToVote (voter : address) : Result () =
  if (@caller == @state.chairPerson) and (@state.voters[voter] == None) then
    { .state = @state with { .voters = @state.voters with { voter = init_voters } }

fun delegate (delegateTo : address) : Result ()
  let _ = assert (delegateTo != @caller)
  and voter : Voter = get_voter @caller
  and assert !@state.voters[@caller].voted
  and finalDelegateTo : address = delegate_chain delegateTo in
  and voter' = voter with { .voted = true, .delegate = final_delegateTo }
  and state' = (delegate_vote finalDelegateTo voter.weight).state in
  { .state = state' with { .voters = state'.voters with { @caller = voter' } } }

fun delegate_vote (delegateTo : address) (count : UInt) : Result () =
  let voter = get_voter delegateTo in
  if voter.voted then
    add_vote voter.vote count
  else
    let voter' = voter with { .weight = voter.weight + count } in
    { .state = @state with { .voters = @state.voters with { delegateTo = voter' } } }

fun vote (candidate : UInt) : Result () =
  let voter = get_voter @caller
  and _ = assert !voter.voted
  and state' = (add_vote candidate voter.weight).state
  and voter' = voter with { .voted = true, .vote = candidate } in
  { .state = state' with { .voters = @state'.voters with { @caller = voter' } } }

fun add_vote (candidate : UInt) (count : UInt) : Result () =
  let proposal = @state.proposals[candidate]
  and _ = assert (proposal != None)
  and proposal' = proposal with { .voteCount = proposal.voteCount + count } in
  { .state = @state with { .proposals = @state.proposals with { candidate = proposal' } } }

const fun winning_proposal () : Proposal =
  match @state.proposals with
   | [] -> abort
   | p :: ps -> winning_proposal' p ps

pure funrec winning_proposal' (p : Proposal) (ps : List Proposal) : Proposal =
  match ps with
   | []        -> p
   | p' :: ps' -> let p1 = if p.voteCount > p'.voteCount then p else p' in
                  winning_proposal' p1 ps'

const fun winner_name () : String = winning_proposal.name

(* Helper funs *)
pure fun mk_proposal (name' : string) : Propsal = { .name = name', .voteCount = 0 }

const funrec delegate_chain (delegateTo : address)
  if delegateTo == @caller then abort (* loops in delegate chain not allowed! *)
  else
    let voter = get_voter delegateTo in
    if voter.delegate != #0 then delegate_chain voter.delegate else delegateTo

pure fun init_voter () : Voter =
  { .weight = 1, .voted = false, .address = #0, .vote = 0 }

(* This could/should be a built-in function?! *)
pure fun assert (x : Bool) : () = if x then () else abort

const fun get_voter (key : Address) : Voter =
  let voter = @state.voters[key] in
  if voter == None then abort else voter