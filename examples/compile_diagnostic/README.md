# compile_diagnostic

From the MoonReduce repository root:

```text
moon run cmd/main -- reduce --config testdata/compile_diagnostic/predicate.json --workspace testdata/compile_diagnostic/input --output ./compile_diagnostic-result
```

Use a new output directory outside the input project. Output currently resolves
relative to the invocation directory. Inspect report.json and reproduce.txt.

