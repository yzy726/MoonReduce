# Custom evaluator, pass and event sink

```text
moon run examples/custom_pass --target native
moon run examples/custom_pass --target js
moon run examples/custom_pass --target wasm-gc
```

The executable imports the public facade, proposes removing a known prefix,
validates the KEEP marker through a custom evaluator and collects final events.
It prints the reduced source and exactly three final observations. No filesystem
or external process is needed. The engine still enforces selection and protection.
