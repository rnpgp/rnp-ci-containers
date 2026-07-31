# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Docker images that power CI for [rnpgp/rnp](https://github.com/rnpgp/rnp). Images are published to `ghcr.io/rnpgp/ci-rnp-<name>` and referenced from rnp workflows via `container:`.

Primary consumer concerns: system-packaged Botan/OpenSSL/GnuPG where possible, plus optional side-by-side custom builds when the distro is too old or when rnp needs a specific Botan/GnuPG version.

## Layout

```
*.Dockerfile          # one file per image, at repo root
tools/
  tools.sh            # shared install/select helpers, copied to /opt/tools in every image
  botan-modules       # minimized Botan 2.x module list
  botan3-modules      # Botan 3.0–3.1
  botan3.2-modules    # Botan 3.2–3.4 (adds PQ + hkdf/kmac)
  botan3.5-modules    # Botan 3.5–3.6 (curve25519 → x25519 rename)
  botan3.7-modules    # Botan 3.7+ (adds pcurves_*)
.github/workflows/build-containers.yml
README.adoc           # image inventory + version matrix (keep in sync when adding images)
```

There is no application source, package manager, or test suite beyond `docker build`.

## Naming

| Artifact | Pattern | Example |
|---|---|---|
| Dockerfile | `<os>-<version>[-<arch>].Dockerfile` | `fedora-41-amd64.Dockerfile` |
| Image tag | `ci-rnp-<os>-<version>[-<arch>]` | `ghcr.io/rnpgp/ci-rnp-fedora-41-amd64` |
| Matrix entry | basename without `.Dockerfile` | `fedora-41-amd64` |

Inconsistency today: most images use `-<arch>` (`-amd64`/`-i386`); `opensuse-leap`, `opensuse-tumbleweed`, and `redhat-*-ubi` do not. Prefer the arch-suffixed form for new images. The rnp workflow `container:` field must match the basename exactly.

## Common commands

```bash
# Build one image locally (context is always repo root — tools/ must be present)
docker build -f fedora-41-amd64.Dockerfile -t ci-rnp-fedora-41-amd64 .

# Inspect system Botan in a built image
docker run --rm ci-rnp-fedora-41-amd64 pkg-config --modversion botan-2
docker run --rm ci-rnp-debian-13-amd64 pkg-config --modversion botan-3

# Exercise the GHA selector helpers (needs GITHUB_ENV/GITHUB_PATH files)
docker run --rm -e GITHUB_ENV=/tmp/ge -e GITHUB_PATH=/tmp/gp ci-rnp-fedora-41-amd64 \
  bash -c 'touch /tmp/ge /tmp/gp && /opt/tools/tools.sh select_botan_version_for_gha 3.7.1 && cat /tmp/ge /tmp/gp'

# tools.sh is also runnable on the host for non-install helpers, but build_* targets need root + network
./tools/tools.sh ensure_symlink_to_target /usr/bin/python3 /tmp/python-test
```

There is no lint/test target. Validation is: image builds, expected packages are present, and `select_*_for_gha` / `pkg-config` behave as documented.

## CI / publish flow

Workflow: `.github/workflows/build-containers.yml`

- **Triggers:** every PR and push; `workflow_dispatch`; version tags `v*`
- **Matrix:** one job per container name listed in `strategy.matrix.container`
- **Build always; push only on tags** (`push: ${{ contains(github.ref, 'refs/tags/v') }}`)
- **Registry:** `ghcr.io/rnpgp/ci-rnp-${{ matrix.container }}` (login as user `rnpgp` with `GITHUB_TOKEN`)
- **Cleanup on tag:** keeps 1 untagged package version per image

Adding an image requires three edits:
1. New `*.Dockerfile` at repo root
2. New entry in `matrix.container`
3. Row(s) in `README.adoc` version tables

Releasing is tagging `v*` on main (maintainers only) — that is what actually publishes images.

## Dockerfile shape

Typical pattern (see `fedora-41-amd64.Dockerfile`, `debian-13-amd64.Dockerfile`):

1. `FROM` distro base (`fedora:N`, `amd64/debian:N`, `i386/debian:N`, `opensuse/*`, `redhat/ubi*`, `quay.io/centos/centos:streamN`)
2. Locale + arch env: `LANG/LC_*`, `ARCH` (`x64`/`ia32`), `CPU` (`x86_64`/`i386`), `OS=linux`, often `LD_LIBRARY_PATH=/usr/local/lib`
3. `COPY tools /opt/tools`
4. Distro package install of build deps + system crypto (`botan2`/`libbotan-*-dev`/`libbotan-devel`, `json-c`, openssl, gpg, cmake toolchain, clang, asciidoctor, …)
5. Optional `/opt/tools/tools.sh …` steps for custom Botan/GnuPG/json-c/automake/libiconv/cmake
6. No `USER` / no `rnpuser` today — images run as root; rnp CI creates its own user if needed

**RHEL UBI images are OpenSSL-only** (no Botan). They pull Ribose EPEL-style packages (`json-c13-devel`) and are for the openssl crypto backend path in rnp.

**i386 Debian images** set `ARCH=ia32` / `CPU=i386` and use `i386/debian:N` so `tools.sh` cmake/botan/gpg configure paths pick the right arch.

## `tools/tools.sh` contract

