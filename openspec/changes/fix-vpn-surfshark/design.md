# Design: fix-vpn-surfshark

## Decisions

- **D1 — Keep wg-quick + nft kill-switch.** The connect/disconnect chain is sound at CLI level; the failure is in daemon/polkit state, not the approach.
- **D2 — Investigate before fixing.** Ranked hypotheses from diagnosis: (1) toggle targets dead/disabled daemons; (2) daemon IPC broken via missing D-Bus name (`ServiceUnknown`); (3) user-triggered `systemctl start` of system units lacks polkit rights; (4) stale kill-switch state from a prior session.
- **D3 — Parked.** No implementation until investigation tasks confirm the root cause.

## References

- Diagnosis: exp-5 report (2026-08-14). Unit: services/vpn-surfshark/.
