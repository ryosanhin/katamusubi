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
2. Set the parent's `scope_id` to `application` and save the parent scene.
3. Open `ExampleScene` for editing. Attach the following script to `ChildContainerScope`:

```gdscript
# child_container_scope.gd
extends ContainerScope


func _register_instance(_container: InjectionContainer) -> void:
	pass
```

4. Set the child's `parent_scope_id` to `application`.
5. Add `ExampleUser` to the child scope's **Inject Targets** array. Use the receiving script from the basic example, which requests `ExampleManager`.
6. Save the child scene and run `RootScene` with both scenes present.

`_register_instance()` must be implemented even when the child has no services to register.

A child scope can resolve services registered in its parent scope.

### Scope IDs

- Set `scope_id` if other scopes need to use this scope as a parent.
- Set `parent_scope_id` to the parent's `scope_id`. Leave it empty if no parent is needed.
- A scope can use a parent even when its own `scope_id` is empty.
- If you change a parent's ID, update its children's `parent_scope_id` too.

### Input suggestions

As you type, the Inspector shows matching IDs and their scene paths.
You can also enter an ID that is not in the suggestions.

Suggestions use saved `.tscn` scenes. Save the scene to update its suggestions.
To rebuild all suggestions, select **Katamusubi: 公開スコープ索引を再構築** from the editor's Tools menu.

Suggestions only help with input. At runtime, katamusubi finds the parent in the SceneTree using `parent_scope_id`.

### Runtime requirements

When a child scope initializes:

- Exactly one parent with the matching ID must already be in the SceneTree.
- All parent and ancestor scopes must initialize successfully.
- Parent relationships must not form a cycle.

IDs must match exactly, including letter case.
Initialization fails if these requirements are not met.
A failed scope does not automatically retry when a parent is added later.

## Injection timing

Scopes normally initialize in `_ready()`. Parent scopes are initialized first, followed by service registration and dependency injection in the current scope.

A child scope may initialize its parent before the parent's own `_ready()` method runs.

Injection is not guaranteed to occur before or after the service or target node's `_ready()`. Do not assume that injected dependencies are available in `_ready()`.

If you override `ContainerScope._ready()`, call `super._ready()` to preserve scope initialization.
