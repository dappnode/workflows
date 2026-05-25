# DAppNode Workflows

Centralized reusable GitHub Actions workflows for the DAppNode organization.

## Available Workflows

| Workflow | Description | Target Repos |
|----------|-------------|-------------|
| [`bump-upstream.yml`](.github/workflows/bump-upstream.yml) | Check and bump upstream versions | All DAppNodePackage-* |
| [`build-test-release.yml`](.github/workflows/build-test-release.yml) | Build on PR, publish on push | CL clients, generic packages |
| [`staking-release.yml`](.github/workflows/staking-release.yml) | Build → test → release pipeline | EL clients (geth, besu, etc.) |
| [`sync-production.yml`](.github/workflows/sync-production.yml) | Daily sync checks | EL clients |
| [`staking-full-test.yml`](.github/workflows/staking-full-test.yml) | Full attestation test (PR/dispatch) | All staking packages |
| [`staking-sync-test.yml`](.github/workflows/staking-sync-test.yml) | Sync test (PR/dispatch) | All staking packages |
| [`notify-discord.yml`](.github/workflows/notify-discord.yml) | Discord failure notifications | Internal (called by other workflows) |
| [`docker-build-push.yml`](.github/workflows/docker-build-push.yml) | Multi-platform Docker build & push | tropibot, infra tools |

## Usage

### Bump Upstream (8-line stub)

```yaml
# .github/workflows/auto_check.yml
name: Bump Upstream
on:
  schedule:
    - cron: '0 */4 * * *'
  workflow_dispatch:
jobs:
  bump:
    uses: dappnode/workflows/.github/workflows/bump-upstream.yml@main
    with:
      use_variants: true
    secrets: inherit
```

### Build Test & Release (9-line stub)

```yaml
# .github/workflows/main.yml
name: Main
on:
  pull_request:
  push:
    branches: [main, master, 'v[0-9]+.[0-9]+.[0-9]+']
    paths-ignore: ['README.md']
jobs:
  main:
    uses: dappnode/workflows/.github/workflows/build-test-release.yml@main
    with:
      build_variant: mainnet
    secrets: inherit
```

### Staking Release (12-line stub)

```yaml
# .github/workflows/release.yml
name: Release
on:
  workflow_dispatch:
    inputs:
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
  push:
    branches: [main]
    paths-ignore: ['README.md']
jobs:
  release:
    uses: dappnode/workflows/.github/workflows/staking-release.yml@main
    with:
      package_variant: hoodi
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

### Sync Production (12-line stub)

```yaml
# .github/workflows/sync.yml
name: Sync Production
on:
  schedule:
    - cron: '0 4 * * *'
  workflow_dispatch:
    inputs:
      consensus_client:
        type: choice
        options: [lodestar, teku, prysm, nimbus, lighthouse]
jobs:
  sync:
    uses: dappnode/workflows/.github/workflows/sync-production.yml@main
    with:
      execution_client: geth  # change per repo
      consensus_client: ${{ inputs.consensus_client || '' }}
    secrets: inherit
```

### TropiBot Dispatch Stubs (9-line stubs)

```yaml
# .github/workflows/tropibot-sync-test.yml
name: "TropiBot: Sync Test"
on:
  repository_dispatch:
    types: [tropibot-sync-test]
jobs:
  test:
    uses: dappnode/workflows/.github/workflows/staking-sync-test.yml@main
    with:
      package_variant: hoodi
      execution_client: ${{ github.event.client_payload.execution_client }}
      consensus_client: ${{ github.event.client_payload.consensus_client }}
      pr_number: ${{ github.event.client_payload.pr_number }}
      head_ref: ${{ github.event.client_payload.head_ref }}
    secrets: inherit
```

```yaml
# .github/workflows/tropibot-attestation-test.yml
name: "TropiBot: Proof of Attestation"
on:
  repository_dispatch:
    types: [tropibot-attestation-test]
jobs:
  test:
    uses: dappnode/workflows/.github/workflows/staking-full-test.yml@main
    with:
      package_variant: hoodi
      execution_client: ${{ github.event.client_payload.execution_client }}
      consensus_client: ${{ github.event.client_payload.consensus_client }}
      pr_number: ${{ github.event.client_payload.pr_number }}
      head_ref: ${{ github.event.client_payload.head_ref }}
    secrets: inherit
```

### Docker Build & Push (10-line stub)

```yaml
# .github/workflows/docker.yml
name: Docker
on:
  push:
    tags: ['v*']
jobs:
  docker:
    uses: dappnode/workflows/.github/workflows/docker-build-push.yml@main
    with:
      image_name: dappnode/my-tool
      platforms: linux/amd64,linux/arm64
    secrets: inherit
```

## Required Org-Level Configuration

### Secrets (set at org level)
- `TROPI_APP_PRIVATE_KEY` — GitHub App private key for automated PRs/tokens
- `PINATA_API_KEY` / `PINATA_SECRET_API_KEY` — IPFS pinning
- `DISCORD_STAKERS_TESTS_WEBHOOK` — Discord failure notifications
- `NPM_TOKEN` — NPM publishing (SDK/DAPPMANAGER only)

### Variables (set at org level)
- `TROPI_APP_ID` — GitHub App ID (non-sensitive)

### Self-Hosted Runners
- `staking-test-hoodi` — DAppNode runner for staking tests
- `ipfs-dev-gateway` — Runner with IPFS access for publishing

## Migration Roadmap

### ✅ Phase 1: Create this repo (done)
### ✅ Phase 2: Update tropibot to reference this repo

### Phase 3: Execution clients (geth, besu, nethermind, erigon, reth)
Each repo gets 4 minimal workflow stubs:
- `auto_check.yml` → calls `bump-upstream`
- `release.yml` → calls `staking-release`
- `sync.yml` → calls `sync-production`
- `tropibot-sync-test.yml` → calls `staking-sync-test`
- `tropibot-attestation-test.yml` → calls `staking-full-test`

### Phase 4: Consensus clients (lighthouse, lodestar, prysm, teku, nimbus)
Each repo gets 3 minimal workflow stubs:
- `auto_check.yml` → calls `bump-upstream`
- `main.yml` → calls `build-test-release`
- `tropibot-sync-test.yml` → calls `staking-sync-test`
- `tropibot-attestation-test.yml` → calls `staking-full-test`

### Phase 5: Remaining packages (anchor, pi-hole, tailscale, obol, etc.)
- `auto_check.yml` → calls `bump-upstream`
- `main.yml` → calls `build-test-release`

### Phase 6: Core packages (DNP_CORE, DNP_DAPPMANAGER)
- More custom — evaluate individually
- DNP_DAPPMANAGER has unit tests, monorepo, NPM publish (may need dedicated workflow)

## Design Decisions

- **Public repo** — no GitHub Enterprise requirement, community-visible
- **`secrets: inherit`** — minimal stubs, org-level secrets
- **`@main` ref** — internal trust within org (no version pinning needed)
- **All DAppNodeSDK commands centralized** — SDK updates happen here, not in 87 repos
- **tropibot test-runner image** — `ghcr.io/dappnode/tropibot/test-runner:latest`
