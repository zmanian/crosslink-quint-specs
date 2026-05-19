module CrosslinkTenderlinkGossipRouter {
  /*
   Tenderlink gossip router contract.

   The current Tenderlink transport slices already pin exact packet/evidence
   bytes, nonce replay checks, and status packet layout. They reuse generic
   state variable names such as `firedAction` and `transportFiredAction`, so a
   single stateful alias-import composition collides in Quint today. This module
   therefore exposes the shared route namespace contract directly and delegates
   the bounded safety model to CrosslinkTenderlinkGossipRouterSafety.qnt.

   The contract still records the production-facing lanes we need to preserve:
   proposal/POL compact consensus packets, accountability-evidence gossip,
   known-peer consensus packets after nonce/ack checks, and status packets all
   stay on the Crosslink consensus topic but occupy separate router channels
   and message kinds.
   */

  import CrosslinkTenderlinkGossipRouterSafety.* from
    "./CrosslinkTenderlinkGossipRouterSafety"
  export CrosslinkTenderlinkGossipRouterSafety.*

  pure def TenderlinkRouterContractCoversCurrentTransportLanes: bool =
    ConsensusRouteValid(ProposalChunkEnvelope) and
    ConsensusRouteValid(PolPrevoteEnvelope) and
    EvidenceRouteValid(AccountabilityEvidenceEnvelope) and
    KnownPeerRouteValid(KnownPeerEnvelope) and
    StatusRouteValid(StatusEnvelope)

  pure def TenderlinkRouterRejectsCrossLaneKinds: bool =
    not(EvidenceRouteValid(ProposalKindOnEvidenceChannel)) and
    not(ConsensusRouteValid(EvidenceKindOnConsensusChannel)) and
    not(StatusRouteValid(KnownPeerKindOnStatusChannel)) and
    not(KnownPeerRouteValid(StatusKindOnKnownPeerChannel))
}

module CrosslinkTenderlinkGossipRouterTest {
  import CrosslinkTenderlinkGossipRouter.* from
    "./CrosslinkTenderlinkGossipRouter"
  export CrosslinkTenderlinkGossipRouter.*

  action routerUnchangedAll: bool =
    all {
      routedConsensusEnvelopes' = routedConsensusEnvelopes,
      routedEvidenceEnvelopes' = routedEvidenceEnvelopes,
      routedKnownPeerEnvelopes' = routedKnownPeerEnvelopes,
      routedStatusEnvelopes' = routedStatusEnvelopes,
      routerFiredAction' = routerFiredAction,
    }

  run tenderlinkRouterContractCoversCurrentTransportLanesTest = {
    RouterInit.then(all {
      assert(TenderlinkRouterContractCoversCurrentTransportLanes),
      assert(TenderlinkChannelsDisjoint),
      assert(RouterSafety),
      routerUnchangedAll,
    })
  }

  run tenderlinkRouterRejectsCrossLaneKindsTest = {
    RouterInit.then(all {
      assert(TenderlinkRouterRejectsCrossLaneKinds),
      routerUnchangedAll,
    })
  }
}

module CrosslinkTenderlinkGossipRouterModel {
  import CrosslinkTenderlinkGossipRouterTest.* from
    "./CrosslinkTenderlinkGossipRouter"
  export CrosslinkTenderlinkGossipRouterTest.*
}
