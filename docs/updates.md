# Updates

Rerun setup for one VM:

```bash
dvm setup app
```

Rerun setup for every VM:

```bash
dvm setup-all
```

Upgrade Fedora packages, then rerun setup:

```bash
dvm upgrade app
dvm upgrade-all
```

Recipes are rerun after upgrades. Existing downloaded files are only replaced if the
recipe does that explicitly.
