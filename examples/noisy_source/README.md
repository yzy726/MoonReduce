# noisy_source

From the MoonReduce repository root:

```text
moon run cmd/main -- reduce --config testdata/noisy_source/predicate.json --workspace testdata/noisy_source/input --output ./noisy_source-result
```

Use a new output directory outside the input project. Output currently resolves
relative to the invocation directory. Inspect report.json and reproduce.txt.

