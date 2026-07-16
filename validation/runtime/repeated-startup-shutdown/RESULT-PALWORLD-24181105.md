# Palworld Repeated Startup and Shutdown Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Loader SHA-256 | `1f1459b01ff3de75ea637097c0a1ef7bf141e2b2b93369351b22c16105ec1f73` |
| Lua fixture SHA-256 | `c144e20be66c69d3804a0a45416188c9487293fdbb94a09b65d63a1e77be1b23` |
| Harness SHA-256 | `6c00da156f2a8da927194b0480bcddd847f7790598ba5de72dbad048977b96a5` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

Five complete fresh-process startup and graceful-shutdown cycles were
performed.

Observed cycle matrix:

```text
cycle  startup_seconds  shutdown_seconds  shutdown_sigints  controller_status  result
1      9                4                 1                 130                PASS
2      9                16                2                 130                PASS
3      9                4                 1                 130                PASS
4      9                5                 1                 130                PASS
5      9                4                 1                 130                PASS
```

Final result:

```text
RequestedCycles=5
PassedCycles=5
FailedCycles=0
RESULT=PASS
```

Every cycle successfully:

- loaded UE4SS in a fresh PalServer process;
- executed the Lua startup acceptance fixture;
- opened UDP ports 8212 and 27016;
- ran in the scoped `palworld_ue4ss_t` SELinux domain;
- shut down through process-group `SIGINT` handling;
- released both test ports.

Four cycles completed after one `SIGINT`. One cycle required a second
`SIGINT` after the initial grace period. No forced termination was required.

The controller status was `130` for every cycle, consistent with
interrupt-driven process termination.

After the final cycle:

- no isolated PalServer process remained;
- no test listener remained active;
- no cycle failure record existed.

Audit archive SHA-256:

`f57c788643904479ef252e0ccd7bac4a8fa391b9745e60269d06714ce6d5d059`
