# Reflected UFunction Parameter Acceptance Test

This fixture validates primitive reflected-UFunction parameter marshalling
through the UE4SS Lua API on a native Linux Unreal Engine dedicated server.

The fixture:

1. Resolves the Kismet Math Library default object.
2. Resolves the reflected `Add_IntInt` UFunction.
3. Supplies two Lua integer arguments.
4. Invokes the function through ProcessEvent.
5. Verifies the primitive integer return value.

The test calls:

`Add_IntInt(20, 22)`

Expected result:

`42`

## Safety constraints

- Run only on an isolated acceptance server.
- Do not run on production.
- Perform a full host-process restart before each test.
- Do not unload UE4SS with `dlclose`.
- Use only pure functions without persistent game-state effects.

## Pass criteria

The fixture passes only when:

- KismetMathLibrary resolves as a valid UObject.
- `Add_IntInt` resolves as valid callable userdata.
- Both integer parameters are accepted.
- Invocation completes without a Lua exception.
- The return value is the Lua number `42`.
- The fixture emits `RESULT=PASS`.
