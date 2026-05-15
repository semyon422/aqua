# Shared Infrastructure (`aqua`)

## Goal
The `aqua/` tree provides reusable Lua infrastructure intended to stay general enough for use across multiple projects, including this repository and external consumers that may include `aqua` as a submodule. Changes here tend to have broad impact, so agents should favor compatibility, narrow edits, and strong verification.

## User Experience
- Systems built on `aqua/` should inherit predictable utility behavior without surprising project-specific coupling.
- Infra changes should improve stability or ergonomics across callers rather than solving one local feature in a brittle way.

## Conventions

- Keep `aqua/` general-purpose. If logic is specific to one application, feature, or product, prefer placing it in that owning project unless it is clearly reusable.
- Preserve existing public helper contracts where possible, especially in `icc`, `web`, `testing`, `thread`, and type-checking utilities.
- When a reusable helper gains a new policy or assumption, document that policy near the owning module.

## High-Risk Areas

- `aqua/icc/`: message transport and shared-memory queue primitives used by online features.
- `aqua/web/`: OpenResty and web-server integration points.
- `aqua/testing/`: shared test framework behavior.
- `aqua/typecheck/`: runtime type-checking and annotation-adjacent utilities used broadly.

## Architecture Notes

- Prefer reusable primitives over feature-specific shortcuts.
- Keep dependencies one-way where possible: application code may depend on `aqua`, but `aqua` should not grow dependencies on application-level behavior.
- Avoid encoding repository-specific policy into `aqua` unless the module is already explicitly designed around that integration boundary.
- When changing shared transport or serialization primitives used in this repository, coordinate with the owning app specs if their behavior is affected.

## Verification

- Run focused tests in `aqua/`.
- If the changed helper is consumed directly by code in this repository, also run at least one relevant downstream module test.
