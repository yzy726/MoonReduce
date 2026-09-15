# Differential observations

Run the native, self-contained example:

```text
moon build --target native tools/process_probe
moon test --target native -p Ag108/MoonReduce/app -f "*differential*"
```

The primary command prints KEEP and the reference command is silent. They receive
independent copies. Reduction requires the configured primary feature and a stdout
difference. Each pair counts as two commands. For your commands use repeated
`--reference ARG` values and `--differential stdout` (or stderr, exit, any).
Use `--normalize` when comparing output that contains copy-root paths.
