# scripts/

## docker-publish.yml

GitHub Actions workflow template for building and pushing a Hardys connector image to `ghcr.io`.

**Copy this file to your connector repo (one-time setup):**
```bash
mkdir -p .github/workflows
cp scripts/docker-publish.yml .github/workflows/docker-publish.yml
git add .github/workflows/docker-publish.yml
git commit -m "ci: add Docker publish workflow"
git push
```

**No secrets required** — uses the built-in `GITHUB_TOKEN`.

### Triggers

| Event | Image tag produced |
|---|---|
| Push to `main` | `:main-{sha}` |
| Tag `v1.2.3` | `:1.2.3`, `:1.2`, `:1`, `:latest` |

### What it does

1. Validates `connector-manifest.json` at repo root (fails if missing or invalid JSON)
2. Embeds `connector-manifest.json` path as OCI annotation `org.hardys.connector.manifest-path`
3. Builds and pushes the image to `ghcr.io/{org}/{repo}`
4. Verifies the OCI annotation is present on the pushed image

### Requirements

- `connector-manifest.json` must exist at the repo root
- Repository must have `packages: write` permission (already configured in the workflow)
