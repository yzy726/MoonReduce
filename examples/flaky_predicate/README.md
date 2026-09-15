# Four out of five predicate observations

The deterministic test harness has an external counter and suppresses one in five
matches. Run the complete executable example with:

```text
moon build --target native tools/process_probe
moon test --target native -p Ag108/MoonReduce/app -f "*real flaky*"
```

The example configures repeat=5, quorum=4, final_repeat=5, final_quorum=4 and jobs=1.
It executes real processes, checks baseline/final rate 0.8, preserves original
files and replays the evidence in fresh copies. See `app/project_test.mbt` for the
full setup. For your own predicate the equivalent flags are:

```text
--project --repeat 5 --quorum 4 --final-repeat 5 --final-quorum 4
```

Counter fixtures model serial instability; do not use them to claim independent
random trials or parallel deterministic behavior.
