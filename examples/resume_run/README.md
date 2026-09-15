# Budget stop and resume

```text
moon run cmd/main -- reduce --project --config testdata/final/multi_file_project/predicate.json --workspace testdata/final/multi_file_project/input --output ./resume-first-result --max-tests 12
moon run cmd/main -- resume ./resume-first-result/checkpoint.json --output ./resume-final-result --max-tests 2500
moon run cmd/main -- replay ./resume-final-result/report.json
```

The first command normally exits 4 because its budget is intentionally small.
Resume preserves known results and always runs fresh final validation. A controlled
mid-flight cancellation variant is covered by the native `cancellation persists`
E2E test. Do not modify the original input between reduce and resume.
