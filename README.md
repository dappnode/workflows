# DAppNode Workflows

Centralized reusable GitHub Actions workflows for the DAppNode organization.
Every package repo (e.g. `DAppNodePackage-reth-generic`) calls these via
`uses: dappnode/workflows/.github/workflows/<workflow>.yml@master` and passes
org-level secrets with `secrets: inherit`.

## Available Workflows

| Workflow | Description | Used by |
|----------|-------------|---------|
| [`bump-upstream.yml`](.github/workflows/bump-upstream.yml) | Check and bump upstream versions (`tropibot bump-runner`) | All staking packages |
| [`staking-release.yml`](.github/workflows/staking-release.yml) | Build → test → release pipeline | All staking packages |
| [`staking-sync-test.yml`](.github/workflows/staking-sync-test.yml) | Build + sync test (typically on PRs) | All staking packages |
| [`staking-attestation-test.yml`](.github/workflows/staking-attestation-test.yml) | Build + proof-of-attestation test (typically on PRs) | All staking packages |
| [`sync-production.yml`](.github/workflows/sync-production.yml) | Daily production sync with Discord failure notifications | EL packages |
| [`onchain-release-sync.yml`](.github/workflows/onchain-release-sync.yml) | Sync release metadata with on-chain published hashes | Packages using tropibot onchain sync |
| [`notify-discord.yml`](.github/workflows/notify-discord.yml) | Internal Discord failure notifier (called by `sync-production.yml`) | Reusable, not called directly |

## Scripts

| Script | Description |
|--------|-------------|
| [`scripts/discord-notify.sh`](scripts/discord-notify.sh) | Posts a Discord embed on sync failures; sourced by `notify-discord.yml` |

## Usage

All caller stubs use `secrets: inherit` to pass org-level secrets automatically.
Inputs with sensible defaults can be omitted entirely.

### Bump Upstream

```yaml
name: Bump upstream version
on:
  schedule:
    - cron: "00 */4 * * *"
  workflow_dispatch:
  push:
    branches: ["master", "main"]
jobs:
  bump-upstream:
    uses: dappnode/workflows/.github/workflows/bump-upstream.yml@master
    secrets: inherit
```

Optional override inputs for repos that need explicit TropiBot bump configuration:

| Input | Purpose |
|-------|---------|
| `use_variants` | Include variant manifests/compose files in bump scan (default: `true`) |
| `variants_dir` | Path to variants directory (default: `variants`) |
| `tag_pattern` | Regex to extract version from upstream release tag |
| `docker_tag_pattern` | Template for Docker tag checks, e.g. `multiarch-{version}` |
| `build_arg` | Compose build arg override for the targeted upstream |
| `upstream_repo` | Upstream repo slug to target env overrides at a specific dependency |
| `dry_run` | Log write operations without executing them (default: `false`) |

Example with overrides:

```yaml
jobs:
  bump-upstream:
    uses: dappnode/workflows/.github/workflows/bump-upstream.yml@master
    with:
      upstream_repo: "testinprod-io/op-erigon"
      tag_pattern: "^v(.+)$"
    secrets: inherit
```

For repos with mixed upstream version formats, omit override inputs and let
`bump-runner` resolve the target Docker tag format per upstream through its
registry inference path.

### Release (Execution Client)

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
  push:
    branches: ["main"]
    paths-ignore: ["README.md"]
jobs:
  release:
    uses: dappnode/workflows/.github/workflows/staking-release.yml@master
    with:
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

### Release (Consensus Client)

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      execution_client:
        type: choice
        options: [geth, nethermind, besu, erigon, reth]
  push:
    branches: ["main"]
    paths-ignore: ["README.md"]
jobs:
  release:
    uses: dappnode/workflows/.github/workflows/staking-release.yml@master
    with:
      consensus_client: "lodestar"
      execution_client: ${{ inputs.execution_client || '' }}
    secrets: inherit
```

`staking-release.yml` inputs (all optional):

| Input | Purpose | Default |
|-------|---------|---------|
| `package_variant` | DAppNodeSDK variant to build | `hoodi` |
| `consensus_client` | CL to use in tests | `""` (let runner resolve) |
| `execution_client` | EL to use in tests | `""` (let runner resolve) |
| `runner_label` | Self-hosted runner for build + test | `staking-test-hoodi` |
| `publish_runner_label` | Self-hosted runner for the publish step | `ipfs-dev-gateway` |
| `timeout` | Publish timeout | `2h` |

### Sync Test (Execution Client)

```yaml
name: Execution Client Sync Test
on:
  workflow_dispatch:
    inputs:
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
  pull_request:
    branches: ["main"]
    paths-ignore: ["README.md"]
jobs:
  sync-test:
    uses: dappnode/workflows/.github/workflows/staking-sync-test.yml@master
    with:
      execution_client: "erigon"
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

### Sync Test (Consensus Client)

```yaml
name: Execution Client Sync Test
on:
  workflow_dispatch:
    inputs:
      execution_client:
        type: choice
        options: [geth, nethermind, besu, erigon, reth]
  pull_request:
    branches: ["main"]
    paths-ignore: ["README.md"]
jobs:
  sync-test:
    uses: dappnode/workflows/.github/workflows/staking-sync-test.yml@master
    with:
      consensus_client: "lodestar"
      execution_client: ${{ inputs.execution_client || '' }}
    secrets: inherit
```

`staking-sync-test.yml` accepts the same shape of inputs as
`staking-release.yml` plus:

