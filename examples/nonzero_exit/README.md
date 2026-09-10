# nonzero_exit

From the MoonReduce repository root:

```text
moon run cmd/main -- reduce --config testdata/nonzero_exit/predicate.json --workspace testdata/nonzero_exit/input --output ./nonzero_exit-result
```

Use a new output directory outside the input project. Output currently resolves
relative to the invocation directory. Inspect report.json and reproduce.txt.

