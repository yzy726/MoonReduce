# Third-party dependencies

MoonReduce's reducer, matcher, scanner, configuration and reports are original
MoonBit implementations. No third-party reducer source is copied.

| Dependency | Version | Purpose | License | Source |
|---|---|---|---|---|
| moonbitlang/async | 0.20.4 | Native process, filesystem, time and cancellation | Apache-2.0 | https://github.com/moonbitlang/async |
| moonbitlang/core | bundled toolchain | Collections, JSON, text and tests | Apache-2.0 | https://github.com/moonbitlang/core |

Dependencies remain in the ignored package cache; their licenses are preserved.

All fixtures under testdata/final are original project-owned Apache-2.0 examples.
They extend the initial fixture scenarios with removable declarations, three
compiler checks, three test failures, two explicit runtime exits, a timeout and
multi-file reduction. Each directory carries LICENSE, predicate and expected
behavior. SHA-256 is independently implemented from the standard algorithm;
no third-party hash library or reducer source was imported.
