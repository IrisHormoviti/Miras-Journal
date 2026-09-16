# GDScript Refactoring — Godot 4 Plugin

A **scope-aware refactoring** plugin for the Godot 4 script editor, powered by Godot's built-in **GDScript Language Server (LSP)**, the same engine that drives autocompletion and go-to-definition. It adds two tools to the editor:

- **Rename** a symbol (variable, function, class…) across your whole project.
- **Find all references** to a symbol, listed in a dockable panel you can click to jump straight to the code.

Unlike naive find-and-replace, both tools understand GDScript semantics: renaming or searching a member variable will not touch an unrelated local variable that happens to share the same name, and vice versa.

---

## Features

### Rename

- **Shift+F2** (or right-click → **Rename...**) directly in the script editor, on any user-defined symbol (variable, function, parameter, class, enum member…). The shortcut is customizable (see *Customizing the shortcuts* below).
- **Scope-aware**: powered by `textDocument/rename` from Godot's own language server, shadowed or unrelated symbols are left untouched
- **Project-wide**: all `.gd` files are analyzed and updated in one action
- **Preview before applying**: every affected file, line number, and line content is listed (with the symbol highlighted) before anything is written
- **Multi-file undo/redo**: a single Ctrl+Z reverts the rename across *all* modified files; Ctrl+Shift+Z (or Ctrl+Y) re-applies it. Your own local edits are still undone first, like in any IDE
- **Unsaved-changes guard**: if any open script has unsaved edits when you open the dialog, a warning lists the affected files and a **Save modified files** button lets you save them in one click before renaming
- **Silent editor refresh**: open script tabs reload automatically, no "files are newer on disk" popup, caret and scroll position preserved

### Find all references

- **Alt+Shift+F2** (or right-click → **Find all references**) on any user-defined symbol
- Opens a dockable **References** panel at the bottom of the editor (next to Output / Debugger)
- Every usage is listed, grouped by file, with **syntax-colored** source lines and the occurrence highlighted, just like the rename preview
- **Click any line to jump** straight to that file at the exact position
- **Copy / Select All** from the panel's right-click context menu (like the Output panel)
- A progress spinner is shown in the header while the search runs
- The shortcut is customizable (see *Customizing the shortcuts* below)

### Scope-aware analysis (both tools)

Godot's language server matches variables by name only, so a member `var x` and
a function-local `var x` get merged, and some usages are missed. Both tools
correct this by analyzing GDScript scoping directly:

- **Member vs local variables** are treated as distinct symbols, honoring
  shadowing: a member's usages inside a function that redeclares it locally are
  excluded, and a local's usages never leak outside its function.
- **Virtual methods** (`_init`, `_ready`, `_process`, …) are restricted to the
  starting class and its subclasses, hiding unrelated matches in other classes.
  For `_init`, the corresponding `.new()` constructor calls are included.
