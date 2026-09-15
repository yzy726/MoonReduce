# Diagnostic fingerprint

```text
moon run cmd/main -- reduce --project --config testdata/final/type_diagnostic/predicate.json --workspace testdata/final/type_diagnostic/input --output ./fingerprint-result --normalize --diagnostic-code 4014
moon run cmd/main -- replay ./fingerprint-result/report.json
```

Normalization removes copy roots, location numbers, ANSI CSI and long hexadecimal
addresses. The diagnostic code 4014 and configured Type Mismatch text must remain.
This avoids accepting unrelated parse/path failures simply because exit is nonzero.
