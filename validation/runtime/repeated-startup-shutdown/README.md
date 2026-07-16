# Repeated Startup and Shutdown Acceptance Test

This fixture validates repeated native Linux UE4SS initialization and graceful
Palworld Dedicated Server shutdown across fresh host processes.

The harness performs five complete cycles. Each cycle:

1. Clears prior UE4SS logs and crash records.
2. Starts PalServer and UE4SS in a fresh process group.
3. Locates the actual `PalServer-Linux-Shipping` process.
4. Waits for the Lua startup acceptance marker.
5. Verifies UDP listeners on ports 8212 and 27016.
6. Verifies the process is running in the scoped
   `palworld_ue4ss_t` SELinux domain.
7. Verifies the expected loader identity.
8. Sends `SIGINT` to the isolated process group.
9. Sends a second `SIGINT` when the first does not complete shutdown within
   the configured grace period.
10. Confirms that the process exits and both test ports are released.

The harness never uses `dlclose`. Each cycle uses a completely fresh PalServer
process.

## Safety constraints

- Run only against the isolated `palworld-2` acceptance instance.
- Do not run against the production Palworld server.
- Use test ports 8212 and 27016.
- Do not weaken the global SELinux policy.
- Do not forcibly terminate a cycle unless graceful interrupt handling fails.
- Preserve generated audit archives outside the Git repository.

## Pass criteria

The acceptance test passes only when:

- Every requested startup reaches the Lua `RESULT=PASS` marker.
- Both test UDP ports are active during every cycle.
- The PalServer process runs in `palworld_ue4ss_t`.
- Every process exits after graceful interrupt handling.
- Both ports are released after every shutdown.
- No isolated PalServer process survives the final cycle.
- No cycle records a failure.
- The harness emits a final `RESULT=PASS`.
