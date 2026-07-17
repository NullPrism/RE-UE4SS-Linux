# Linux Compatibility Matrix

## Palworld Dedicated Server

| Component | Validated value |
|---|---|
| Game | Palworld |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Distribution | Fedora Linux 43 |
| Imported Linux baseline | `407d14cf3c485a150cd157fd581643c901dd9b0e` |
| Runtime acceptance source | `0b1c7f90a35fb2f35baf545548ea641f74418ba1` |
| Runtime-accepted packaged loader SHA-256 | `32d903487643ec91b0fadc0f6564a2ea4064b55096ba7677d96263d01f263ba7` |
| PalServer SHA-256 | `788649fa1592160faa7bcf07ccd16d474ebeaae954717bc32284b5a43028d8e7` |
| PalServer ELF build ID | `7f7e167407984ec3` |
| Loader artifact | `libUE4SS.so` |
| Loading method | Process-scoped launcher using `LD_PRELOAD` |

## Validated capabilities

| Capability | Status |
|---|---|
| UE4SS initialization | Pass |
| Signature resolution | Pass |
| Lua mod loading | Pass |
| Native lifecycle callback | Pass |
| UObject access | Pass |
| FName access | Pass |
| UClass access | Pass |
| UWorld access | Pass |
| FString property read | Pass |
| FText property read | Pass |
| Reflected numeric property read | Pass |
| Reflected property write | Pass |
| Reflected UFunction invocation | Pass |
| Reflected UFunction primitive parameters | Pass |
| Hook parameter handling | Pass |
| Repeated startup/shutdown | Pass |
| Packaged-runtime five-cycle acceptance | Pass |
| Native C++ mod loading | Pass |
| Repeated native C++ mod loading | Pass |
| Existing third-party mod compatibility | Pending |

## Limitations

- Do not unload UE4SS with `dlclose`.
- Stop the host process to unload the loader.
- Normal host-process shutdown did not invoke native mod `uninstall_mod` or the C++ destructor during validation.
- Native private C++ members are not automatically exposed as reflected Lua
  properties.
- Dependency commits are not yet guaranteed to be reachable through stable
  public submodule remotes.