Invoked as `/opt/tools/tools.sh <function> [args…]` (last line is `"$@"`). Key functions used by Dockerfiles and by rnp GHA:

| Function | Effect |
|---|---|
| `build_and_install_botan [ver\|head\|system]` | Builds Botan from git. `system`/omitted → `DEFAULT_BOTAN_VERSION` (2.18.2) into `/usr/local`. Named tag/branch → `/opt/botan/<ver>`. `head` → master into `/opt/botan/head`. Module list chosen by version thresholds against `tools/botan*-modules`. |
| `build_and_install_gpg [head\|stable\|lts]` | Builds full GnuPG stack via [rnpgp/gpg-build-scripts](https://github.com/rnpgp/gpg-build-scripts) into `/opt/gpg/<selector>`. Versions pinned in the function body (stable=GnuPG 2.4.5, lts=2.2.43). Always compiles with gcc. |
| `build_and_install_jsonc` / `_automake` / `_libiconv` / `_python` | Source builds into `/usr` or `/usr/local` for distros missing adequate packages. |
| `install_cmake` | xpack prebuilt cmake for `${ARCH}`. |
| `select_botan_version_for_gha [ver\|system]` | Appends `PATH`/`BOTAN_ROOT_DIR`/`LD_LIBRARY_PATH`/`PKG_CONFIG_PATH`/`CPATH` for `/opt/botan/<ver>`. No-op for `system`. Needs `$GITHUB_ENV` + `$GITHUB_PATH`. |
| `select_gpg_version_for_gha [ver\|system]` | Prepends `/opt/gpg/<ver>/bin` to `GITHUB_PATH`. |
| `select_crypto_backend_for_gha [botan\|openssl]` | Sets `CRYPTO_BACKEND` in `GITHUB_ENV`. |
| `ensure_symlink_to_target <from> <to>` | `ln -s` if target missing (python3→python). |

Botan module-list thresholds in `build_and_install_botan` (keep in mind when adding new Botan versions):

- `< 3.0.0` → `botan-modules` (+ `--without-openssl`)
- `< 3.2.0` → `botan3-modules`
- `< 3.5.0` → `botan3.2-modules`
- `< 3.7.0` → `botan3.5-modules`
- `≥ 3.7.0` → `botan3.7-modules`

If upstream Botan renames/splits modules again, add a new `tools/botanX.Y-modules` file and a new threshold branch — do not silently reuse an older list.

## Current image set (high level)

| Family | Crypto | Notes |
|---|---|---|
| `debian-10/11-*-*` | Botan 2.18.2 @ `/usr/local` | Legacy; local Botan build |
| `debian-12-*` | system Botan 2.19.3 | Also builds json-c from source |
| `debian-13-*` | system Botan 2.19.5 **and** 3.7.1 | First Debian with dual botan2+botan3 |
| `fedora-39/40/41-amd64` | system botan2 + several Botan 3.x under `/opt/botan/*` | Also prebuilds gpg lts+stable; kept for regression |
| `fedora-43-amd64` | system botan2 (latest) | No from-source Botan |
| `fedora-44-amd64` | system botan2 + botan3 (latest) | No from-source Botan |
| `fedora-rawhide-amd64` | system botan3 (latest) | Rolling; Botan3-only |
| `debian-sid-amd64` | system botan3 (latest) | Rolling |
| `alpine-edge-amd64` | system botan3 (latest) | apk-based; first Alpine image |
| `centos-9-amd64` | system botan2 + gpg lts+stable @ `/opt/gpg/*` | Needs CRB + EPEL; builds automake/libiconv |
| `opensuse-leap` | system Botan 2.19.3 | zypper; no custom botan builds |
| `opensuse-tumbleweed` / `-amd64` | system botan3 (latest) | `-amd64` is the preferred name; unsuffixed kept for compatibility |
| `redhat-8/9-ubi` | OpenSSL only | Ribose yum repo for json-c13 |

`debian-10-i386.Dockerfile` exists on disk but is **not** in the CI matrix (EOL). EOL Fedora images stay in the matrix for historical/regression use.

Authoritative version numbers live in `README.adoc` — update that table whenever Dockerfiles change preinstalled versions.

## Related work / open direction

Issue [#20](https://github.com/rnpgp/rnp-ci-containers/issues/20) (and rnpgp/rnp#2420): expand matrix toward distro-shipped Botan 3.x and drop from-source Botan where possible.

Requested additions: `fedora-43-amd64`, `fedora-44-amd64`, `fedora-rawhide-amd64`, `opensuse-tumbleweed-amd64` (rename), `debian-sid-amd64`, `alpine-edge-amd64`.

EOL candidates once rnp stops referencing them: `fedora-39/40/41`, `debian-10-i386`.

rnpgp/rnp#2419 will uncomment workflow legs once the new images exist on ghcr.io.

## Conventions when editing

- Prefer system packages for Botan/GnuPG/json-c; only call `build_and_install_*` when the distro cannot supply a usable version or when multi-version coverage is required.
- Keep `COPY tools /opt/tools` before any `tools.sh` invocation.
- Match package names to the distro family already used by a sibling Dockerfile (dnf/apt/zypper patterns differ; copy the closest existing file).
- Do not push images or tags from a working tree — publish is tag-driven via GHA.
- After adding/removing images, update both the workflow matrix and `README.adoc` in the same change.
