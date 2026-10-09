class_name YardRoutineStyle
extends AssetModule
## v6b daily yard routine: a short checklist each day (let the sheep out in the
## morning, stack the boxes, water the garden, pen the flock in the evening).
## Shown under the clock; finishing it gives a small reward + a healthy-life
## bonus. Consumer: YardRoutine.

@export var name_fa: String = ""
## {id, en, fa, from, to}
@export var tasks: Array = []
@export var reward: int = 30
@export var stamina_bonus: float = 10.0
