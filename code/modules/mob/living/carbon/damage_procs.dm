/mob/living/carbon/apply_damage(damage, damagetype = BRUTE, def_zone = null, blocked = 0, forced = FALSE, spread_damage = FALSE, wound_bonus = 0, bare_wound_bonus = 0, sharpness = NONE, attack_direction = null, attacking_item)
	SEND_SIGNAL(src, COMSIG_MOB_APPLY_DAMAGE, damage, damagetype, def_zone)
	var/hit_percent = (100-blocked)/100
	if(!damage || (!forced && hit_percent <= 0))
		return 0

	var/obj/item/bodypart/BP = null
	if(!spread_damage)
		if(isbodypart(def_zone)) //we specified a bodypart object
			BP = def_zone
		else
			if(!def_zone)
				def_zone = get_random_valid_zone(def_zone)
			BP = get_bodypart(check_zone(def_zone))
			if(!BP)
				BP = bodyparts[1]

	var/damage_amount = forced ? damage : damage * hit_percent
	switch(damagetype)
		if(BRUTE)
			if(BP)
				if(BP.receive_damage(damage_amount, 0, wound_bonus = wound_bonus, bare_wound_bonus = bare_wound_bonus, sharpness = sharpness, attack_direction = attack_direction))
					update_damage_overlays()
			else //no bodypart, we deal damage with a more general method.
				adjustBruteLoss(damage_amount, forced = forced)
		if(BURN)
			if(BP)
				if(BP.receive_damage(0, damage_amount, wound_bonus = wound_bonus, bare_wound_bonus = bare_wound_bonus, sharpness = sharpness, attack_direction = attack_direction))
					update_damage_overlays()
			else
				adjustFireLoss(damage_amount, forced = forced)
		if(TOX)
			adjustToxLoss(damage_amount, forced = forced)
		if(OXY)
			adjustOxyLoss(damage_amount, forced = forced)
		if(CLONE)
			adjustCloneLoss(damage_amount, forced = forced)
		if(STAMINA)
			adjustStaminaLoss(damage_amount, forced = forced)
	SEND_SIGNAL(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, damage, damagetype, def_zone)
	return TRUE

//These procs fetch a cumulative total damage from all bodyparts
/mob/living/carbon/getBruteLoss()
	var/amount = 0
	for(var/X in bodyparts)
		var/obj/item/bodypart/BP = X
		amount += BP.brute_dam
	return amount

/mob/living/carbon/getFireLoss()
	var/amount = 0
	for(var/X in bodyparts)
		var/obj/item/bodypart/BP = X
		amount += BP.burn_dam
	return amount

/mob/living/carbon/adjustBruteLoss(amount, updating_health = TRUE, forced = FALSE, required_bodytype)
	if(!forced && (status_flags & GODMODE))
		return FALSE
	if(amount > 0)
		. = take_overall_damage(brute = amount, updating_health = updating_health, forced = forced, required_bodytype = required_bodytype)
	else
		. = heal_overall_damage(brute = abs(amount), required_bodytype = required_bodytype, updating_health = updating_health, forced = forced)

/mob/living/carbon/setBruteLoss(amount, updating_health = TRUE, forced = FALSE, required_bodytype)
	if(!forced && (status_flags & GODMODE))
		return FALSE
	var/current = getBruteLoss()
	var/diff = amount - current
	if(!diff)
		return FALSE
	return adjustBruteLoss(diff, updating_health, forced, required_bodytype)

/mob/living/carbon/adjustFireLoss(amount, updating_health = TRUE, forced = FALSE, required_bodytype)
	if(!forced && (status_flags & GODMODE))
		return FALSE
	if(amount > 0)
		. = take_overall_damage(burn = amount, updating_health = updating_health, forced = forced, required_bodytype = required_bodytype)
	else
		. = heal_overall_damage(burn = abs(amount), required_bodytype = required_bodytype, updating_health = updating_health, forced = forced)

/mob/living/carbon/setFireLoss(amount, updating_health = TRUE, forced = FALSE, required_bodytype)
	if(!forced && (status_flags & GODMODE))
		return FALSE
	var/current = getFireLoss()
	var/diff = amount - current
	if(!diff)
		return FALSE
	return adjustFireLoss(diff, updating_health, forced, required_bodytype)

