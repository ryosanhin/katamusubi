# katamusubi

**A dependency injection container for Godot, written in GDScript.**

katamusubi lets you register services in explicit scopes and inject them into nodes through typed method parameters. Parent-child scope relationships are configured using scope IDs, independently of the node hierarchy in the SceneTree.

This project is heavily inspired by [VContainer](https://github.com/hadashiA/VContainer), a DI library for C#. Its API and concepts intentionally resemble those of VContainer.

Suggestions and corrections are welcome!

## Environment
The project is developed using Godot 4.7.x.

The implementation uses `@abstract`.

## Installation

1. Copy the `addons/katamusubi` directory into your project's `addons` directory. The resulting path should be `res://addons/katamusubi`.
2. Open **Project > Project Settings > Plugins**.
3. Enable **katamusubi**.

## Basic Usage

This example demonstrates how to register an existing service node and inject it into another node.

Create a scene with the following nodes:

- `RootScene` (`Node`)
  - `ExampleContainerScope` (`Node`, with `example_container_scope.gd`)
  - `ExampleManager` (`Node`, with `example_manager.gd`)
  - `ExampleUser` (`Node`, with `example_user.gd`)

Neither the service nor the injection target needs to be a child of the scope node.

### 1. Create a service

Create `example_manager.gd` and attach it to the `ExampleManager` node.

```gdscript
extends Node
class_name ExampleManager


func use_service() -> void:
	print("Service used.")
```

### 2. Register the service

Create `example_container_scope.gd` with the following code to extend `ContainerScope` and register the service by overriding `_register_instance()`

```gdscript
extends ContainerScope

@export var _example_service: ExampleManager


func _register_instance(container: InjectionContainer) -> void:
	container.register(
			ServiceRegistration.create_instance_registration(
					_example_service,
					ExampleManager,
			)
	)
```

`create_instance_registration()` registers an existing instance. It does not create the node or add it to the SceneTree.

Attach this script to `ExampleContainerScope`.

In the Inspector, assign the `ExampleManager` node to the exported `_example_service` property.

### 3. Receive the service

Create `example_user.gd` and attach it to `ExampleUser`:

```gdscript
extends Node

var _example_manager: ExampleManager


func inject_dependency(example_manager: ExampleManager) -> void:
	_example_manager = example_manager
```

Select `ExampleContainerScope` and add `ExampleUser` to its **Inject Targets** array　in the Inspector.

During scope initialization, katamusubi calls `inject_dependency()` on each node in the **Inject Targets** array.

## Register a service under a base type

```gdscript
container.register(
        ServiceRegistration.create_instance_registration(
                _example_service,
                ExampleManager,
        ).as_type(AbstractExampleManager)
)
```

`as_type()` changes the exposed type without converting the instance.

The implementation type must be the same as, or derive from, the specified base type.

To resolve the service using both types, register it under each type separately.

## Register with a key

Use `with_key()` to distinguish multiple registrations of the same service type.

```gdscript
container.register(
        ServiceRegistration.create_instance_registration(
                _specific_example_service,
                ExampleManager,
        ).with_key(&"specific")
)
```

To request a keyed registration, use its key as the parameter name in `inject_dependency()`.

```gdscript
func inject_dependency(specific: ExampleManager) -> void:
    _example_manager = specific
```

If no matching keyed registration exists, katamusubi falls back to an unkeyed registration of the same type.

### Resolution order

katamusubi first searches the current scope and its ancestor scopes for a registration matching both the requested type and key.

If no matching keyed registration is found, it searches the same scopes for an unkeyed registration of the requested type.

For a child scope with one parent, the order is:

| Priority | Registration |
| --- | --- |
| 1 | Matching type and key in the current scope |
| 2 | Matching type and key in the parent scope |
| 3 | Matching type without a key in the current scope |
| 4 | Matching type without a key in the parent scope |

A keyed registration in a parent scope takes precedence over an unkeyed registration in the current scope.

If no matching keyed or unkeyed registration exists, dependency resolution fails.

## Use parent and child scopes

Parent-child scope relationships are defined by scope IDs rather than the SceneTree hierarchy.

For example, a persistent scene can provide services to a replaceable scene:

- `RootScene` (`Node`)
  - `ParentContainerScope` (`Node`, with `parent_container_scope.gd`)
  - `ExampleManager` (`Node`, with `example_manager.gd`)
  - `ReplaceableSceneRoot` (`Node`)
    - `ExampleScene` (an instance of a separate scene)
      - `ChildContainerScope` (`Node`, with `child_container_scope.gd`)
      - `ExampleUser` (`Node`, with `example_user.gd`)

To configure this example:

1. Use `example_container_scope.gd` from [Basic Usage](#basic-usage) as `parent_container_scope.gd`. Attach it to `ParentContainerScope` and assign the `ExampleManager` node to `_example_service`.
2. Set **Public Scope Name** on `ParentContainerScope` to a stable name such as `application`. A blank name means that the scope is private and is not offered as a parent candidate.
3. Open `ExampleScene` for editing. Attach the following script to `ChildContainerScope`:

```gdscript
# child_container_scope.gd
extends ContainerScope


func _register_instance(_container: InjectionContainer) -> void:
	pass
```

4. In the child scope's Inspector, enter `application` in **Parent Scope Name**. The field searches public names and shows each candidate's scene and `NodePath`, but also accepts names that are not currently in the index.
5. Add `ExampleUser` to the child scope's **Inject Targets** array. Use the receiving script from the basic example, which requests `ExampleManager`.
6. Save the child scene and run `RootScene` with both scenes present.

`_register_instance()` must be implemented even when the child has no services to register.

A child scope can resolve services registered in its parent scope.

### Parent scope runtime requirements

When a child scope initializes:

- Exactly one matching parent scope must already exist in the running SceneTree.
- All required ancestor scopes must be available, and their initialization must succeed.
- The scope relationships must not contain a cycle.

Initialization fails if a required parent is missing. A failed scope does not automatically retry even if a parent is added later.

When instantiating a child scene at runtime, ensure that all required parent scopes are already present in the SceneTree.

Do not instantiate multiple parent scopes with the same scope ID at the same time. A child scope requires exactly one matching parent scope.

The public name and parent name are independent: a scope with a blank public name can
still use a parent, and an intermediate scope can have both values. Suggestions are
editor assistance only. Runtime lookup always uses an exact name match and requires
exactly one live matching scope. Duplicate suggestions are therefore shown as
ambiguous rather than being collapsed to one node.

### Candidate index and diagnostics

**Saved scenes are the source of truth for the candidate index.** Katamusubi builds
the index only from saved `.tscn` files. It caches only non-empty public names, their
scene locations, and their `NodePath`s. Saving a scene replaces that scene's cache
entries. **Katamusubi: 公開スコープ索引を再構築** in the editor's Tools menu finds all
saved `.tscn` scenes again; deleted scenes are also removed from the cache.

This means that a new scene's `scope_id` does not appear in the candidates until the
scene is saved for the first time. Additions, changes, and deletions in an already
saved scene also do not affect the candidates until the scene is saved again.

`parent_scope_id` is a free-form field. You can enter an unsaved ID even if it is not
in the candidates. The candidate list is only input help based on saved scenes. It
does not guarantee that a value is valid or that the parent scope will exist at
runtime. Runtime parent resolution does not use the candidate index; it uses the
actual SceneTree.

Missing, duplicate, and self-referential parent names produce editor diagnostics but
the typed value is retained. A cache read/write failure neither rolls back scene
properties nor prevents the game from running. The runtime remains authoritative for
exactly-one-parent, missing-parent, cycle, registration, and injection validation.

### Migration from the selectable-parent setting

Older releases automatically generated an ID for every scope and used **Selectable
As Parent** to control whether it appeared in the picker. The toggle and automatic ID
generation have been removed. Every existing non-empty ID now acts as a public name,
including IDs that previously belonged to scopes with the toggle disabled. Clear any
unnecessary public names manually after upgrading. Katamusubi deliberately does not
bulk-clear them because doing so could break existing parent references.

Renaming or clearing a public name does not rewrite parent names in other scenes.
Update those references explicitly; until then the editor reports them as missing and
runtime initialization fails when no exactly matching live parent exists.

## Injection timing

Scopes normally initialize in `_ready()`. Parent scopes are initialized first, followed by service registration and dependency injection in the current scope.

A child scope may initialize its parent before the parent's own `_ready()` method runs.

Injection is not guaranteed to occur before or after the service or target node's `_ready()`. Do not assume that injected dependencies are available in `_ready()`.

If you override `ContainerScope._ready()`, call `super._ready()` to preserve scope initialization.
