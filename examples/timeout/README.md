# timeout

From the MoonReduce repository root:

```text
moon run cmd/main -- reduce --config testdata/timeout/predicate.json --workspace testdata/timeout/input --output ./timeout-result
```

Use a new output directory outside the input project. Output currently resolves
relative to the invocation directory. Inspect report.json and reproduce.txt.

Do not run automatically: descendant-process timeout cleanup remains under validation.

