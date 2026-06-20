from typing import Dict, Tuple

# A clarification request ("what do you mean?") must not advance, regress, or
# otherwise touch the stage at all -- the user hasn't engaged with the content
# yet, they've only asked for it to be explained differently.
#
# Casual companion mode strategies are included for the same reason a fresh
# greeting shouldn't pre-load "validation": none of them read tracker.
# conversation_stage to shape their own text (they're dynamic/static banks,
# not ComponentNLGEngine), so letting them silently march the tracker through
# validation -> reflection -> exploration -> encouragement -> problem_solving
# while the user is just making small talk only sets up a heavier framing for
# whenever real distress eventually shows up. Freezing the stage here is the
# "greeting -> light_exploration -> closing" path for neutral check-ins --
# the moment genuine distress fires a real "*_support" strategy, the full
# state machine below resumes exactly where it left off.
NO_STAGE_CHANGE_STRATEGIES = {
    "explain_clarification",
    "greeting", "open_chat", "explore_checkin", "gentle_pivot",
    "casual_ack_strategy", "casual_answer_strategy", "accomplishment_ack",
    "misunderstanding_repair_strategy", "conversation_leader_strategy",
    "new_topic_strategy", "ambiguous_emotion_clarify_strategy",
    "repair_statement_strategy",
}

# Strategies that mean "something is getting worse / needs to de-escalate" --
# these always snap the conversation back to validation regardless of progress so far.
SNAP_TO_VALIDATION_STRATEGIES = {
    "escalation",
    "crisis_support",
    "crisis_followup_support",
    "crisis_continuation",
    "soft_escalation_support",
    "persistent_no_relief_support",
    "slow_down_support",
    "topic_shift_acknowledgement",
}

COPING_STRATEGIES = {
    "deliver_coping_step", "next_calming_step", "guided_breath_step",
    "body_symptom_action", "grounding_tactile_step", "chest_release_step",
    "orientation_step", "cool_down_grounding", "coping_alternative",
}

RELIEF_STRATEGIES = {
    "reinforce_small_progress", "stabilize_partial_relief", "soft_positive_transition",
}
# NOTE: "respond_to_no_relief" and "evaluate_task" are deliberately excluded --
# they fire when the user says something *didn't* help / is being evaluated,
# not when relief was actually shown. Treating them as relief signals caused
# premature encouragement right when the user says nothing is working.

RELIEF_INTENTS = {
    "slight_relief", "mixed_relief", "grounding_completed", "unclear_positive_feedback",
}

# Genuine escalation -- distinct from "still on the same hard topic" (e.g. plain
# academic_workload continuing isn't escalation by itself, it's just the topic).
# Used to step encouragement back to exploration when things get notably worse
# again, not merely because the same difficulty is still being discussed.
ESCALATION_INTENTS = {
    "physical_panic", "strong_negative_mood", "repeated_no_relief", "no_relief",
    "chronic_distress", "guilt_shame", "emptiness",
}

EXPLORATION_STRATEGIES = {
    "topic_exploration", "academic_explore_strategy", "panic_body_symptom_followup",
    "body_symptom_probe", "mixed_anxiety_followup", "anxiety_direct_open",
    "anxiety_body_or_thoughts_followup", "random_pattern_followup",
    "explore_checkin", "open_chat", "answer_acknowledgement_strategy",
}

PLANNING_KEYWORDS = [
    "what do i do", "what should i do", "what's the plan", "whats the plan",
    "need to finish", "have to finish", "by next month", "by next week",
    "by tomorrow", "how do i fix this", "how can i fix this",
    "how do i solve this", "next step", "next steps",
]

# Hard cap, not just a backstop: at most 2 consecutive exploration turns --
# past that the conversation must summarize (synthesis) rather than keep
# interviewing, regardless of whether a relief/resilience/coping signal has
# fired yet (those still short-circuit to encouragement earlier, same as
# before). Set to 1 (not 2) because _next() decides the NEXT turn's stage
# using the CURRENT turn's pre-increment `turns`, while THIS turn's content
# already used the stage as it was before that decision (see advance()'s
# effective_stage, captured before _next() runs) -- so the turn where
# `turns >= EXPLORATION_TURN_BACKSTOP` first becomes true is itself still
# rendered as the 2nd exploration turn, and only the turn after that
# actually renders as synthesis. ENCOURAGEMENT_TURN_BACKSTOP remains a
# generous backstop since encouragement isn't the "endless interviewing"
# problem these limits exist to fix.
EXPLORATION_TURN_BACKSTOP = 1
ENCOURAGEMENT_TURN_BACKSTOP = 3

# Problem 5: a relationship stay-or-leave dilemma that keeps coming back
# ("should I leave him", "I don't know whether to leave" again and again)
# means the user wants guidance, not more open-ended exploring -- fast-track
# to problem_solving once it's repeated this many turns in a row. Keyed off
# the topic classification that already ran upstream (relationship_uncertainty/
# fear_of_breakup specifically -- NOT the whole relationship_domain, since
# general relationship venting that never actually poses the stay-or-leave
# question shouldn't count toward this), so it stays in sync with whatever
# AdvancedNLUPipeline.extract_direct_rules() recognizes for those two topics.
RELATIONSHIP_DECISION_TOPICS = {"relationship_uncertainty", "fear_of_breakup"}
RELATIONSHIP_DECISION_REPEAT_THRESHOLD = 2


