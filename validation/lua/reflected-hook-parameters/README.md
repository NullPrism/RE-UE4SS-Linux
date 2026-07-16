# Reflected Hook Parameter Acceptance Test

This fixture validates reflected pre-hook parameter delivery through the UE4SS
Lua API on a native Linux Unreal Engine dedicated server.

The fixture:

1. Receives a live Palworld GameMode actor.
2. Reads its existing actor tick interval.
3. Registers a reflected pre-hook for `SetActorTickInterval`.
4. Invokes the setter using the existing value.
5. Unwraps the hook context and float parameter using
   `RemoteUnrealParam:get()`.
6. Verifies the hook context, parameter value, callback count, and final actor
   state.
7. Unregisters the hook.

Hooked function:

`/Script/Engine.Actor:SetActorTickInterval`

## Safety constraints

- Run only on an isolated acceptance server.
- Do not run on production.
- Perform a full host-process restart before each test.
- Do not unload UE4SS with `dlclose`.
- Invoke the setter only with the actor's existing value.
- Unregister the hook immediately after the test invocation.

## Pass criteria

The fixture passes only when:

- Both hook arguments arrive as `RemoteUnrealParam` userdata.
- The context unwraps to the expected UObject.
- The float parameter unwraps to the expected Lua number.
- Exactly one matching callback is observed.
- No callback error is recorded.
- The hook unregisters successfully.
- The actor tick interval remains unchanged.
- The fixture emits `RESULT=PASS`.
