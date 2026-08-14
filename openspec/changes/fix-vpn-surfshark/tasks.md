# Tasks: fix-vpn-surfshark

- [ ] Confirm toggle invocation path: how quickshell executes the shell.json connectCmd and whether it needs polkit for system units.
- [ ] Root check: /etc/wireguard/surfshark.conf completeness (PostUp/PreDown present, valid).
- [ ] Root check: `nft list ruleset` state after a connect attempt (kill-switch chains stuck?).
- [ ] Decide daemon role: enable surfsharkd/surfsharkd2, or make the toggle work without them.
- [ ] Apply the fix in the vpn-surfshark unit (systemd units, install.sh, shell.json delta).
- [ ] Validate: toggle connect → surfshark iface up + output policy drop active; toggle disconnect → rules restored, no leftover state; factory/validate passes.
