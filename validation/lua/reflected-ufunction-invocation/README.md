# Reflected UFunction Invocation Acceptance Test

This fixture validates reflected UFunction discovery and invocation through the
UE4SS Lua API on a native Linux Unreal Engine dedicated server.

The fixture:

1. Receives a live `BP_PalGamemode_C` UObject.
2. Resolves several inherited `AActor` UFunctions by name.
3. Confirms that the resulting callable userdata is valid.
4. Invokes the first valid zero-parameter getter.
5. Verifies that its return value is converted to a normal Lua primitive.

The selected function is expected to be:

`/Script/Engine.Actor:GetActorTimeDilation`

## Safety constraints

- Run only on an isolated acceptance server.
- Do not run on production.
- Perform a full host-process restart before each test.
- Do not unload UE4SS with `dlclose`.
- Invoke only known, read-only, zero-parameter getter functions.

## Pass criteria

The fixture passes only when:

- A reflected getter resolves to valid callable userdata.
- Invocation completes without a Lua exception.
- The result is returned as the expected Lua primitive type.
- Numeric output is finite.
- The fixture emits `RESULT=PASS`.
