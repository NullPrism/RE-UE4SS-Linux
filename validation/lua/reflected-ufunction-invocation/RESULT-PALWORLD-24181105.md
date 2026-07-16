# Palworld Reflected UFunction Invocation Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Fixture SHA-256 | `897b6696d29f5127e627af96bcddda039474f54e6dca3b07c7788b2192c6b67f` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

The following inherited Actor functions resolved as valid reflected UFunctions:

- `GetActorTimeDilation`
- `GetGameTimeSinceCreation`
- `GetActorTickInterval`
- `IsActorTickEnabled`
- `HasAuthority`

The fixture selected:

`Function /Script/Engine.Actor:GetActorTimeDilation`

Observed invocation result:

```text
invocation completed
return Lua type=number
return value=1.0
numeric return finite=true
getter/property delta=0.0
return type verification=true
RESULT=PASS
```

The reflected getter returned the same value as the independently read
`CustomTimeDilation` property.

No Lua exception, nonempty crash record, property mutation, or SELinux AVC was
observed.

The runtime emitted the existing warning that vtable and scan addresses differ
for `UGameEngine::Tick`. This warning occurred during loader initialization
and was not introduced by the UFunction fixture.
