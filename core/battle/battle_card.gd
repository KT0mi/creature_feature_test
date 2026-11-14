@tool
##Generic class of cards
##Parent class of all cards
class_name BattleCard
extends Resource

@export var id: StringName
@export var name: String

#Number of turns this card is inactive for, after use
@export var cooldown: int
