# Repeated and inconclusive observations

Project mode accepts `--repeat N --quorum K`, with 1 <= K <= N <= 100. Defaults are
1/1 for candidates, 2/2 for baseline, and 3/3 for final verification. For repeat
values above one, baseline uses the same N/K policy. `--consecutive` requires K
consecutive successes within the N trials. `--final-repeat` must be at least three.

Each trial returns interesting, uninteresting or unresolved. Missing differential
observations, malformed wrapper JSON, truncated relevant output, regex exhaustion
and timeout-tolerance ambiguity are unresolved. They are never cached as false.
The policy accepts only when observed successes prove the threshold, rejects only
when even all unresolved values succeeding cannot meet it, and otherwise remains
unresolved. Successful baseline/final decisions require all configured trials.

Reports include observed attempts, resolved count, passed count, rate and Wilson
95% bounds. Rate uses resolved trials as denominator. These are descriptive
statistics, not a claim that trials are independent or that a bug has a proved
probability. `probabilistic` is true whenever quorum is below repeat.

A differential trial launches two commands in separate fresh copies and counts
both against the command budget. Final verification bypasses the candidate cache.
The owned `process_probe flaky` fixture uses an explicit external counter with
four successes per five launches; native E2E checks 5/4 baseline, candidate, final
statistics and replay. It is intended for jobs=1 because its counter is serial.
