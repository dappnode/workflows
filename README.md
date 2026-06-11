# DAppNode Workflows

Centralized reusable GitHub Actions workflows for the DAppNode organization.

## Available Workflows

| Workflow | Description | Used by |
|----------|-------------|---------|
| [`bump-upstream.yml`](.github/workflows/bump-upstream.yml) | Check and bump upstream versions (tropibot bump-runner) | All staking packages |
| [`staking-release.yml`](.github/workflows/staking-release.yml) | Build → test → release pipeline | All staking packages |
| [`staking-sync-test.yml`](.github/workflows/staking-sync-test.yml) | Sync test on PRs | All staking packages |
| [`sync-production.yml`](.github/workflows/sync-production.yml) | Daily production sync + Discord notification | EL packages |
| [`onchain-release-sync.yml`](.github/workflows/onchain-release-sync.yml) | Sync release metadata with on-chain published hashes | Packages that use tropibot onchain sync |
| [`notify-discord.yml`](.github/workflows/notify-discord.yml) | Discord failure notifications | Internal (called by sync-production) |

## Usage

All caller stubs use `secrets: inherit` to pass org-level secrets automatically.

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

Optional override inputs are available for repos that need explicit TropiBot bump configuration:

```yaml
jobs:
  bump-upstream:
    uses: dappnode/workflows/.github/workflows/bump-upstream.yml@master
    with:
      upstream_repo: "testinprod-io/op-erigon"
      tag_pattern: "^v(.+)$"
    secrets: inherit
```

For repos with mixed upstream version formats, omit override inputs and let `bump-runner`
resolve the target Docker tag format per upstream through its registry inference path.

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
      all_repos: ${{ inputs.all_repos || false }}
      dry_run: ${{ github.event_name == 'workflow_dispatch' }}
    secrets: inherit
```

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
- `TROPI_APP_PRIVATE_KEY` — GitHub App private key for automated PRs/tokens
- `PINATA_API_KEY` / `PINATA_SECRET_API_KEY` — IPFS pinning (bump-upstream)
- `DISCORD_STAKERS_TESTS_WEBHOOK` — Discord failure notifications (sync-production)

### Variables
- `TROPI_APP_ID` — GitHub App ID (non-sensitive, accessed via `vars` context)

### Self-Hosted Runners
- `staking-test-hoodi` — DAppNode runner for build and sync tests
- `ipfs-dev-gateway` — Runner with IPFS access for publishing

## Design Decisions

- **`secrets: inherit`** — minimal stubs, org-level secrets flow automatically
- **`vars.TROPI_APP_ID`** — accessed from caller's `vars` context (no need to pass as secret)
- **`@master` ref** — internal trust within org, no version pinning needed
- **`dappnode/tropibot:latest`** — single Docker image for test-runner and bump-runner
- **Bidirectional testing** — EL packages fix their client name and parameterize the CL, CL packages do the reverse
