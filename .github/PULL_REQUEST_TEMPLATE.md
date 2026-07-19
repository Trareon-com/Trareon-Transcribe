## Summary
-

## Security checklist
- [ ] No secrets / tokens / `.env` in the diff
- [ ] Downloads (if any) verify integrity or are pinned
- [ ] No new telemetry / outbound audio paths
- [ ] Path operations stay under library/app data roots

## Test plan
- [ ] `pytest`
- [ ] `ruff check .`
- [ ] Manual smoke: start app, Start/Stop, Export
