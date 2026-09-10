# test_failure

From the MoonReduce repository root:

```text
moon run cmd/main -- reduce --config testdata/test_failure/predicate.json --workspace testdata/test_failure/input --output ./test_failure-result
```

Use a new output directory outside the input project. Output currently resolves
relative to the invocation directory. Inspect report.json and reproduce.txt.

