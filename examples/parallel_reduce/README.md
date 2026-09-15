# Deterministic native workers

```text
moon run cmd/main -- reduce --project --config testdata/final/multi_file_project/predicate.json --workspace testdata/final/multi_file_project/input --output ./parallel-result --jobs 4
```

Repeat with `--jobs 1` and another output path. Compare the reduced file SHA-256
entries in both reports. Batches always contain at most four candidates; worker
completion order cannot choose the winner. Timing and events are not byte-identical.
