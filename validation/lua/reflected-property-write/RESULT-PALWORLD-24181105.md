# Palworld Reflected Property Write Result

## Environment

| Component | Value |
|---|---|
| Game | Palworld Dedicated Server |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Loader baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Fixture SHA-256 | `06e53fa447fd9e009a9d6616e13bd2a9e4fbeb937b38bd5d67443dd2e4f9bf99` |
| Test date | 2026-07-16 UTC |

## Result

**PASS**

Observed sequence:

```text
original Lua type=number
original value=1.0
temporary target=0.99
temporary write completed
temporary readback Lua type=number
temporary readback value=0.99000000953674
temporary readback verified=true
restore write completed
restored readback Lua type=number
restored readback value=1.0
restore verified=true
RESULT=PASS


The temporary value was successfully written through UE4SS reflection, read
back as an Unreal single-precision float, and restored to the original value.

No Lua exception, segmentation fault, nonempty crash record, or property
restoration failure was observed.

The runtime emitted the existing warning that the vtable and scan addresses
for UGameEngine::Tick differ. This warning occurred during loader
initialization and was not introduced by the property-write fixture.
