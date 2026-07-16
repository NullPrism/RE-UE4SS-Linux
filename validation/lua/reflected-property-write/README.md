# Reflected Property Write Acceptance Test

This fixture validates controlled reflected numeric-property mutation through
the UE4SS Lua API on a native Linux Unreal Engine dedicated server.

The test performs the following sequence against `CustomTimeDilation`:

1. Read and preserve the original value.
2. Write a temporary value.
3. Verify the temporary value through reflected readback.
4. Restore the original value.
5. Verify the restored value.

Restoration is attempted regardless of whether the temporary write or readback
succeeds.

## Safety constraints

- Run only on an isolated acceptance server.
- Do not run on production.
- Perform a full host-process restart before each test.
- Do not unload UE4SS with `dlclose`.
- Do not leave the temporary property value active.

## Floating-point behavior

`CustomTimeDilation` is exposed as an Unreal `FFloatProperty`. Lua's requested
value of `0.99` may therefore read back as a nearby IEEE-754 single-precision
value, such as:

`0.99000000953674`

The fixture verifies values using an epsilon rather than exact string or binary
equality.

## Pass criteria

The fixture passes only when all of the following are true:

- The original value is returned as a Lua number.
- The temporary assignment completes without a Lua error.
- Reflected readback approximately equals the temporary value.
- Restoration completes without a Lua error.
- Final reflected readback approximately equals the original value.
- The script emits `RESULT=PASS`.
