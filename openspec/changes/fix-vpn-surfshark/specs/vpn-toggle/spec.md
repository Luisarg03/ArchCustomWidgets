# vpn-toggle — ADDED Requirements

## ADDED Requirements

### Requirement: VPN quick-toggle MUST connect and disconnect the tunnel reliably

The quick-toggles VPN button MUST bring up the `surfshark` WireGuard interface with the nft kill-switch active, and MUST tear both down cleanly.

#### Scenario: Connect via button

- Given the unit installed and the button pressed
- When the connect command runs
- Then the `surfshark` interface exists and the nft output chain drops non-tunnel traffic

#### Scenario: Disconnect via button

- Given the tunnel up
- When the disconnect command runs
- Then the interface is removed and nftables is restored from `/etc/nftables.conf` with no leftover kill-switch state

#### Scenario: No manual root required

- Given a user pressing the button
- When connect or disconnect executes
- Then it succeeds without the user typing sudo commands (polkit or equivalent handled)
