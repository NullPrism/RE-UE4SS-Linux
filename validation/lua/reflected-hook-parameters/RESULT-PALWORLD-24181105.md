# Palworld Reflected Hook Parameter Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Fixture SHA-256 | `a3d273835e36a0fc1363fe5d943b2213ceb582fee6c8305cc80d0319e6d0e8d8` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

The fixture registered a reflected pre-hook for:

`/Script/Engine.Actor:SetActorTickInterval`

Both callback arguments arrived as `RemoteUnrealParam` userdata.

Observed callback values:

```text
context parameter wrapper type=RemoteUnrealParam
tick interval parameter wrapper type=RemoteUnrealParam
hook interval Lua type=number
hook interval value=1.0
context matches target=true
interval delta=0.0
interval matches target=true
matching pre-hook callback observed
```

Observed cleanup and verification:

```text
hook unregistered
readback tick interval=1.0
readback delta=0.0
state unchanged=true
hook callback count=1
matching callback seen=true
callback error seen=false
RESULT=PASS
```

This validates reflected pre-hook context and primitive-parameter handling
through `RemoteUnrealParam:get()`.

The setter was invoked using the actor's existing tick interval, so the final
actor state remained unchanged.

No Lua exception, nonempty crash record, or SELinux AVC was observed.

The runtime emitted the existing warning that vtable and scan addresses differ
for `UGameEngine::Tick`. This warning occurred during loader initialization
and was not introduced by this fixture.
