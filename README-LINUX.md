# RE-UE4SS Linux

This repository is an unofficial downstream Linux port and distribution of
RE-UE4SS. It currently focuses on native x86-64 Linux Unreal Engine dedicated
servers, beginning with Palworld 1.0 on Unreal Engine 5.1.

## Project status

Experimental. This project is not yet recommended for production servers.

## Current validated functionality

- Native Linux UE4SS startup through `LD_PRELOAD`
- Palworld 1.0 dedicated-server initialization
- Lua mod discovery and execution
- Native lifecycle hook registration
- Native-to-Lua callbacks
- UObject, UClass, UWorld, FName, FString, and FText access
- Reflected primitive numeric property reads
- Controlled reflected numeric property write, readback, and restoration
- Read-only reflected UFunction lookup, invocation, and primitive return conversion
- Primitive reflected UFunction input-parameter marshalling
- Reflected pre-hook context and primitive-parameter handling
- Scoped SELinux operation without global `execheap`

## Scope

The current compatibility evidence applies only to explicitly tested game,
engine, operating-system, and build combinations. It must not be interpreted as
general compatibility with every Unreal Engine game or server.

## Relationship to upstream

This project is not affiliated with or supported by the official UE4SS project.

The source history derives from:

- UE4SS-RE/RE-UE4SS
- tc-imba/RE-UE4SS `linux-port`

The imported Linux baseline is tagged:

`tc-imba-linux-port-baseline-407d14c`

Portable fixes may be proposed upstream separately as small, independently
reviewable changes.
