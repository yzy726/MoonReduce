# Multi-file reduction

From the repository root:

```text
moon run cmd/main -- reduce --project --config testdata/final/multi_file_project/predicate.json --workspace testdata/final/multi_file_project/input --output ./multi-file-result
moon run cmd/main -- replay ./multi-file-result/report.json
```

The fixture has one failing source and four irrelevant files. Inspect `reduced/`,
`reduction.diff`, file scores and the three final observations in `report.json`.
Use a new output name each time. Protected manifests remain in the result.
