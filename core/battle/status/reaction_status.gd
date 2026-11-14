@tool
## The status a reaction card puts on its user when played: "this reaction
## is armed". Created at runtime by BattleCard.play(), never saved.
##
## It forwards reacts_to/react to the card, so reaction cards only write
## their logic once (in the card). After firing it removes itself; if it
## hasn't fired by the owner's next turn start, it expires (count 1, ticks
## at OWNER_TURN_START).
##
## Its `reveal` comes from the card: by default the opponent sees that a
## reaction is ready, but not which one.
class_name ReactionStatus
extends StatusEffect

var card: BattleCard


## Builds the armed-reaction status for `p_card`.
static func for_card(p_card: BattleCard) -> ReactionStatus:
	var s := ReactionStatus.new()
	s.card = p_card
	s.id = StringName("reaction_%s" % p_card.id)
	s.name = p_card.name
	s.description = p_card.description
	s.stack_rule = StackRule.REPLACE  # playing it again just re-arms it
	s.tick_on = Tick.OWNER_TURN_START
	s.reveal = p_card.reaction_reveal
	return s


func is_reaction() -> bool:
	return true


func reacts_to(ctx: BattleContext, owner: BattleUnit, _instance: StatusInstance,
		event: BattleEvent) -> bool:
	return card.reacts_to(ctx, owner, event)


func react(ctx: BattleContext, owner: BattleUnit, instance: StatusInstance,
		event: BattleEvent) -> void:
	card.react(ctx, owner, event)
	ctx.remove_status(owner, instance)  # a reaction fires once
