##Generic class of cards
##Parent class of all cards
class_name BattleCard
extends Resource

var id: StringName
var name: String

#Number of turns this card is inactive for, after use
var cooldown: int