class ConversationStageEngine:
    """Deterministic conversation-stage progression (validation -> reflection ->
    exploration -> synthesis -> encouragement -> problem_solving).

    This modulates HumanResponseGenerator/ComponentNLGEngine's response
    composition; it does not replace SmarterDialogueManager's strategy
    selection. Call once per turn, after the strategy has been computed,
    with the tracker's *pre-turn* stage still in place.
    """

    def advance(self, strategy: str, state: Dict[str, str], tracker) -> str:
        # Clarification requests freeze the stage entirely -- no mutation, not
        # even a turn-count increment, since the user hasn't actually engaged
        # with the content of the previous turn yet.
        if strategy in NO_STAGE_CHANGE_STRATEGIES:
            return tracker.conversation_stage or "validation"

        # Safety first: de-escalation strategies always reset to validation.
        if strategy in SNAP_TO_VALIDATION_STRATEGIES:
            tracker.conversation_stage = "validation"
            tracker.stage_turns = 0
            tracker.relationship_decision_repeat_count = 0
            return "validation"

        current_stage = tracker.conversation_stage or "validation"

        # Problem 5: tracker.relationship_decision_repeat_count is updated by
        # SmarterDialogueManager._resolve_strategy() BEFORE this method runs
        # (see compute_strategy's call order) so that same-turn fast-track
        # logic there can react to it immediately -- this just reads the
        # already-current value rather than tracking it a second time.
        wants_decision_support = (
            tracker.relationship_decision_repeat_count >= RELATIONSHIP_DECISION_REPEAT_THRESHOLD
        )

        # Concrete planning language fast-tracks to problem_solving for *this*
        # turn, but only once some rapport has been built (not on a cold open).
        if current_stage != "validation" and (self._wants_problem_solving(strategy, state) or wants_decision_support):
            effective_stage = "problem_solving"
        else:
            effective_stage = current_stage

        next_stage, next_turns = self._next(
            effective_stage, tracker.stage_turns, strategy, state
        )
        tracker.conversation_stage = next_stage
        tracker.stage_turns = next_turns
        return effective_stage

    def _wants_problem_solving(self, strategy: str, state: Dict[str, str]) -> bool:
        if state.get("intent") == "seeking_solutions" or strategy == "solution_suggestion":
            return True
        clean_text = state.get("clean_text", "")
        return any(kw in clean_text for kw in PLANNING_KEYWORDS)

    def _next(
        self, stage: str, turns: int, strategy: str, state: Dict[str, str]
    ) -> Tuple[str, int]:
        is_support = strategy.endswith("_support")
        is_exploration = is_support or strategy in EXPLORATION_STRATEGIES
        is_coping = strategy in COPING_STRATEGIES
        is_relief = strategy in RELIEF_STRATEGIES
        has_new_info = bool(state.get("new_info")) or state.get("msg_word_count", 0) >= 12
        intent = state.get("intent", "")
        meaning_shift = state.get("meaning_shift")
        showing_relief = is_relief or intent in RELIEF_INTENTS
        showing_escalation = intent in ESCALATION_INTENTS and meaning_shift != "acceptance"

        if stage == "validation":
            if is_support or turns >= 1:
                return "reflection", 0
            return "validation", turns + 1

        if stage == "reflection":
            if has_new_info or is_exploration or turns >= 1:
                return "exploration", 0
            return "reflection", turns + 1

        if stage == "exploration":
            # Meaning-based triggers: a coping step was offered, the user shows
            # relief, or shows resilience/acceptance -- NOT just "enough turns
            # have passed". These still go straight to encouragement, same as
            # before. Everything else hits the hard 2-turn cap (Problem 4) and
            # must summarize (synthesis) instead of asking a third
            # exploration question in a row.
            resilience_shown = is_coping or showing_relief or meaning_shift == "acceptance"
            if resilience_shown:
                return "encouragement", 0
            if turns >= EXPLORATION_TURN_BACKSTOP:
                return "synthesis", 0
            return "exploration", turns + 1

        if stage == "synthesis":
            # Synthesis is a single-turn recap (Problem 3) -- it always
            # advances next turn, never loops back into more exploration.
            return "encouragement", 0

        if stage == "encouragement":
            if showing_relief:
                return "problem_solving", 0
            if showing_escalation:
                # Things got notably worse again rather than better -- step back
                # to investigating instead of forging ahead with encouragement.
                return "exploration", 0
            if turns >= ENCOURAGEMENT_TURN_BACKSTOP:
                return "problem_solving", 0
            return "encouragement", turns + 1

        # problem_solving is terminal until a topic change resets the tracker
        return "problem_solving", turns + 1
