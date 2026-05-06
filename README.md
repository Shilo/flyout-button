# Flyout Button
Flyout Button is a reusable Godot 4 addon that provides a compact button control with a directional flyout menu. It is useful for editor toolbars and runtime UI where one visible button should expose several selectable actions. Items support custom textures, editor theme icons, tooltips, shortcuts, and Godot resources through `FlyoutButtonItem`.

## Maintainer: create the addon split branch

The public subtree branch is always named `addon`. After changing files under `addons/flyout_button` on `main`, refresh and push the split branch from the Flyout Button repo root:

```powershell
git subtree split --prefix=addons/flyout_button main --branch addon
git push origin addon
```

The `addon` branch contains only the files that belong inside a dependent project's `addons/flyout_button` directory.

## Using Flyout Button as a subtree dependency

Dependent Godot projects should keep these shared files at:

```text
addons/flyout_button
```

Git subtree is useful here because the dependent repo gets real committed files instead of a submodule pointer. That means the project still opens normally in Godot and does not require an extra clone step.

This repository is a full Godot demo project. The reusable addon files live in `addons/flyout_button`, so subtree consumers should use the generated `addon` split branch.

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
