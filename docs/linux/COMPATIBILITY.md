# Linux Compatibility Matrix

## Palworld Dedicated Server

| Component | Validated value |
|---|---|
| Game | Palworld |
| Game version | 1.0.1.100619 |
| Steam build ID | 24181105 |
| Unreal Engine | 5.1.1 |
| Architecture | x86-64 |
| Distribution | Fedora Linux |
| Loader baseline | 407d14cf3c485a150cd157fd581643c901dd9b0e |
| Loader artifact | `libUE4SS.so` |
| Loading method | Process-lifetime `LD_PRELOAD` |

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
| Reflected property write | Pending |
| Reflected UFunction invocation | Pending |
| Hook parameter handling | Pending |
| Repeated startup/shutdown | Pending |
| Native C++ mod loading | Pending |
| Existing third-party mod compatibility | Pending |

## Limitations

- Do not unload UE4SS with `dlclose`.
- Stop the host process to unload the loader.
- Native private C++ members are not automatically exposed as reflected Lua
  properties.
- Dependency commits are not yet guaranteed to be reachable through stable
  public submodule remotes.