/mob/living/carbon/adjustToxLoss(amount, updating_health = TRUE, forced = FALSE, required_biotype = ALL)
	if(!forced && (status_flags & GODMODE))
		return FALSE
	if(!forced && !(mob_biotypes & required_biotype))
		return FALSE
	if(!forced && HAS_TRAIT(src, TRAIT_TOXINLOVER)) //damage becomes healing and healing becomes damage
		amount = -amount
		if(HAS_TRAIT(src, TRAIT_TOXIMMUNE)) //Prevents toxin damage, but not healing
			amount = min(amount, 0)
		if(amount > 0)
			blood_volume = max(blood_volume - (5*amount), 0)
		else
			blood_volume = max(blood_volume - amount, 0)
	else if(!forced && HAS_TRAIT(src, TRAIT_TOXIMMUNE)) //Prevents toxin damage, but not healing
		amount = min(amount, 0)
	return ..()

/mob/living/carbon/adjustStaminaLoss(amount, updating_stamina, forced, required_biotype = ALL)
	. = ..()
	if(amount > 0)
		stam_regen_start_time = world.time + STAMINA_REGEN_BLOCK_TIME

/**
 * If an organ exists in the slot requested, and we are capable of taking damage (we don't have [GODMODE] on), call the damage proc on that organ.
 *
 * Arguments:
 * * slot - organ slot, like [ORGAN_SLOT_HEART]
 * * amount - damage to be done
 * * maximum - currently an arbitrarily large number, can be set so as to limit damage
 * * required_organ_flag - targets only a specific organ type if set to ORGAN_ORGANIC or ORGAN_ROBOTIC
 *
 * Returns: The net change in damage from apply_organ_damage()
 */
/mob/living/carbon/adjustOrganLoss(slot, amount, maximum, required_organ_flag = NONE)
	var/obj/item/organ/affected_organ = get_organ_slot(slot)
	if(!affected_organ || (status_flags & GODMODE))
		return FALSE
	if(required_organ_flag && !(affected_organ.organ_flags & required_organ_flag))
		return FALSE
	return affected_organ.apply_organ_damage(amount, maximum)

/**
 * If an organ exists in the slot requested, and we are capable of taking damage (we don't have [GODMODE] on), call the set damage proc on that organ, which can
 * set or clear the failing variable on that organ, making it either cease or start functions again, unlike adjustOrganLoss.
 *
 * Arguments:
 * * slot - organ slot, like [ORGAN_SLOT_HEART]
 * * amount - damage to be set to
 * * required_organ_flag - targets only a specific organ type if set to ORGAN_ORGANIC or ORGAN_ROBOTIC
 *
 * Returns: The net change in damage from set_organ_damage()
 */
/mob/living/carbon/setOrganLoss(slot, amount, required_organ_flag = NONE)
	var/obj/item/organ/affected_organ = get_organ_slot(slot)
	if(!affected_organ || (status_flags & GODMODE))
		return FALSE
	if(required_organ_flag && !(affected_organ.organ_flags & required_organ_flag))
		return FALSE
	if(affected_organ.damage == amount)
		return FALSE
	return affected_organ.set_organ_damage(amount)

/**
 * If an organ exists in the slot requested, return the amount of damage that organ has
 *
 * Arguments:
 * * slot - organ slot, like [ORGAN_SLOT_HEART]
 */
/mob/living/carbon/get_organ_loss(slot)
	var/obj/item/organ/affected_organ = get_organ_slot(slot)
	if(affected_organ)
		return affected_organ.damage

////////////////////////////////////////////

///Returns a list of damaged bodyparts
/mob/living/carbon/proc/get_damaged_bodyparts(brute = FALSE, burn = FALSE, required_bodytype = NONE, target_zone = null)
	var/list/obj/item/bodypart/parts = list()
	for(var/X in bodyparts)
		var/obj/item/bodypart/BP = X
		if(required_bodytype && !(BP.bodytype & required_bodytype))
			continue
		if(!isnull(target_zone) && BP.body_zone != target_zone)
			continue
		if((brute && BP.brute_dam) || (burn && BP.burn_dam))
			parts += BP
	return parts

///Returns a list of damageable bodyparts
/mob/living/carbon/proc/get_damageable_bodyparts(required_bodytype)
	var/list/obj/item/bodypart/parts = list()
	for(var/X in bodyparts)
		var/obj/item/bodypart/BP = X
		if(required_bodytype && !(BP.bodytype & required_bodytype))
			continue
		if(BP.brute_dam + BP.burn_dam < BP.max_damage)
			parts += BP
	return parts


///Returns a list of bodyparts with wounds (in case someone has a wound on an otherwise fully healed limb)
/mob/living/carbon/proc/get_wounded_bodyparts(brute = FALSE, burn = FALSE, required_bodytype)
	var/list/obj/item/bodypart/parts = list()
	for(var/X in bodyparts)
		var/obj/item/bodypart/BP = X
		if(required_bodytype && !(BP.bodytype & required_bodytype))
			continue
		if(LAZYLEN(BP.wounds))
			parts += BP
	return parts

