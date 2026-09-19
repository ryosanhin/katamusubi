# katamusubi

**A dependency injection container for Godot, written in GDScript.**

katamusubi lets you register services in explicit scopes and inject them into nodes through typed method parameters. Parent-child scope relationships are configured using scope IDs, independently of the node hierarchy in the SceneTree.

This project is heavily inspired by [VContainer](https://github.com/hadashiA/VContainer), a DI library for C#. Its API and concepts intentionally resemble those of VContainer.

Suggestions and corrections are welcome!

## Environment
The project is developed using Godot 4.7.x

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

Select `ExampleContainerScope` in the Inspector and add `ExampleUser` to its **Inject Targets** array.

During scope initialization, katamusubi resolves the arguments and calls `inject_dependency()` on each node in **Inject Targets**.

Nodes are not automatically discovered or injected. You must add each target node to the Inject Targets array.

For this example, annotate each parameter with a service type declared using `class_name`. Scripts without `class_name` require explicit type overrides through `get_inject_type_overrides()`.

## Injection timing

A scope normally initializes in its `_ready()` method.

Parent scopes are initialized first, followed by service registration and dependency injection in the current scope.

A parent scope can also be initialized by a child scope before the parent's own `_ready()` method runs.

Injection is not guaranteed to occur before or after the target node's `_ready()` method.

Do not assume that injected dependencies are available in `_ready()`, or that service and target nodes have completed their own `_ready()` methods when injection occurs.

Use `inject_dependency()` to receive and store references. Any initialization that also depends on node readiness should explicitly coordinate both conditions.

If a script extending `ContainerScope` overrides `_ready()`, call `super._ready()` to preserve scope initialization.

## Register a service under a base type

Use `as_type()` to register a service under a base type.

`as_type()` replaces the registration's exposed type. It does not cast or convert the actual instance.

For this example, first define `AbstractExampleManager`:

```gdscript
# abstract_example_manager.gd
@abstract
extends Node
class_name AbstractExampleManager


@abstract
func use_service() -> void
```

Then change `ExampleManager` to extend it:

```gdscript
# example_manager.gd
extends AbstractExampleManager
class_name ExampleManager


func use_service() -> void:
	print("Service used.")
```

Replace the registration in `_register_instance()` with:

```gdscript
container.register(
		ServiceRegistration.create_instance_registration(
				_example_service,
				ExampleManager,
		).as_type(AbstractExampleManager)
)
```

Update the receiving script to request `AbstractExampleManager`:

```gdscript
extends Node

var _example_manager: AbstractExampleManager


func inject_dependency(example_manager: AbstractExampleManager) -> void:
	_example_manager = example_manager
```

The implementation type must be the same as, or derive from, the type passed to `as_type()`.

**This registration alone does not make the service resolvable as both `ExampleManager` and `AbstractExampleManager`.**

Register the service under both types if you want to resolve it using either type.

## Register with a key

Use `with_key()` to distinguish multiple registrations of the same service type.

To request a keyed registration, **use its key as the parameter name in `inject_dependency()`**.

If no matching keyed registration exists, katamusubi falls back to an unkeyed registration of the same type.

The following scope registers a default service and a service with the key `specific`:

```gdscript
extends ContainerScope

@export var _example_service: ExampleManager
@export var _specific_example_service: ExampleManager


func _register_instance(container: InjectionContainer) -> void:
	container.register(
			ServiceRegistration.create_instance_registration(
					_example_service,
					ExampleManager,
			)
	)

	container.register(
			ServiceRegistration.create_instance_registration(
					_specific_example_service,
					ExampleManager,
			).with_key(&"specific")
	)
```

The receiving script can request both registrations:

```gdscript
extends Node

var _default_service: ExampleManager
var _specific_service: ExampleManager


func inject_dependency(
	example_manager: ExampleManager,
	specific: ExampleManager,
) -> void:
	_default_service = example_manager
	_specific_service = specific
```

In this example, `example_manager` receives the unkeyed service because there is no registration with that key.

`specific` receives the service registered with `&"specific"`.

Registrations must have unique combinations of service type and key within a scope. Registering the same combination twice is an error.

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
2. Enable **Selectable As Parent** on `ParentContainerScope`.
3. Open `ExampleScene` for editing. Attach the following script to `ChildContainerScope`:

```gdscript
# child_container_scope.gd
extends ContainerScope


func _register_instance(_container: InjectionContainer) -> void:
	pass
```

4. In the child scope's Inspector, select `ParentContainerScope` from **Current parent scope**.
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
