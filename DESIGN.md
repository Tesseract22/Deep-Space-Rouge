# Game Design Document

Deep Space Rouge is a rouge-like fighter shooting game inspired by asteriod, and backpack heros.oi089u

## Gameplay
You control a figher jet, and collect gears by defeating enemies. Each gear has a shape. A gear needs to be equipped into a limited-size backpack for it to take effect.
Gears affect each other in the backpack.

### Buff System
We want to have a very powerful buff systems, that not only modifies the stat (shooting rates, fire power, movement speed, etc.),
but it should also be able to transform the weapon/component it is affecting. 

For example:
* Applying effects on hit.
* Turns the weapon into a triple shot
* Lanuch a turret, which will use the original weapon.

#### What is a buff?
We need a good mental model and abstraction of buff. I propose the following: 

* A buff is something that modify a component.
* Reversible

#### Order matter!
Depending on the order we apply the aforementioned buff #2 and #3, the result can be drastically different.