- **Property accesses** such as `velocity.y` return only the self-accesses in
  the class and its related classes (ancestors + descendants), filtering out
  unrelated `.y` members on other objects and reporting how many external
  `obj.velocity.y` accesses were found but not followed (their object's type
  can't be resolved from text alone).

### Both tools

- **Smart context menu**: the *Rename...* and *Find all references* entries only appear when the cursor is on a usable symbol, never on keywords, built-in types (`Vector2`, `String`…), native engine classes (`Node`, `Sprite2D`…), numbers, strings, or comments
- **Native members protected from rename**: inherited node properties
  (`velocity`, `position`, `rotation`, …) are never renameable; value components
  (`x`, `y`, `length`, …) are protected when used as a property access, while a
  standalone user variable of the same name stays renameable. *Find all
  references* remains available on native members, searching the self-accesses
  of that property.
- **Cross-platform paths**: file URIs from the language server are resolved correctly on Windows, Linux, and macOS, including paths containing accented or other non-ASCII characters

---

## Installation

1. Copy the `addons/gdscript_refactoring/` folder into your project's `addons/` directory.
2. Open **Project → Project Settings → Plugins**.
3. Enable **GDScript Refactoring**.

> **Requirement:** the GDScript language server must be running (it is enabled by default in the Godot editor, on port 6005, see *Editor Settings → Network → Language Server*).

---

## Usage

### Renaming a symbol

1. In the script editor, place the caret on the symbol you want to rename.
2. Press **Shift+F2** (customizable, see below), or right-click → **Rename...**.
   The shortcut and the menu entry only activate on renameable symbols.
3. Type the new name.
4. Click **Preview**, all occurrences across the project are listed with file, line number, and highlighted line content.
5. Click **Rename** to apply.

To revert: press **Ctrl+Z** in the script editor. All modified files are restored in one step. **Ctrl+Shift+Z** / **Ctrl+Y** re-applies the rename.

### Finding all references

1. Place the caret on the symbol you want to inspect.
2. Press **Alt+Shift+F2** (customizable, see below), or right-click → **Find all references**.
3. The **References** panel opens at the bottom, listing every usage grouped by file, with syntax-colored lines.
4. **Click any line** to open that file in the editor at the exact position.

### Customizing the shortcuts

On **Godot 4.6 and later**, both shortcuts appear in the native **Shortcuts** tab: open **Editor → Editor Settings → Shortcuts**, find the **Gdscript Refactoring** category, and rebind **Rename Symbol** (default *Shift+F2*) or **Find all references** (default *Alt+Shift+F2*).

On **older versions**, the rename shortcut falls back to a setting under **Editor → Editor Settings → Gdscript Refactoring → Rename Shortcut**.

> **Note:** if you clear a shortcut completely, it is restored to its default the next time the plugin loads (an empty shortcut can never fire). To disable one, bind it to a different key instead.

> **Note:** in the settings list (fallback case), the *Gdscript Refactoring* category only appears when **Advanced Settings** is enabled (toggle at the top-right of the Editor Settings window). This does not apply to the Shortcuts tab.

---

## How it works

| Step | Mechanism |
|------|-----------|
| Symbol detection | Word under caret + keyword / native-class / string / comment filtering |
| Rename search | `textDocument/rename` request to Godot's LSP (port 6005) |
| Reference search | `textDocument/references` request to the same LSP, returning every usage `Location` |
| Scope correction | Member/local resolution, virtual-method hierarchy filtering, and property-access matching are computed by the plugin from the source text, compensating the LSP's name-only matching |
| File sync to LSP | `didOpen` with monotonically increasing versions, drained socket buffers to avoid TCP deadlock |
| Applying edits | The LSP `WorkspaceEdit` (precise line/character ranges) is applied bottom-to-top to each file |
| Reference display | Results grouped by file in a bottom-panel `RichTextLabel`; each line is syntax-colored via a detached copy of the editor's highlighter and made clickable with BBCode `[url]` tags |
| Editor refresh | Temporary `auto_reload_scripts_on_external_change` + filesystem notification + simulated window-focus check (the same mechanism Godot uses to detect external file changes) |
| Undo / redo | Plugin-internal multi-file stack; Ctrl+Z is intercepted in the CodeEdit only when its local history is empty |

---

## File structure

```
addons/gdscript_refactoring/
├── plugin.cfg               # Plugin manifest
├── qb_gdscript_rename.gd    # EditorPlugin, context menu, undo stack, shortcuts
├── qb_rename_dialog.gd      # Rename dialog, preview, apply, editor refresh
├── qb_references_panel.gd   # "Find all references" dockable bottom panel
├── qb_scope_filter.gd       # Shared scope-aware occurrence analysis
├── qb_lsp_client.gd         # Minimal LSP client (JSON-RPC 2.0 over TCP)
├── qb_file_scanner.gd       # Recursive .gd file collector
└── qb_symbol_replacer.gd    # Legacy regex engine (kept for reference)
```

---

## Limitations

- GDScript only (not C#).
- Both tools rely on Godot's language server: symbols it cannot resolve (e.g. purely dynamic access via strings, `get()`/`set()` calls) will not be found.
- References inside `.tscn` scene files (connected signals, exported node paths) are neither updated by rename nor listed by *Find all references*, use Godot's built-in tools for those.
- Property-access searches (e.g. `velocity.y`) match self-accesses within the class hierarchy; accesses through a typed variable on another object (`some_body.velocity.y`) are counted but not listed, since the object's type can't be resolved from text alone.

---

## Compatibility

- **Godot 4.x** (developed and tested on 4.6 and 4.7)