/**
 * Heals ONE bodypart randomly selected from damaged ones.

 * It automatically updates damage overlays if necessary
 *
 * It automatically updates health status
 */
/mob/living/carbon/heal_bodypart_damage(brute = 0, burn = 0, updating_health = TRUE, required_bodytype = NONE, target_zone = null)
	. = FALSE
	var/list/obj/item/bodypart/parts = get_damaged_bodyparts(brute, burn, required_bodytype, target_zone)
	if(!parts.len)
		return

	var/obj/item/bodypart/picked = pick(parts)
	var/damage_calculator = picked.get_damage() //heal_damage returns update status T/F instead of amount healed so we dance gracefully around this
	if(picked.heal_damage(abs(brute), abs(burn), required_bodytype = required_bodytype))
		update_damage_overlays()
	return (damage_calculator - picked.get_damage())


/**
 * Damages ONE bodypart randomly selected from damagable ones.
 *
 * It automatically updates damage overlays if necessary
 *
 * It automatically updates health status
 */
/mob/living/carbon/take_bodypart_damage(brute = 0, burn = 0, updating_health = TRUE, required_bodytype, check_armor = FALSE, wound_bonus = 0, bare_wound_bonus = 0, sharpness = NONE)
	. = FALSE
	if(status_flags & GODMODE)
		return
	var/list/obj/item/bodypart/parts = get_damageable_bodyparts(required_bodytype)
	if(!parts.len)
		return

	var/obj/item/bodypart/picked = pick(parts)
	var/damage_calculator = picked.get_damage()
	if(picked.receive_damage(abs(brute), abs(burn), check_armor ? run_armor_check(picked, (brute ? MELEE : burn ? FIRE : null)) : FALSE, wound_bonus = wound_bonus, bare_wound_bonus = bare_wound_bonus, sharpness = sharpness))
		update_damage_overlays()
	return (damage_calculator - picked.get_damage())

/mob/living/carbon/heal_overall_damage(brute = 0, burn = 0, stamina = 0, required_bodytype, updating_health = TRUE, forced = FALSE)
	. = FALSE
	// treat negative args as positive
	brute = abs(brute)
	burn = abs(burn)

	var/list/obj/item/bodypart/parts = get_damaged_bodyparts(brute, burn, required_bodytype)

	var/update = NONE
	while(parts.len && (brute > 0 || burn > 0))
		var/obj/item/bodypart/picked = pick(parts)

		var/brute_was = picked.brute_dam
		var/burn_was = picked.burn_dam
		. += picked.get_damage()

		update |= picked.heal_damage(brute, burn, updating_health = FALSE, forced = forced, required_bodytype = required_bodytype)

		. -= picked.get_damage() // return the net amount of damage healed

		brute = round(brute - (brute_was - picked.brute_dam), DAMAGE_PRECISION)
		burn = round(burn - (burn_was - picked.burn_dam), DAMAGE_PRECISION)

		parts -= picked

	if(!.) // no change? no need to update anything
		return

	if(updating_health)
		updatehealth()
	if(update)
		update_damage_overlays()

/mob/living/carbon/take_overall_damage(brute = 0, burn = 0, stamina = 0, updating_health = TRUE, forced = FALSE, required_bodytype)
	. = FALSE
	if(!forced && (status_flags & GODMODE))
		return
	// treat negative args as positive
	brute = abs(brute)
	burn = abs(burn)

	var/list/obj/item/bodypart/parts = get_damageable_bodyparts(required_bodytype)
	var/update = NONE
	while(parts.len && (brute > 0 || burn > 0))
		var/obj/item/bodypart/picked = pick(parts)
		var/brute_per_part = round(brute/parts.len, DAMAGE_PRECISION)
		var/burn_per_part = round(burn/parts.len, DAMAGE_PRECISION)

		var/brute_was = picked.brute_dam
		var/burn_was = picked.burn_dam
		. += picked.get_damage()

		// disabling wounds from these for now cuz your entire body snapping cause your heart stopped would suck
		update |= picked.receive_damage(brute_per_part, burn_per_part, blocked = FALSE, updating_health = FALSE, forced = forced, required_bodytype = required_bodytype, wound_bonus = CANT_WOUND)

		. -= picked.get_damage() // return the net amount of damage healed

		brute = round(brute - (picked.brute_dam - brute_was), DAMAGE_PRECISION)
		burn = round(burn - (picked.burn_dam - burn_was), DAMAGE_PRECISION)

		parts -= picked

	if(!.) // no change? no need to update anything
		return

	if(updating_health)
		updatehealth()
	if(update)
		update_damage_overlays()
