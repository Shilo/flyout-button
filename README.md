# Flyout Button
Flyout Button is a reusable Godot 4 addon that provides a compact button control with a directional flyout menu. It is useful for editor toolbars and runtime UI where one visible button should expose several selectable actions. Items support custom textures, editor theme icons, tooltips, shortcuts, and Godot resources through `FlyoutButtonItem`.

## 🔧 Maintainer: publish the addon branch

The public subtree branch is always named `addon`. After changing files under `addons/flyout_button` on `main`, the GitHub workflow publishes that directory as the root of `addon` automatically.

To create or repair the branch manually from the Flyout Button repo root, publish the addon directory tree with `git commit-tree`:

```powershell
$addonDir = "addons/flyout_button"
git fetch origin "+refs/heads/addon:refs/remotes/origin/addon" 2>$null
$addonTree = git rev-parse "main:$addonDir"
$currentTree = git rev-parse "origin/addon^{tree}" 2>$null

if ($LASTEXITCODE -eq 0 -and $addonTree -eq $currentTree) {
  "addon branch already up to date"
} else {
  $parent = git rev-parse --verify origin/addon 2>$null
  if ($LASTEXITCODE -eq 0) {
    $newCommit = git commit-tree $addonTree -p $parent -m "chore: sync addon branch from $(git rev-parse --short main)"
  } else {
    $newCommit = git commit-tree $addonTree -m "chore: sync addon branch from $(git rev-parse --short main)"
  }
  git push origin "${newCommit}:refs/heads/addon"
}
```

The `addon` branch contains only the files that belong inside a dependent project's `addons/flyout_button` directory. It is a generated one-way publish branch, so make source changes under `addons/flyout_button` on `main` instead of editing `addon` directly.

The `.github/workflows/sync-addon-branch.yml` workflow uses the same `git commit-tree` publish flow whenever `main` receives changes under `addons/flyout_button`.

## Using Flyout Button as a subtree dependency

Dependent Godot projects should keep these shared files at:

```text
addons/flyout_button
```

Git subtree is useful here because the dependent repo gets real committed files instead of a submodule pointer. That means the project still opens normally in Godot and does not require an extra clone step.

This repository is a full Godot demo project. The reusable addon files live in `addons/flyout_button`, so subtree consumers should use the generated `addon` branch.

### Initialize the subtree

From the root of the repo that depends on Flyout Button:

```powershell
git subtree add --prefix=addons/flyout_button https://github.com/Shilo/flyout-button.git addon --squash
```

This adds the shared Flyout Button files into `addons/flyout_button` and records enough subtree history for future updates.

### Update to the latest Flyout Button commit

From the dependent repo root:

```powershell
git subtree pull --prefix=addons/flyout_button https://github.com/Shilo/flyout-button.git addon --squash
```

If Git reports conflicts, resolve them like a normal merge, then commit the result.

## VS Code task for updating without typing the CLI command

In any dependent repo, create `.vscode/tasks.json` with this task:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Update Flyout Button subtree",
      "type": "shell",
      "command": "git",
      "args": [
        "subtree",
        "pull",
        "--prefix=addons/flyout_button",
        "https://github.com/Shilo/flyout-button.git",
        "addon",
        "--squash"
      ],
      "problemMatcher": []
    }
  ]
}
```

Then run it from VS Code:

1. Open the Command Palette with `Ctrl+Shift+P`.
2. Choose `Tasks: Run Task`.
3. Choose `Update Flyout Button subtree`.

Optional keyboard shortcut in VS Code `keybindings.json`:

```json
{
  "key": "ctrl+alt+u",
  "command": "workbench.action.tasks.runTask",
  "args": "Update Flyout Button subtree"
}
```

The task still runs Git under the hood, but you can trigger it from VS Code without retyping the subtree command.

## 📦 Dependencies

None.

## 🔁 Used By

- [Tyle Map Editor](https://github.com/Shilo/tyle-map-editor) - uses Flyout Button as a child subtree at `addons/tyle_map_editor/flyout_button`.
- [PentaTile](https://github.com/Shilo/PentaTile) - receives Flyout Button recursively through Tyle Map Editor at `addons/penta_tile/tyle_map_editor/flyout_button`.
- [VirtuMap](https://github.com/Shilo/VirtuMap) - receives Flyout Button recursively through PentaTile and Tyle Map Editor at `addons/virtumap/penta_tile/tyle_map_editor/flyout_button`.