| Input | Purpose | Default |
|-------|---------|---------|
| `pr_number` | PR number to report results on | `""` |
| `head_ref` | PR head branch ref to checkout | `""` |
| `sender` | User who triggered the test | `""` |

### Attestation Test

```yaml
name: Attestation Test
on:
  pull_request:
    branches: ["main"]
    paths-ignore: ["README.md"]
  workflow_dispatch:
    inputs:
      execution_client:
        type: choice
        options: [geth, nethermind, besu, erigon, reth]
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
jobs:
  attestation:
    uses: dappnode/workflows/.github/workflows/staking-attestation-test.yml@master
    with:
      execution_client: ${{ inputs.execution_client || '' }}
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

`staking-attestation-test.yml` accepts the same input shape as
`staking-sync-test.yml` and runs a proof-of-attestation check against the
built package instead of a full sync.

### Sync Production (Execution Clients only)

```yaml
name: Execution Client Sync Production
on:
  schedule:
    - cron: "0 5 * * *"
  workflow_dispatch:
    inputs:
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
jobs:
  sync:
    uses: dappnode/workflows/.github/workflows/sync-production.yml@master
    with:
      execution_client: "erigon"
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

`sync-production.yml` inputs:

| Input | Purpose | Default |
|-------|---------|---------|
| `execution_client` | EL to sync (`geth`, `reth`, `nethermind`, `besu`, `erigon`) | _required_ |
| `consensus_client` | CL override | `""` |
| `network` | Network to sync | `hoodi` |
| `runner_label` | Self-hosted runner label | `staking-test-hoodi` |

Required caller secret: `DISCORD_STAKERS_TESTS_WEBHOOK`.

> The internal `notify` job fires automatically when `sync` fails and posts
> to Discord via [`notify-discord.yml`](.github/workflows/notify-discord.yml)
> + [`scripts/discord-notify.sh`](scripts/discord-notify.sh).

### Onchain Release Sync

```yaml
name: Onchain Release Sync
on:
  schedule:
    - cron: "00 */6 * * *"
  workflow_dispatch:
    inputs:
      all_repos:
        type: boolean
        default: false
jobs:
  onchain-sync:
    uses: dappnode/workflows/.github/workflows/onchain-release-sync.yml@master
    with:
      dry_run: ${{ github.event_name == 'workflow_dispatch' }}
    secrets: inherit
```

`onchain-release-sync.yml` inputs:

| Input | Purpose | Default |
|-------|---------|---------|
| `graphql_endpoint` | DApp Explorer endpoint (POST URL, no `/graphql` suffix) | gateway endpoint |
| `dry_run` | Do not mutate releases | `true` |
| `fail_on_partial` | Fail job if partial sync errors are detected | `false` |
| `max_releases_per_repo` | Per-repo release scan cap | `20` |
| `max_release_age_days` | Ignore old releases | `120` |
| `prerelease_only` | Process only prereleases | `true` |
| `rust_log` | Rust log level | `info` |

Required caller secrets: `TROPI_APP_PRIVATE_KEY`, `ONCHAIN_GRAPHQL_BEARER_TOKEN`.

## Packages Using These Workflows

### Execution Clients
erigon, geth, nethermind, besu, reth — each has 4 stubs:
- `bump-upstream.yml` → `bump-upstream`
- `release.yml` → `staking-release`
- `sync-test.yml` → `staking-sync-test`
- `sync-production.yml` → `sync-production`

### Consensus Clients
lodestar, lighthouse, nimbus, prysm, teku — each has 3 stubs:
- `bump-upstream.yml` → `bump-upstream`
- `release.yml` → `staking-release`
- `sync-test.yml` → `staking-sync-test`

## Required Org-Level Configuration

### Secrets

| Secret | Used by |
|--------|---------|
| `TROPI_APP_PRIVATE_KEY` | All tropibot-driven workflows (release, sync-test, attestation, bump, onchain sync) |
| `PINATA_API_KEY` / `PINATA_SECRET_API_KEY` | `bump-upstream` (IPFS pinning) |
| `DISCORD_STAKERS_TESTS_WEBHOOK` | `sync-production` failure notifications |
| `ONCHAIN_GRAPHQL_BEARER_TOKEN` | `onchain-release-sync` |

### Variables

| Variable | Used by |
|----------|---------|
| `TROPI_APP_ID` | All tropibot-driven workflows (GitHub App client ID, accessed via `vars` context) |

### Self-Hosted Runners

| Label | Purpose |
|-------|---------|
| `staking-test-hoodi` | DAppNode runner for build and sync tests |
| `ipfs-dev-gateway` | Runner with IPFS access for publishing |

## Design Decisions

- **`secrets: inherit`** — minimal stubs; org-level secrets flow automatically.
- **`vars.TROPI_APP_ID`** — accessed from the caller's `vars` context, no need to pass as a secret.
- **`@master` ref** — internal trust within the org, no version pinning needed.
- **`dappnode/tropibot:latest`** — single Docker image powers both `test-runner` and `bump-runner`.
- **Bidirectional testing** — EL packages fix their client name and parameterize the CL; CL packages do the reverse, so the same workflows cover both directions.
- **Cross-repo script checkout** — `notify-discord.yml` checks out `dappnode/workflows` (not the caller) with `repository: dappnode/workflows` + `sparse-checkout: scripts` to retrieve `discord-notify.sh`. Reusable workflows check out the caller repo by default, which is the typical reason "script not found" errors occur.
