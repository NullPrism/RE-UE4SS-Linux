# Downstream UEPseudo Patches

These patches apply to the pinned private UEPseudo submodule used by
RE-UE4SS-Linux.

Pinned baseline:

`79b33ae93800a8d630c97b57b792a72831ce4fa9`

## 0001: Case-preserving FName constructor

The case-preserving `FName` constructor accepts raw process-local integer
identifiers but assigns them directly to opaque `FNameEntryId` members.

The patch converts both values through:

`FNameEntryId::FromUnstableInt()`

This matches the conversion already used by adjacent `FName` constructors and
allows the `CasePreserving__*__Win64` configurations to compile.

The parent repository retains the original submodule gitlink. CI and local
build workflows apply this patch after submodule checkout.

This patch should be removed when an equivalent correction becomes available
in the pinned UEPseudo history.
