# Palworld Reflected UFunction Parameter Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Fixture SHA-256 | `c85e040fccdffdd266c43aadf47ead3ae57515515f4daf4fd8ed92daede79005` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

The fixture resolved:

`Function /Script/Engine.KismetMathLibrary:Add_IntInt`

Observed invocation:

```text
left argument=20
right argument=22
expected result=42
invocation completed
return Lua type=number
return value=42
result verified=true
RESULT=PASS
```

This validates primitive integer input marshalling and primitive integer return
conversion through the reflected ProcessEvent path.

No persistent game state was modified. No Lua exception, nonempty crash record,
or SELinux AVC was observed.

The runtime emitted the existing warning that vtable and scan addresses differ
for `UGameEngine::Tick`. This warning occurred during loader initialization
and was not introduced by this fixture.
