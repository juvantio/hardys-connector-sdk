# Governance

## Proposing a contract change (existing class)

**Non-breaking (always safe):**
- Adding a new field (use next available field number)
- Adding a new message or rpc
- Adding a new enum value

**Breaking (requires major version bump):**
- Removing or renaming a field
- Changing a field number or type
- Removing an rpc

**Process:**
1. Open a PR with the proto change and motivation
2. Tag with the relevant class label (e.g. `class:lecture`)
3. For breaking changes: include migration guide, bump package version
   (e.g. `hardys.connector.lecture.v2`)
4. Update the class SDK repo after proto is merged

## Proposing a new connector class

A new class is needed when a new *category* of integration is required —
not a new platform within an existing category.

Examples warranting a new class:
- Content repositories (documents, recordings) → `content` class
- Identity systems (user profiles, roles) → `identity` class

Examples that do NOT warrant a new class:
- New video conferencing platform (Teams, Zoom) → `lecture` class, new connector_id

**Process:**
1. Open an issue describing: what it integrates, data flows needed, why existing classes don't fit
2. If approved: new proto file, new class SDK repo, new entry in `docs/connector-classes.md`, new section in HCF v1.0

## Versioning policy

Proto packages follow semantic versioning in the package name:
- `hardys.connector.lecture.v1` — current stable
- `hardys.connector.lecture.v2` — future breaking change

Hardys Core may support multiple versions simultaneously during migrations.
