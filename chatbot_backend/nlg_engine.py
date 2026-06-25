import random
from typing import Optional, Dict, List, Tuple


def _cap(text: str) -> str:
    return text[0].upper() + text[1:] if text else text


class ComponentNLGEngine:
    def __init__(self):
        self.TOPIC_TEMPLATES = {
            "relationship_loss": {
                "relationship_loss_support": [
                    "Breakups can bring up a lot of emotions all at once. Losing someone important can hurt deeply. What's been weighing on you the most since it happened?",
                    "That sounds incredibly painful. Going through a breakup can feel like your whole world has shifted. How are you holding up?",
                    "I hear you. Breakups are rarely easy and often leave a heavy feeling behind. What has felt hardest for you today?"
                ],
                "longing_support": [
                    "It's completely natural to feel that way. When someone was a big part of your life, the space they leave behind can feel impossible to ignore.",
                    "Missing them is often one of the hardest parts. It takes time for your mind and heart to adjust to them not being there.",
                    "It makes sense that you can't forget her. The connection you shared doesn't just disappear overnight."
                ],
                "mixed_feelings_support": [
                    "Missing someone and recognizing that the relationship wasn't healthy can both be true at the same time. Those feelings don't cancel each other out.",
                    "It sounds like part of you misses her deeply, while another part recognizes that the relationship wasn't healthy. Holding both of those truths at the same time can be confusing and painful."
                ],
                "rumination_behavior_strategy": [
                    "It sounds like part of you still feels connected, and checking up might be one way of holding onto that connection. What usually goes through your mind afterwards?",
                    "Many people find themselves looking for signs or memories after a breakup. How do you usually feel after checking?"
                ],
                "acceptance_acknowledgment": [
                    "It sounds like part of you is beginning to wonder whether letting go might ultimately be healthier, even though it still hurts.",
                    "Even with all the pain, it sounds like you're starting to see why part of you feels this separation may be for the best.",
                    "It takes strength to recognize that even though it hurts, part of you is beginning to see why this relationship may not have been healthy for you. Missing her and believing this might be for the best don't cancel each other out. Sometimes both feelings exist together.",
                    "A relationship can matter deeply and still not be good for you. It sounds like you're starting to recognize both sides of that."
                ]
            },
            "academic": {
                "mixed_feelings_support": [
                    "It makes sense to feel conflicted about your academic path right now.",
                    "School can bring up a lot of mixed feelings, especially when the workload is heavy."
                ],
                "academic_explore_strategy": [
                    "What part of your academic workload is weighing on you the most right now?",
                    "Is there a specific project or deadline making things feel overwhelming?"
                ]
            },
            "general": {}
        }
        
        # ── Validation bank: emotion-group-specific empathic openers ──
        self.validations = {
            "frustration": [
                "It can be incredibly discouraging",
                "I hear how frustrating it is",
                "That sounds really unfair",
                "It makes complete sense that you're frustrated",
                "That would wear anyone down",
                "I can understand why that's so irritating",
                "That sounds like it's testing your patience",
                "It's completely fair to feel frustrated by that",
            ],
            "sadness": [
                "I hear you. That sounds really heavy",
                "That sounds so painful to carry",
                "I'm sorry you're feeling so down",
                "It's completely okay to feel sad about this",
                "That sounds like a lot of sadness to hold onto",
                "I can hear how much this is weighing on you",
                "That sounds genuinely hard to sit with",
                "It makes sense that this would hurt",
            ],
            "panic": [
                "That physical reaction sounds really intense",
                "I hear you. Panic can be terrifying when it hits",
                "That sounds so overwhelming",
                "It makes sense that you're feeling panicked",
                "That sounds like your body went into overdrive",
                "I can imagine how frightening that must feel",
                "That's a lot for your body to be holding right now",
                "It's understandable that this feels so urgent",
            ],
            "anxiety": [
                "That sounds like a lot to worry about",
                "Anxiety can make everything feel urgent",
                "It's exhausting when your mind won't settle",
                "I hear how anxious this is making you",
                "That sounds like your mind is racing ahead of you",
                "It makes sense that the uncertainty feels unsettling",
                "That sounds like a heavy amount of worry to carry",
                "I can hear how on edge this has made you",
            ],
            "stress": [
                "That sounds like a really heavy burden right now",
                "It makes sense you're feeling stressed",
                "I can see how overwhelming this is",
                "That sounds like too much to handle all at once",
                "That's a lot to be juggling at the same time",
                "It's understandable that this feels like a lot of pressure",
                "That sounds genuinely draining",
                "I hear how stretched thin this is making you feel",
            ],
            "general": [
                "I hear you",
                "That sounds really tough",
                "I understand how that could feel overwhelming",
                "That makes complete sense",
                "Thank you for telling me that",
                "That sounds like a lot to be dealing with",
                "I'm glad you shared that with me",
                "That makes sense, given everything going on",
            ],
            "relationship_loss": [
                "That sounds really painful, especially with this happening so recently",
                "Breakups can leave a lot of emotions all at once",
                "Losing someone important can hurt deeply",
                "It makes sense that this would be weighing on you",
            ],
            "grief": [
                "Losing someone close can be incredibly difficult",
                "It makes sense that you're hurting after something like this",
            ],
            "academic": [
                "That sounds like a lot of pressure to carry",
                "Having several deadlines at once can feel overwhelming",
            ],
        }

        # ── Meaning-shift bank: acceptance/determination/persistence, distinct
        # from raw frustration -- used when the user's latest message has moved
        # past "this is hard" into "I'll do it anyway" ──
        self.acceptance_validations = [
            "It sounds like you've accepted that this still needs to get done, even though it's frustrating",
            "That takes real persistence, especially when things keep going wrong",
            "It makes sense to just push through, even when it's not going the way you'd hoped",
            "That's a lot of responsibility to carry, even without much choice in the matter",
            "It says something that you're still showing up for this, even when it's hard",
            "That kind of quiet determination matters, even when it doesn't feel like it",
        ]
        self.hopelessness_validations = [
            "It sounds like it's starting to feel pointless, even though you're still trying",
            "That sense of 'why bother' can creep in when nothing seems to be working",
            "It makes sense to feel like giving up when things keep not working out",
            "That kind of exhaustion, where it feels useless to keep going, is real",
        ]
        self.relief_validations = [
            "It's good to hear that helped, even a little",
            "That's a real shift — I'm glad something gave you a bit of relief",
            "Even a small bit of relief counts for something",
            "That sounds like a genuine moment of relief",
        ]
        self.confidence_validations = [
            "That sounds like real confidence coming through",
            "It's good to hear you believe you can handle this",
            "That kind of self-belief matters, especially after everything you've been through",
            "It sounds like you're starting to trust yourself with this",
        ]
        # Reflection Rewriter: generic human paraphrases of "you've made
        # progress" -- deliberately do NOT quote the user's own sentence back
        # (echoing raw text reads as parroting, not reflection). These stand
        # alone as complete sentences.
        self.progress_summaries = [
            "You've already finished a large portion of this.",
            "You're much further along than someone just starting out would be.",
            "It sounds like you've already put a huge amount of effort into this.",
            "You've covered a lot of ground already, even with some still left to go.",
            "That's a solid chunk of work already behind you.",
        ]
        # These are continuation clauses (lowercase, no leading subject) meant to
        # follow a validation line as a dash-joined clause.
        self.progress_validations = [
            "that's real, measurable progress",
            "that's a meaningful amount of progress, even if the rest still feels like a lot",
            "that's worth acknowledging as real movement forward",
            "that's progress, even with more still ahead",
        ]
        self.progress_followup = [
            "Which part of what's left feels the most manageable to start with?",
            "Is there one task in what's left you could knock out quickly?",
            "What's the very next thing you'd want to tackle from here?",
            "Which of the remaining pieces is worrying you the most?",
        ]
        self.MEANING_SHIFT_BANKS = {
            "acceptance": "acceptance_validations",
            "hopelessness": "hopelessness_validations",
            "relief": "relief_validations",
            "confidence": "confidence_validations",
            "progress": "progress_validations",
        }

        # ── Dead-end repair: when a response would otherwise be bare
        # validation/encouragement with no question and no reflective insight,
        # offer explicit conversation paths instead of leaving the user with
        # nothing to say next. Used when the user seems stuck (low engagement/
        # uncertain) and an entity is known, so the offered directions are
        # concrete rather than generic. ──
        self.conversation_paths = {
            "general": [
                "We could talk about what's been the hardest part of this, what's making you feel this way, or just how you've been coping with it.",
                "We can dig into the situation itself, what's been weighing on you about it, or just sit with how you're feeling right now.",
                "We could focus on the situation, on what's underneath the feeling, or just take a moment before going further.",
            ],
            "fallback": [
                "We could talk about what's been making this hard, how you're feeling about it, or just take a moment together.",
                "We can explore what's behind this, how you've been coping, or just slow down for a bit.",
            ],
        }
        self.STUCK_INTENTS = {"low_engagement", "short_idk", "uncertain"}

        # ── Answer Interpretation Layer: the user's short reply confirmed,
        # denied, or partially confirmed the bot's previous question/observation
        # -- compose a response that continues from that confirmed context
        # instead of restarting classification on a contentless "yes"/"both". ──
        self.confirmed_both_templates = [
            "It sounds like you're being squeezed from both directions — {option_a}, and {option_b} at the same time.",
            "That makes sense — both {option_a} and {option_b} are piling on at once.",
            "It sounds like it's not just one thing — {option_a} and {option_b} are both weighing on you.",
        ]
        self.confirmation_openers = [
            "That can be really frustrating.",
            "That makes a lot of sense.",
            "Okay, that helps me understand.",
            "That tracks with everything else you've said.",
        ]
        self.correction_acknowledgements = [
            "Okay, thanks for clarifying — I didn't have that quite right.",
            "Got it, that's useful to know.",
            "Okay, noted — that's not quite it then.",
        ]
        self.clarify_after_denial = [
            "What would you say is the bigger part of this, then?",
            "What feels closer to the real issue?",
            "What's actually been the main thing, then?",
        ]
        self.partial_acknowledgements = [
            "That sounds like a mixed bag — some of it fits, but maybe not all of it.",
            "That sounds about half right.",
            "Okay, sounds like it's not a clean yes or no.",
        ]
        self.clarify_after_partial = [
            "What feels closest to the truth for you?",
            "Which part fits, and which part doesn't?",
            "What would you say is more accurate?",
        ]

        # ── Clarification Intent Layer: explain the previous turn in simpler
        # terms using only context already known -- no new observations, no
        # stage movement, just a plainer restatement of the same question. ──
        self.clarification_intros = [
            "No worries, let me put that differently.",
            "Sorry, let me explain that another way.",
            "Sure — let me rephrase that.",
            "Good question, let me explain.",
        ]
        # Names actual TYPES of milestones instead of asking abstractly about
        # "what would help" -- easier for a stressed user to answer.
        self.clarification_ask_progress_concrete = [
            "I mean things like finishing one difficult module, solving a tricky issue, or getting a major feature working. Would any of those make you feel more confident about the remaining work?",
            "I mean something like wrapping up one tricky part, fixing a specific problem, or hitting a small milestone. Would something like that help?",
            "I mean things like clearing one hard module off your list, or getting one feature fully working. Would either of those feel like a win?",
        ]
        self.clarification_ask_event = [
            "I just meant — what's felt hardest about having to do that so far?",
            "I was wondering what's been the toughest part of that for you.",
        ]
        self.clarification_ask_entity = [
            "I just meant — what's been on your mind about it the most?",
            "I was wondering what's been hardest about that for you.",
        ]
        self.clarification_fallback = [
            "I just meant, in your own words — how has this been for you?",
            "No worries — just tell me a bit about how you're doing with this.",
        ]

        # ── Attention Lock System: explicitly name the pivot when the user
        # introduces a more specific domain than whatever was active before. ──
        self.attention_shift_templates = [
            "It sounds like the challenge has shifted from {previous} to {new}.",
            "It seems like this has moved on from {previous} to {new}.",
            "It sounds like the focus has changed — less about {previous}, more about {new} now.",
        ]

        # ── Validation-stage light curiosity: gentle, open invitations for
        # early context-gathering -- distinct from exploration's targeted asks ──
        self.light_curiosity = [
            "Do you have a sense of what's been weighing on you the most?",
            "What's been contributing to that feeling lately?",
            "Is there something specific that's been making this harder?",
            "What's been on your mind the most about this?",
            "Do you know what's been driving that feeling?",
        ]

        # ── Reflection (attached): dependent clause, joined after a validation line ──
        self.reflections = {
            "general": [
                "especially when you have to deal with so much at once.",
                "especially with everything going on.",
                "when you are facing such a tough situation.",
                "when this is constantly on your mind.",
                "especially with this weighing on you.",
                "particularly with how things have been going.",
            ]
        }
        self.reflections_event = {
            "general": [
                "especially having to {event}.",
                "particularly with having to {event} weighing on you.",
                "especially with having to {event} on your plate right now.",
                "when you're stuck having to {event}.",
            ]
        }

        # ── Reflection-stage summary: explicitly synthesizes understanding,
        # distinct in tone from validation ("So it sounds like...") ──
        self.reflection_summary = {
            "general": [
                "So it sounds like this has been the main thing weighing on you.",
                "It seems like this is the part that's been hardest to deal with.",
                "From what you've shared, this situation is really at the center of things right now.",
                "So far it sounds like this is what's been taking up most of your energy.",
                "It sounds like dealing with this is what's been taking up most of your energy.",
            ],
            "event": [
                "So it sounds like having to {event} is the main thing weighing on you.",
                "It seems like having to {event} is the part that's been hardest to deal with.",
                "From what you've shared, having to {event} is really at the center of this right now.",
                "So it sounds like the real struggle has been having to {event}.",
            ],
            "fallback": [
                "So it sounds like this has been sitting with you for a while now.",
                "From what you've shared, this has clearly been a lot to carry.",
                "It seems like this has been weighing on you more than you might be showing.",
            ],
        }
        self.reflection_followup = [
            "Does that sound about right?",
            "Is that the part that's been hardest, or is there more to it?",
            "Would you say that's the main thing right now?",
        ]

        # ── Exploration-stage: targeted, investigative -- gathers context,
        # never just restates how it feels ──
        self.investigate = {
            "general": [
                "What part of this feels the hardest to deal with right now?",
                "Has this been an ongoing issue, or did something change recently?",
                "What have you already tried?",
                "Is this happening every time, or only sometimes?",
                "What does this usually look like when it happens?",
                "Is there a pattern to when this gets worse?",
            ],
            "event": [
                "What part of having to {event} feels the hardest right now?",
                "Has having to {event} been an ongoing issue, or did something change recently?",
                "What have you already tried so far with that?",
                "Is having to {event} happening every time, or only sometimes?",
                "What does it look like when you have to {event}?",
            ],
            "fallback": [
                "Can you tell me a bit more about what happened?",
                "What's been the hardest part of this for you?",
                "Have you noticed a pattern to when this happens?",
                "What have you tried so far?",
                "What would be most useful to dig into right now?",
            ],
        }
        self.investigate_statement = {
            "general": [
                "It sounds like this has been a lot to deal with right now.",
                "This seems like it is weighing on you quite a bit.",
            ],
            "event": [
                "It sounds like having to {event} has been a lot to deal with.",
                "This seems like having to {event} is weighing on you right now.",
            ],
            "fallback": [
                "It sounds like this has been a lot to deal with.",
                "This seems like it's been weighing on you quite a bit.",
            ],
        }
        # "Recurring pattern" framing names something specific (this has
        # happened before, more than once) -- it must only be used when the
        # message actually carries that evidence (repetition_cue, e.g. "keep
        # happening"/"again and again"/"every week"/"always"/"repeatedly"),
        # never just because an event/topic is being discussed again. Several
        # deadlines landing in the same week is not a "recurring pattern".
        self.investigate_statement_recurring = {
            "general": [
                "It sounds like this keeps coming up for you.",
                "This seems like a pattern that's been building for a while.",
            ],
            "event": [
                "It sounds like having to {event} has turned into a recurring pattern.",
                "This seems like having to {event} keeps showing up, not just once.",
            ],
            "fallback": [
                "It sounds like this has been building for a while, not just today.",
                "This seems like more of a pattern than a one-off.",
            ],
        }

        # ── Category-specific content: a more specific lens than topic/event
        # alone, so a technical struggle reads differently from a deadline
        # crunch or a supervisor-feedback knock-back instead of generic
        # academic-stress phrasing ──
        self.category_content = {
            "technical": {
                # Evidence-gated: only used when the user actually mentioned a
                # bug/error/crash (tracker.technical_failure_evidence). Otherwise
                # the "_cautious" variants below are used instead -- the
                # Assumption Safety Layer exists specifically so the bot doesn't
                # invent "debugging"/"bugs" when the user only said "backend".
                "investigate_question": [
                    "What part has been the hardest to debug?",
                    "Has there been one issue causing most of the delays?",
                    "Is it more of a coding issue, or figuring out how everything connects together?",
                    "Has there been one bug causing most of the trouble?",
                    "Is it breaking in the same place each time, or somewhere new?",
                    "Is the challenge more about coding it or debugging it?",
                    "What part has been taking the most time?",
                ],
                "investigate_question_cautious": [
                    "I wonder whether the challenge is more about debugging, integration, or something else?",
                    "What's been the trickiest part of working on it technically?",
                    "Is it more about building something new, or fixing something that's not working?",
                    "Are the remaining tasks mostly big features, or smaller fixes?",
                    "What part has been taking the most time?",
                ],
                "investigate_statement": [
                    "It sounds like this has turned into an ongoing debugging struggle.",
                    "This seems like it's been more about chasing down bugs than building new things.",
                ],
                "investigate_statement_cautious": [
                    "It sounds like the technical side has been taking a lot of your attention lately.",
                    "It sounds like there's been a lot to manage on the technical side.",
                ],
                "observation": [
                    "Technical problems can be especially draining because progress often comes with a lot of trial and error before things finally start working.",
                    "When a system keeps breaking unexpectedly, it can feel like you're spending more time fixing things than actually moving forward.",
                    "It sounds like you've been putting a lot of energy into getting things working properly.",
                    "Debugging the same thing over and over can be exhausting in a way that's hard to explain unless you've done it.",
                    "Backend issues can be frustrating because one problem often affects several other parts of the system.",
                    "Sometimes technical blockers consume more energy than the actual amount of work remaining.",
                ],
                "observation_cautious": [
                    "Technical problems can be especially draining because progress often comes with a lot of trial and error before things finally start working.",
                    "It sounds like you've been putting a lot of energy into getting things working properly.",
                    "It sounds like the technical side has been taking up a lot of your energy lately.",
                    "Sometimes technical blockers consume more energy than the actual amount of work remaining.",
                ],
                "next_steps_question": [
                    "Is there one bug or piece that's blocking most of the rest of the work?",
                    "Would it help to isolate the smallest broken piece, rather than the whole system?",
                    "What's the very next thing you'd need to test or fix to make progress?",
                    "If you had to debug just one thing today, what would move things forward the most?",
                ],
                "next_steps_question_cautious": [
                    "What would feel like the most useful next step on the technical side?",
                    "Is there one part of it you'd want to tackle first?",
                ],
                "next_steps_statement": [
                    "It might help to isolate the one piece that's actually failing, rather than the whole system at once.",
                    "Sometimes the fastest way through is tackling the blocker first, even if it's not the biggest piece of work.",
                ],
                "next_steps_statement_cautious": [
                    "It might help to figure out which part to prioritize first on the technical side.",
                ],
            },
            "deadline": {
                "investigate_question": [
                    "How much do you still have left to do before the deadline?",
                    "What feels most urgent to tackle first?",
                    "Is it the amount of work, or the time you have left, that feels heavier?",
                ],
                "investigate_statement": [
                    "It sounds like the timeline is adding a lot of pressure on top of everything else.",
                    "It seems like the clock running down is its own separate stress from the work itself.",
                    "This sounds like it's less about the work and more about not having enough time for it.",
                ],
                "observation": [
                    "Working against a deadline can make everything feel more urgent than it might otherwise.",
                    "Trying to get everything done before time runs out can be exhausting on its own, separate from the work itself.",
                    "Having something due soon has a way of making every minute feel smaller than it actually is.",
                    "Even just watching the clock can wear you down before you've gotten to any of the actual work.",
                ],
                "next_steps_question": [
                    "What's the one task that, if you finished it next, would relieve the most pressure?",
                    "Would it help to list out everything left and rank it by urgency?",
                    "What's realistically possible before the deadline, versus what could slip if it had to?",
                ],
                "next_steps_statement": [
                    "It could help to separate what absolutely has to happen before the deadline from what can wait.",
                    "Sometimes ranking everything by urgency first makes the workload feel more manageable.",
                ],
            },
            "supervisor_feedback": {
                "investigate_question": [
                    "What part of the feedback felt hardest to hear?",
                    "Is this the first round of revisions, or has it been going back and forth a lot?",
                    "What's the main thing they're asking you to change?",
                ],
                "investigate_statement": [
                    "It sounds like the back-and-forth with feedback has been wearing you down.",
                    "This seems like it's less about the work itself and more about the constant revisions.",
                    "It sounds like every round of feedback is its own small setback.",
                ],
                "observation": [
                    "Having your work sent back for revisions can feel discouraging, especially after you've already put in the effort.",
                    "It's tough when feedback feels like it's undoing progress you thought you'd already made.",
                ],
                "next_steps_question": [
                    "Of everything they asked you to change, what's the smallest one to start with?",
                    "Is there a part of the feedback you actually agree with, that might be easier to tackle first?",
                ],
                "next_steps_statement": [
                    "It might help to address the smallest requested change first, just to get moving again.",
                ],
            },
            "academic": {
                "investigate_question": [
                    "What part of the project feels most overwhelming right now?",
                    "Is there one part of this that's taking up most of your time?",
                ],
                "investigate_statement": [
                    "It sounds like the workload itself has been the heaviest part of this.",
                ],
                "observation": [],
            },
            # Several deadlines landing at once -- distinct from a single
            # "deadline" crunch and never framed as a recurring pattern,
            # since simultaneous isn't repeated. See _problem_solving_line's
            # dedicated multiple_deadlines branch for the problem_solving-
            # stage content (validation + normalization + prioritization).
            "multiple_deadlines": {
                "investigate_question": [
                    "Which of these feels most urgent to tackle first?",
                    "Is it the number of things due, or how close together they are, that feels heaviest?",
                ],
                "investigate_statement": [
                    "It sounds like having several things due around the same time is what's making this feel so heavy.",
                    "This seems like the sheer number of deadlines landing together is what's piling on the pressure.",
                ],
                "observation": [
                    "Having several deadlines at once can make everything feel overwhelming.",
                    "When everything seems urgent at the same time, it's easy to feel stuck.",
                ],
            },
            "relationship": {
                "investigate_question": [
                    "What was going through your mind when that happened?",
                    "How have things felt between you two since then?",
                ],
                "investigate_statement": [
                    "It sounds like this has been sitting with you since it happened.",
                    "This seems like it's been replaying in your mind more than you'd like.",
                ],
                "observation": [
                    "It makes sense that this would still be on your mind -- relationships carry a lot of weight.",
                    "It sounds like this has taken up a lot of emotional space for you.",
                ],
            },
            "family": {
                "investigate_question": [
                    "How long has this been affecting you?",
                    "What's it been like having this going on at home?",
                ],
                "investigate_statement": [
                    "It sounds like this has been a strain for a while now.",
                    "This seems like it's been weighing on you at home more than you've let on.",
                ],
                "observation": [
                    "Family situations can be especially hard because there's often no real way to step away from them.",
                    "It sounds like this has been weighing on you in a way that's hard to switch off from.",
                ],
            },
        }
        # categories specific enough to outrank a strategy's own generic question bank
        self.SPECIFIC_CATEGORIES = {"technical", "deadline", "supervisor_feedback", "relationship", "family", "multiple_deadlines"}

        # ── Slot Completeness Tracking: a question bank entry that just asks
        # for information the user already volunteered this session (see
        # tracker.deadline_timing_known/workload_incomplete_known in
        # AdvancedNLUPipeline) must be skipped rather than asked again --
        # matched by substring against the bot's own template text, same
        # approach as ANSWER_TYPE_PATTERNS in HumanResponseGenerator.
        self.REDUNDANT_QUESTION_RULES = [
            ("how much do you still have left to do before the deadline", "workload_incomplete_known"),
            ("how much work is", "workload_incomplete_known"),
            ("how much is left", "workload_incomplete_known"),
        ]

        # ── Multi-Event Fusion: when the user discloses a deadline-flavored
        # event (a presentation/deadline/exam) AND that the work itself isn't
        # ready, in the same breath or the same thread, a single fused
        # observation naming BOTH is far more "understood" than picking one
        # category's generic bank and ignoring the other half of what was
        # said. {event} is the deadline-flavored thing (e.g. "your FYP
        # presentation"); used only when workload_incomplete_known is True.
        self.deadline_workload_fusion_observations = [
            "Having {event} coming up while feeling like the work still isn't ready can create a lot of pressure.",
            "It can feel like time is moving faster than you'd like when something important is approaching and it still isn't done.",
            "Trying to prepare for {event} while it still feels unfinished is its own kind of stress, on top of the work itself.",
        ]

        # ── Answering a pending question continues the same thread -- this
        # acknowledges the specific answer instead of pivoting to a canned line ──
        self.answer_ack = {
            "general": [
                "Ah, so this has been taking up most of your time.",
                "Got it, so this is the main thing going on.",
                "I see, so this is where most of the pressure is coming from.",
                "That makes sense, so this is what's been keeping you busy.",
            ],
            "event": [
                "Ah, so having to {event} has been taking up most of your time.",
                "Got it, so having to {event} is the main thing going on.",
                "I see, so having to {event} is where most of this is coming from.",
            ],
            "fallback": [
                "Thanks for telling me that.",
                "Got it, that helps me understand better.",
            ],
        }

        # ── Typed Pending Questions: an answer to a duration/quantity/
        # project_name/issue question is interpreted as THAT kind of value,
        # never run through the generic {topic}/{event} acknowledgment above
        # -- "one week" answering "how much time has X been taking up?" is a
        # timespan, not a new topic ("One week has been keeping you busy
        # lately" is wrong). See generate_response's answer_previous_question
        # branch and AdvancedNLUPipeline's expected_answer_type inference.
        self.duration_answer_acks = [
            "So you've been putting a lot of time into it already.",
            "That's a real chunk of time to have already spent on it.",
            "Sounds like it's already taken up a fair amount of your time.",
        ]
        self.quantity_answer_acks = [
            "That's a lot to juggle at once.",
            "That's a fair amount to be carrying all together.",
            "That's a real handful to manage at the same time.",
        ]
        self.priority_choice_acks = [
            "That makes sense. Sounds like {entity} feels like the biggest priority right now.",
            "Got it -- sounds like {entity} is the one weighing on you most right now.",
            "Okay, sounds like {entity} feels like the highest priority right now.",
        ]
        self.priority_choice_followup = [
            "What's been slowing you down the most with it?",
            "What's been the biggest holdup with it so far?",
            "What part of it has been the hardest to get moving on?",
        ]
        self.issue_answer_technical = [
            "Backend issues can be frustrating because one bug often affects several things.",
            "That kind of technical snag can eat up more time than the actual work itself.",
        ]
        self.issue_answer_with_entity = [
            "{entity} sounds like the real sticking point right now.",
            "It sounds like {entity} is what's actually been holding things up.",
        ]
        self.issue_answer_fallback = [
            "That sounds like the real sticking point right now.",
            "It sounds like that's what's actually been holding things up.",
        ]

        # ── Assumption Safety Layer (emotional): topic mention != emotional
        # state. When answer_previous_question only surfaces a topic ("I'm
        # doing my FYP") and no distress/emotion has actually been expressed
        # yet (has_emotional_evidence), the follow-up must stay strictly in
        # attention/focus/time-occupied territory -- never infer stress,
        # pressure, exhaustion, frustration, or anxiety until that evidence
        # appears. Once it does, _investigate_line's richer content applies
        # instead (see the answer_previous_question branch below). ──────────
        self.answer_neutral_followup = {
            "statement": {
                "general": [
                    "Sounds like things have been keeping you busy lately.",
                    "Looks like you've been spending a lot of time on this.",
                    "This seems to be taking up quite a bit of your attention recently.",
                ],
                "event": [
                    "Sounds like having to {event} has been keeping you busy lately.",
                    "Looks like you've been spending a lot of time on having to {event}.",
                    "Having to {event} seems to be taking up quite a bit of your attention recently.",
                ],
                "fallback": [
                    "Sounds like that's been keeping you busy lately.",
                    "Looks like that's taken up quite a bit of your time recently.",
                ],
            },
            "question": {
                "general": [
                    "How much of your time has this been taking up lately?",
                    "Is this the main thing you've been focused on lately?",
                    "What's been on your plate the most?",
                ],
                "event": [
                    "How much time has having to {event} been taking up lately?",
                    "Is having to {event} the main thing you've been focused on?",
                ],
                "fallback": [
                    "What's been taking up most of your time lately?",
                    "Is that the main thing you've been focused on?",
                ],
            },
        }

        # ── Encouragement: forward-looking, supportive, no question ──
        self.encouragements = [
            "You've already shown you can keep going even when it's hard.",
            "It says a lot that you're still working through this.",
            "You're handling more than you're probably giving yourself credit for.",
            "Whatever happens next, you don't have to figure it out perfectly.",
            "You've gotten through hard moments before, and that matters.",
            "Taking it one piece at a time is still real progress.",
            "It's okay to move through this slowly — you're still moving.",
            "You're allowed to be proud of how far you've already come with this.",
        ]
        self.encouragement_followup = [
            "What's helped you keep going so far?",
            "Where have you found a bit of strength in this so far?",
            "What's made the biggest difference for you up to now?",
        ]

        # ── Observation (standalone): full sentences, no validation needed ──
        self.observations = {
            "general": [
                "It sounds like this has been sitting with you for a while now.",
                "This seems to be taking up a lot of space in your mind right now.",
                "It seems like this keeps coming back to mind.",
                "It sounds like this has been wearing on you lately.",
                "It makes sense that this would feel like a lot right now.",
                "That sounds like it's been a heavy thing to carry around.",
            ],
            "fallback": [
                "It sounds like there's a lot sitting with you right now.",
                "This seems to be taking up a lot of space in your mind.",
                "It makes sense that this would feel like a lot to carry.",
                "That sounds like it's been weighing on you for a bit.",
                "There's clearly a lot going on beneath the surface right now.",
            ],
        }
        # ── Label Reframe Layer: when the resolved topic/entity is itself a
        # diagnostic or clinical-sounding label ("toxic relationship",
        # "depression", "anxiety", "stress") rather than a concrete topic
        # noun (backend, database, deadline, exam), a templated "It sounds
        # like {topic} is carrying most of the weight" just parrots the
        # label back. These full, ready-made observations replace that
        # template instead, turning the label into a reflective insight
        # about the person's experience. Matched by substring against the
        # lowercased focus_clause/entity (see _label_reframe below), so
        # "your anxiety"/"this anxiety" etc. still match.
        self.label_reframe_observations = {
            "toxic relationship": [
                "You're questioning whether this relationship is healthy for you.",
                "Part of you seems unsure whether your emotional needs are being met.",
            ],
            "depression": [
                "It sounds like you've been carrying a heaviness that's hard to put into words.",
                "Part of you seems to be struggling to feel like yourself lately.",
            ],
            "anxiety": [
                "It sounds like your mind has been racing ahead, bracing for what might go wrong.",
                "Part of you seems to be on edge, like it's hard to fully relax.",
            ],
            "stress": [
                "It sounds like there's just been too much landing on you all at once.",
                "Part of you seems stretched thin trying to keep up with everything.",
            ],
        }
        self.observations_event = {
            "general": [
                "Having to {event} sounds like it would wear anyone down.",
                "It makes sense that having to {event} would feel discouraging.",
                "Having to {event} sounds genuinely tiring.",
                "Having to {event} sounds like a frustrating thing to keep facing.",
            ]
        }
        # ── Recurring-failure framing: used when repetition_cue is set --
        # names the *pattern* of repeated failure, not just "tiring + again" ──
        self.observations_event_recurring = [
            "When something keeps failing after multiple attempts, it can start feeling like you're putting in effort without seeing progress.",
            "Having to {event} over and over again can chip away at your motivation, even if you keep showing up for it.",
            "It's especially frustrating to keep having to {event} despite everything you've already tried.",
            "Repeated setbacks like this can make it feel like nothing is moving forward, even when you're putting in real effort.",
        ]

        # ── Problem-solving stage: next steps ──
        self.next_steps = {
            "fallback": [
                "What's one small step you could take that feels manageable?",
                "Is there any part of this that is within your control right now?",
                "What's the very next concrete task you need to do?",
                "Let's break this down. What's the very next thing you need to focus on?",
                "If you had to pick just one thing to tackle first, what would it be?",
                "What's the smallest piece of this you could finish today?",
                "What's the smallest version of progress that would still count?",
            ],
            "topic": [
                "What's the biggest blocker right now?",
                "If you broke this down into smaller pieces, what would the first piece be?",
                "What's the one part of this that, if solved, would make the rest easier?",
            ],
            "event": [
                "What's the biggest blocker standing in the way of having to {event}?",
                "If you broke down having to {event} into smaller pieces, what would come first?",
            ],
        }
        self.next_steps_statement = {
            "fallback": [
                "One option could be focusing on just the part that's breaking first, rather than the whole thing.",
                "Sometimes it helps to tackle the smallest piece first, just to get some momentum back.",
                "It might help to separate what needs fixing now from what can wait.",
            ],
            "topic": [
                "It might help to break this down into smaller, more manageable pieces.",
            ],
            "event": [
                "It might help to break having to {event} down into smaller, more manageable pieces.",
            ],
        }
        # ── Relationship decision problem-solving (Problem 3): a "what
        # should I do" about a relationship isn't a blocker to break into
        # smaller pieces -- it needs validation, permission to not decide
        # right away, a few honest reflection points, and ONE gentle
        # decision-focused question, never generic "break it down further"
        # exploration. See _relationship_decision_line below.
        self.relationship_decision_content = {
            "validations": [
                "That's a difficult place to be, especially when you still care about them and also fear what comes after a breakup.",
                "That's a genuinely hard spot to be in -- caring about someone while still feeling unsure can pull you in two directions at once.",
                "It makes sense this feels so hard -- you're weighing what you have against what you're afraid of losing.",
            ],
            "normalizers": [
                "You don't necessarily need to decide immediately.",
                "This isn't something you have to figure out all at once.",
                "There's no rush to land on a clear answer right now.",
            ],
            "reflection_points": [
                "Do I feel loved and respected most of the time?",
                "Have I told them what feels missing?",
                "Am I staying because I truly want to, or because I'm afraid of being alone?",
                "What would I tell a close friend in this exact situation?",
                "Has anything actually changed when I've raised this before?",
                "What do I need emotionally?",
                "Have I communicated those needs?",
                "Am I staying because I want to, or because I fear loneliness?",
            ],
            "decision_questions": [
                "Which feels scarier right now -- leaving, or staying?",
                "What would need to change for you to feel sure about staying?",
                "If the fear of being alone wasn't part of it, what would you want?",
            ],
        }
        # ── Multiple-deadlines problem-solving: several things due at once
        # need validation + permission to not do everything at once + ONE
        # gentle prioritization question -- never the generic blocker/
        # breakdown next-step content, and never "recurring pattern" framing
        # (simultaneous deadlines aren't a repeated pattern). See
        # _multiple_deadlines_problem_solving_line below.
        self.multiple_deadlines_problem_solving = {
            "validations": [
                "That sounds like a lot to carry all at once.",
                "Juggling several things due at the same time is genuinely a lot to hold.",
                "That's a heavy load to be facing all together.",
            ],
            "normalizers_with_entity": [
                "You don't have to solve all of {entity} at the same time.",
                "You don't have to tackle {entity} all in one go.",
            ],
            "normalizers_generic": [
                "You don't have to solve everything at the same time.",
                "You don't have to tackle all of it in one go.",
                "It's okay to take these one at a time instead of all at once.",
            ],
            "prioritization_questions": [
                "Which one feels most urgent or easiest to start with?",
                "If you only picked one to start with, which would it be?",
                "Which of these would relieve the most pressure if it were done first?",
            ],
        }
        # ── Synthesis stage (Problem 3/4): after a couple of exploration
        # turns, recap the pattern across what's been shared instead of
        # asking a third exploration question in a row -- show
        # understanding, don't advance the topic. Relationship situations
        # get their own bank (the same "cares, but something's still
        # missing" tension _relationship_decision_line validates), other
        # categories get a generic event/topic-aware recap.
        self.relationship_synthesis_observations = [
            "It sounds like you appreciate how he treats you and the care he shows, but emotionally something still feels missing. That's leaving you feeling torn about whether breaking up would solve the pain or create a different kind of pain.",
            "Putting it together, there's real care here, but also a quieter sense that something isn't being met -- and that mix is exactly what makes this so hard to sit with.",
            "It sounds like this isn't really about whether they're a good person -- it's about whether what you're getting is enough for what you actually need.",
        ]
        self.synthesis_observations = {
            "general": [
                "Putting it together, it sounds like this has been the thread running through a lot of it.",
                "Stepping back, this keeps showing up as the thing underneath everything else you've shared.",
            ],
            "event": [
                "Putting it together, it sounds like having to {event} keeps being the thing underneath everything else.",
                "Stepping back, having to {event} seems to be the thread running through a lot of this.",
            ],
            "fallback": [
                "Putting everything together, it sounds like there's a real mix of feelings here, all tangled up with each other.",
                "Stepping back, there's clearly a lot happening underneath the surface that's hard to untangle into just one feeling.",
            ],
        }

    def _map_emotion_to_group(self, intent: str, topic_label: Optional[str] = None, event_category: Optional[str] = None) -> str:
        intent = intent.lower()
        topic_label = (topic_label or "").lower()
        event_category = (event_category or "").lower()

        if topic_label == "relationship_loss" or "relationship_loss" in intent:
            return "relationship_loss"
        if topic_label == "grief" or "grief" in intent:
            return "grief"
        if topic_label == "academic" or event_category == "academic" or "academic" in intent:
            return "academic"

        if "anger" in intent or "frustration" in intent:
            return "frustration"
        if "sadness" in intent or "depression" in intent or "emptiness" in intent:
            return "sadness"
        if "panic" in intent:
            return "panic"
        if "anxiety" in intent or "worry" in intent or "fear" in intent:
            return "anxiety"
        if "pressure" in intent or "stress" in intent or "burnout" in intent:
            return "stress"
        if "workload" in intent or "coding" in intent or "deadline" in intent:
            return "stress"
        return "general"

    # ── diversity helpers ──────────────────────────────────────────────
    _CATEGORY_KEYWORDS = {
        "tiring": ["tiring", "exhaust", "wear", "drain", "worn"],
        "heavy": ["heavy", "weigh", "carry", "burden"],
        "difficulty": ["difficult", "hard", "tough"],
        "overwhelm": ["overwhelm", "too much", "a lot"],
        "frustration": ["frustrat", "unfair", "irritat", "patience"],
    }

    def _categorize(self, text: str) -> str:
        t = text.lower()
        for category, keywords in self._CATEGORY_KEYWORDS.items():
            if any(kw in t for kw in keywords):
                return category
        return "general"

    def _pick_fresh(self, options: List[str], recent_phrases: List[str]) -> str:
        fresh = [o for o in options if o not in recent_phrases]
        pool = fresh if fresh else options
        return random.choice(pool)

    def _pick_diverse(
        self, options: List[str], recent_phrases: List[str], recent_categories: List[str]
    ) -> Tuple[str, str]:
        fresh = [o for o in options if o not in recent_phrases]
        pool = fresh if fresh else options
        non_repeat = [o for o in pool if self._categorize(o) not in recent_categories]
        final_pool = non_repeat if non_repeat else pool
        choice = random.choice(final_pool)
        return choice, self._categorize(choice)

    def _category_bank(self, cat, key, event_category, has_evidence):
        """Assumption Safety Layer: for 'technical', prefer the hedged
        '_cautious' variant unless the user actually mentioned a bug/error/
        crash (has_evidence) -- so the bot doesn't invent "debugging"/"bugs"
        from a plain mention like "my backend and core tech." Other
        categories don't define cautious variants, so this is a no-op there."""
        if event_category == "technical" and not has_evidence:
            cautious = cat.get(key + "_cautious")
            if cautious:
                return cautious
        return cat.get(key)

    def _filter_redundant_questions(self, bank, known_slots):
        """Drop any question in `bank` that would just ask for a slot the
        user already filled this session (e.g. "how much do you still have
        left to do?" right after "my system still isn't ready") -- returns
        None if EVERY question turns out redundant, so the caller can fall
        back to a statement instead of asking anyway. A no-op when
        known_slots is empty, so callers that never pass it behave exactly
        as before."""
        if not bank or not known_slots:
            return bank
        filtered = [
            q for q in bank
            if not any(slot in known_slots and sub in q.lower() for sub, slot in self.REDUNDANT_QUESTION_RULES)
        ]
        return filtered if filtered else None

    def _answer_neutral_followup(self, event, entity, ask_question, pick):
        """Strictly neutral continuation for answer_previous_question when
        has_emotional_evidence is False -- attention/focus/time-occupied
        framing only. See answer_neutral_followup for the principle this
        enforces: topic mention != emotional state."""
        bank = self.answer_neutral_followup["question" if ask_question else "statement"]
        if event:
            pool = [t.replace("{event}", event) for t in bank["event"]]
        elif entity:
            pool = [t.replace("{topic}", entity).replace("{Topic}", _cap(entity)) for t in bank["general"]]
        else:
            pool = list(bank["fallback"])
        chosen = pick(pool)
        return chosen if ask_question else _cap(chosen)

    def _issue_answer_line(self, entity, event, pick) -> str:
        """Acknowledge an "issue"-typed answer (what's blocking/wrong) by
        naming the actual blocker flavor when it's recognizably technical,
        rather than a generic "X is where this is coming from" topic ack."""
        focus = (entity or event or "").lower()
        if any(kw in focus for kw in ("backend", "bug", "code", "coding", "database", "api", "server")):
            return pick(self.issue_answer_technical)
        if entity:
            return _cap(pick(self.issue_answer_with_entity).replace("{entity}", entity))
        return pick(self.issue_answer_fallback)

    def _investigate_line(self, event_category, event, entity, action_options, ask_question, pick, pick_diverse=None, has_evidence=False, repetition_cue=False, known_slots=frozenset()):
        """Resolve the exploration-stage investigative line. A *specific* category
        (technical/deadline/supervisor_feedback/relationship/family/
        multiple_deadlines) has its own small bank used exclusively, since
        it's a strong, precise signal. A generic "academic" category instead
        gets merged into the broader event/entity-aware pool -- exclusive use
        of its tiny bank caused rapid repetition for the (very common)
        plain-academic case.

        Statement-style content (not questions) goes through pick_diverse when
        provided, so the same observation "flavor" doesn't repeat across turns
        even when the exact wording differs. repetition_cue only widens the
        statement pool with "recurring pattern" framing when there's actual
        evidence of recurrence -- see investigate_statement_recurring."""
        pick_stmt = pick_diverse or pick
        cat = self.category_content.get(event_category) if event_category else None
        is_specific = event_category in self.SPECIFIC_CATEGORIES

        if cat and is_specific:
            if ask_question:
                bank = self._category_bank(cat, "investigate_question", event_category, has_evidence)
                filtered = self._filter_redundant_questions(bank, known_slots)
                if filtered:
                    return pick(filtered)
                if bank:
                    # Every question this category could ask was already
                    # answered (Slot Completeness Tracking) -- speak instead
                    # of asking anyway just because ask_question rolled True.
                    statement_bank = self._category_bank(cat, "investigate_statement", event_category, has_evidence)
                    if statement_bank:
                        return _cap(pick_stmt(statement_bank))
            else:
                bank = self._category_bank(cat, "investigate_statement", event_category, has_evidence)
                if bank:
                    return _cap(pick_stmt(bank))

        if action_options:
            if ask_question:
                return pick(action_options)
            else:
                stmts = [o for o in action_options if "?" not in o]
                if stmts:
                    return pick(stmts)

        if ask_question:
            if event:
                pool = [t.replace("{event}", event) for t in self.investigate["event"]]
            elif entity:
                pool = [t.replace("{topic}", entity) for t in self.investigate["general"]]
            else:
                pool = list(self.investigate["fallback"])
            if cat and cat.get("investigate_question"):
                pool = pool + list(cat["investigate_question"])
            return pick(self._filter_redundant_questions(pool, known_slots) or pool)

        if event:
            stm_pool = list(self.investigate_statement["event"])
            if repetition_cue:
                stm_pool = stm_pool + list(self.investigate_statement_recurring["event"])
        elif entity:
            stm_pool = list(self.investigate_statement["general"])
            if repetition_cue:
                stm_pool = stm_pool + list(self.investigate_statement_recurring["general"])
        else:
            stm_pool = list(self.investigate_statement["fallback"])
            if repetition_cue:
                stm_pool = stm_pool + list(self.investigate_statement_recurring["fallback"])
        if cat and cat.get("investigate_statement"):
            stm_pool = stm_pool + list(cat["investigate_statement"])
        chosen = pick_stmt(stm_pool)
        if event:
            chosen = chosen.replace("{event}", event)
        elif entity:
            chosen = chosen.replace("{topic}", entity)
        return _cap(chosen)

    def _synthesis_line(self, event_category, event, entity, pick) -> str:
        """Synthesis stage (Problem 3/4): summarize the pattern across the
        last couple of exploration turns instead of asking another
        question -- show understanding, don't advance. Deliberately
        ignores ask_question entirely (the caller never appends one for
        this stage either) since the whole point is to NOT ask something
        new immediately after recapping."""
        if event_category == "relationship":
            return pick(self.relationship_synthesis_observations)
        reframed = self._label_reframe(entity, pick) if entity else None
        if reframed:
            return reframed
        bank = self.synthesis_observations
        if event:
            return pick(bank["event"]).replace("{event}", event)
        if entity:
            return pick(bank["general"]).replace("{topic}", entity)
        return pick(bank["fallback"])

    def _relationship_decision_line(self, pick) -> str:
        """Problem-solving content for a relationship decision dilemma
        ("What should I do?" about staying/leaving) -- validate, normalize
        that there's no rush to decide, offer a few honest reflection
        points, then ask ONE gentle decision-focused question. Deliberately
        does not branch on ask_question -- this structure's whole point is
        the closing decision question, unlike the generic blocker/
        breakdown framing _problem_solving_line uses for technical/
        academic problem-solving below."""
        bank = self.relationship_decision_content
        validation = pick(bank["validations"])
        normalizer = pick(bank["normalizers"])
        points = random.sample(
            bank["reflection_points"], k=min(3, len(bank["reflection_points"]))
        )
        points_text = "\n".join(f"- {p}" for p in points)
        question = pick(bank["decision_questions"])
        return (
            f"{validation} {normalizer}\n\n"
            f"Sometimes it helps to ask:\n\n{points_text}\n\n{question}"
        )

    def _multiple_deadlines_problem_solving_line(self, entity, pick) -> str:
        """Problem-solving content for several simultaneous deadlines
        (Problem 4): validation that this is genuinely a lot, permission to
        not solve everything at once, then ONE gentle prioritization
        question -- never the generic blocker/breakdown framing
        _problem_solving_line uses below, and never a "recurring pattern"
        observation (simultaneous isn't repeated)."""
        bank = self.multiple_deadlines_problem_solving
        validation = pick(bank["validations"])
        if entity:
            normalizer = pick(bank["normalizers_with_entity"]).replace("{entity}", entity)
        else:
            normalizer = pick(bank["normalizers_generic"])
        question = pick(bank["prioritization_questions"])
        return f"{validation} {normalizer} {question}"

    def _problem_solving_line(self, event_category, event, entity, ask_question, pick, pick_diverse=None, has_evidence=False, known_slots=frozenset()):
        """Resolve problem-solving-stage content: identify blockers, break the
        problem down, prioritize -- never a generic exploration question.
        Same priority pattern as _investigate_line: specific category bank
        first (it names the actual blocker-type), then event/topic-aware
        generic next-step content, then a content-free fallback.

        Relationship decision dilemmas and multiple-simultaneous-deadlines
        are exceptions to that generic pattern (Problem 3/4): neither is a
        single blocker to break into smaller pieces, so they route to their
        own dedicated composers above instead of the blocker-style content
        below."""
        if event_category == "relationship":
            return self._relationship_decision_line(pick)
        if event_category == "multiple_deadlines":
            return self._multiple_deadlines_problem_solving_line(entity, pick)
        pick_stmt = pick_diverse or pick
        cat = self.category_content.get(event_category) if event_category else None
        is_specific = event_category in self.SPECIFIC_CATEGORIES

        if cat and is_specific:
            if ask_question:
                bank = self._category_bank(cat, "next_steps_question", event_category, has_evidence)
                filtered = self._filter_redundant_questions(bank, known_slots)
                if filtered:
                    return pick(filtered)
                if bank:
                    # Same Slot Completeness fallback as _investigate_line:
                    # don't ask anyway once every question here is redundant.
                    statement_bank = self._category_bank(cat, "next_steps_statement", event_category, has_evidence)
                    if statement_bank:
                        return _cap(pick_stmt(statement_bank))
            else:
                bank = self._category_bank(cat, "next_steps_statement", event_category, has_evidence)
                if bank:
                    return _cap(pick_stmt(bank))

        if ask_question:
            bank = self.next_steps
            if event:
                pool = [t.replace("{event}", event) for t in bank["event"]]
            elif entity:
                pool = [t.replace("{topic}", entity) for t in bank["topic"]]
            else:
                pool = list(bank["fallback"])
            return pick(self._filter_redundant_questions(pool, known_slots) or pool)

        bank = self.next_steps_statement
        if event:
            pool = [t.replace("{event}", event) for t in bank["event"]]
        elif entity:
            pool = [t.replace("{topic}", entity) for t in bank["topic"]]
        else:
            pool = list(bank["fallback"])
        return _cap(pick_stmt(pool))

    def _label_reframe(self, focus_clause: Optional[str], pick) -> Optional[str]:
        """Returns a reflective observation when `focus_clause` is a
        diagnostic/clinical label rather than a concrete topic noun, else
        None so the caller falls back to its normal {topic}-templated
        phrasing. See label_reframe_observations above."""
        fc = (focus_clause or "").lower()
        for label, lines in self.label_reframe_observations.items():
            if label in fc:
                return pick(lines)
        return None

    def _get_safe_reflections(self, entity: Optional[str]) -> List[str]:
        """Add unsafe phrase detection: block templates containing 'particularly with how'
        when topic labels represent people."""
        pool = list(self.reflections["general"])
        if not entity:
            return pool
        PERSON_TOPICS = {"girlfriend", "boyfriend", "father", "mother", "friend", "lecturer"}
        entity_lower = entity.lower()
        if any(p in entity_lower for p in PERSON_TOPICS):
            return [r for r in pool if "particularly with how" not in r]
        return pool

    def _event_observation_line(self, event_category, event, repetition_cue, pick, pick_diverse=None, has_evidence=False):
        """Resolve the event-acknowledgment line for encouragement/validation,
        preferring category-specific phrasing (e.g. the technical "trial and
        error" framing) over the generic recurring-failure/observations_event banks."""
        pick_stmt = pick_diverse or pick
        cat = self.category_content.get(event_category) if event_category else None
        if cat:
            bank = self._category_bank(cat, "observation", event_category, has_evidence)
            if bank:
                return _cap(pick_stmt(bank))
        bank = self.observations_event_recurring if repetition_cue else self.observations_event["general"]
        return _cap(pick_stmt(bank).replace("{event}", event))

    def _dead_end_bridge(self, event, entity, emotion_intent, pick, topic_label="general"):
        """Last-resort conversational momentum: called only when a response
        would otherwise be bare validation/encouragement with no question and
        no reflective insight already attached -- the exact dead end where a
        user is left with nothing to say next. Picks, in order: an interpretive
        observation (if we know the entity/event), explicit conversation paths
        (if the user seems stuck and an entity is known), or a gentle,
        non-interrogating invitation."""
        if event:
            return _cap(pick(self.observations_event["general"]).replace("{event}", event))
        if entity:
            if emotion_intent in self.STUCK_INTENTS:
                return pick(self.conversation_paths["general"]).replace("{topic}", entity)
            reframed = self._label_reframe(entity, pick)
            if reframed:
                return _cap(reframed)
            if topic_label in ["relationship_loss", "grief"]:
                return _cap(pick(self.observations["fallback"]))
            return _cap(pick(self.observations["general"]).replace("{topic}", entity).replace("{Topic}", _cap(entity)))
        if emotion_intent in self.STUCK_INTENTS:
            return pick(self.conversation_paths["fallback"])
        return pick(self.light_curiosity)

    def generate_response(
        self,
        emotion_intent: str,
        topic_entity: Optional[str],
        stage: str,
        strategy: Optional[str] = None,
        topic: str = "general",
        meaning_shift: Optional[str] = None,
        event_category: Optional[str] = None,
        topic_label: Optional[str] = None,
        action_options: Optional[List[str]] = None,
        event_phrase: Optional[str] = None,
        repetition_cue: bool = False,
        progress_detail: Optional[str] = None,
        choice_options: Optional[Tuple[str, str]] = None,
        has_evidence: bool = False,
        has_emotional_evidence: bool = False,
        new_info: bool = False,
        new_entity_this_turn: bool = False,
        attention_shift: Optional[Tuple[str, str]] = None,
        recent_phrases: Optional[List[str]] = None,
        recent_categories: Optional[List[str]] = None,
        ask_question: bool = True,
        expected_answer_type: Optional[str] = None,
        known_slots: frozenset = frozenset(),
        workload_incomplete: bool = False,
    ) -> Tuple[str, List[str], List[str]]:
        """Compose a response whose *content shape* is driven by stage, not just
        surface intent. This enables the bot to push through an anxious frame
        to deliver concrete steps during problem-solving, or acknowledge relief
        before returning to a heavy topic.
        """
        if strategy and topic:
            topic_pool = self.TOPIC_TEMPLATES.get(topic, {})
            if strategy in topic_pool:
                # Direct topic-isolated strategy override
                return random.choice(topic_pool[strategy]), [], []

        # meaning_shift (e.g. "acceptance") and emotion_intent=="answer_previous_question"
        # both override the feeling-acknowledgment part regardless of stage, so the
        # bot reacts to what just changed/was just answered instead of repeating
        # the previous emotion's framing or pivoting away from it generically.
        #
        # event_category (technical/deadline/supervisor_feedback/relationship/family/
        # academic) lets situation-specific phrasing outrank generic academic-stress
        # templates when a more specific signal is available.
        # Returns (response_text, phrases_used, categories_used) -- caller should
        # fold both into its own tracker memory for anti-repetition across turns.
        recent_phrases = list(recent_phrases or [])
        recent_categories = list(recent_categories or [])
        used: List[str] = []
        used_categories: List[str] = []
        entity = topic_entity if topic_entity and topic_entity != "this" else None
        event = None
        if event_phrase:
            event = event_phrase + (" again" if repetition_cue else "")

        def pick(options: List[str]) -> str:
            choice = self._pick_fresh(options, recent_phrases + used)
            used.append(choice)
            return choice

        def pick_diverse(options: List[str]) -> str:
            choice, category = self._pick_diverse(
                options, recent_phrases + used, recent_categories + used_categories
            )
            used.append(choice)
            used_categories.append(category)
            return choice

        parts: List[str] = []

        if emotion_intent == "request_clarification":
            # Explain the previous turn in simpler terms using only context
            # already known -- no new observation, no question advancing the
            # topic, just a plainer restatement of the SAME underlying question.
            parts.append(pick(self.clarification_intros))
            if progress_detail:
                # Reflection Rewriter applies here too: paraphrase, don't quote
                # the user's sentence back. The ask is concrete (named example
                # milestones) rather than abstractly asking "what would help".
                parts.append(pick(self.progress_summaries))
                parts.append(pick(self.clarification_ask_progress_concrete))
            elif event:
                parts.append(f"I'm asking about having to {event}.")
                parts.append(pick(self.clarification_ask_event))
            elif entity:
                parts.append(f"I'm asking about {entity}.")
                parts.append(pick(self.clarification_ask_entity))
            else:
                parts.append(pick(self.clarification_fallback))

        elif attention_shift:
            # Attention Lock System: the user just introduced a more specific
            # topic than whatever domain was previously active -- name the
            # pivot explicitly instead of silently continuing as if nothing
            # changed (or worse, still reflecting the OLD domain). Deliberately
            # no question here; the new domain gets explored starting next turn.
            previous_label, new_label = attention_shift
            template = pick(self.attention_shift_templates)
            parts.append(template.format(previous=previous_label, new=new_label))

        elif meaning_shift in self.MEANING_SHIFT_BANKS:
            # The user's latest message carries a DIFFERENT meaning than whatever
            # situation was previously being discussed (acceptance/hopelessness/
            # relief/confidence/progress) -- this takes priority over repeating
            # the previous situational observation, regardless of stage.
            bank = getattr(self, self.MEANING_SHIFT_BANKS[meaning_shift])
            line = pick_diverse(bank)
            has_insight = True
            if meaning_shift == "progress" and progress_detail:
                # Reflection Rewriter: paraphrase, don't quote the user's own
                # sentence back -- echoing raw text reads as parroting.
                summary = pick(self.progress_summaries)
                parts.append(f"{summary} {_cap(line)}.")
                # Restating + affirming progress isn't interpretive insight on its
                # own -- without a question or path, "that's progress" is exactly
                # the kind of acknowledgment-only dead end this layer exists to catch.
                has_insight = False
            elif event:
                template = pick(self.reflections_event["general"])
                parts.append(f"{line}, {template.replace('{event}', event)}")
            elif entity:
                if topic_label in ["relationship_loss", "grief"]:
                    parts.append(f"{line}.")
                else:
                    template = pick(self._get_safe_reflections(entity))
                    parts.append(f"{line}, {template.replace('{topic}', entity)}")
            else:
                parts.append(f"{line}.")
                has_insight = False
            if ask_question:
                followup_bank = self.progress_followup if meaning_shift == "progress" else self.light_curiosity
                parts.append(pick(followup_bank))
            elif not has_insight:
                # Bare validation with no question and nothing to connect it to
                # -- the exact dead end where the user has nothing to say next.
                # progress gets its own contextual bridge (light_curiosity's
                # distress-exploration framing doesn't fit a progress update).
                if meaning_shift == "progress":
                    parts.append(pick(self.progress_followup))
                else:
                    parts.append(self._dead_end_bridge(event, entity, emotion_intent, pick, topic_label))

        elif emotion_intent == "confirmed_both" and choice_options and choice_options[0] and choice_options[1]:
            # "Workload or time pressure?" -> "Both." -- acknowledge BOTH named
            # things at once instead of guessing which single one was meant.
            option_a, option_b = choice_options
            template = pick(self.confirmed_both_templates)
            parts.append(template.replace("{option_a}", option_a).replace("{option_b}", option_b))
            if ask_question:
                parts.append(pick(self.light_curiosity))

        elif emotion_intent in ("confirmed_both", "confirmed_observation"):
            # Either "both" with no stored options to confirm both of, or a
            # plain "yes" -- continue from the now-confirmed circumstance by
            # elaborating on it (event/entity/category-aware), rather than
            # re-extracting a new topic from a contentless "yes".
            parts.append(pick(self.confirmation_openers))
            if event or entity:
                parts.append(self._event_observation_line(event_category, event, repetition_cue, pick, pick_diverse, has_evidence))
                has_insight = True
            else:
                has_insight = False
            if ask_question:
                parts.append(pick(self.light_curiosity))
            elif not has_insight:
                parts.append(self._dead_end_bridge(event, entity, emotion_intent, pick, topic_label))

        elif emotion_intent == "denied_observation":
            # The user rejected the bot's assumption -- acknowledge the
            # correction and invite them to name what's actually going on,
            # instead of repeating the now-rejected framing. A bare
            # acknowledgment with nothing else is exactly the dead end this
            # layer exists to avoid, so the clarifying follow-up always runs
            # here regardless of the ask_question roll.
            parts.append(pick(self.correction_acknowledgements))
            parts.append(pick(self.clarify_after_denial))

        elif emotion_intent == "partial_confirmation":
            parts.append(pick(self.partial_acknowledgements))
            parts.append(pick(self.clarify_after_partial))

        elif emotion_intent == "checking_ex_behavior":
            parts.append(pick([
                "Part of you still seems connected to them, and checking their social media might be one way of holding onto that connection."
            ]))
            if ask_question:
                parts.append(pick([
                    "What usually goes through your mind afterward?"
                ]))

        elif emotion_intent == "answer_previous_question":
            # Typed Pending Questions: the bot's own last question was
            # classified by what KIND of answer it was fishing for (see
            # AdvancedNLUPipeline.expected_answer_type) -- a duration/
            # quantity/issue/project_name answer is interpreted as THAT kind
            # of value, never run through the generic {topic}/{event}
            # acknowledgment below. "one week" answering "how much time has
            # X been taking up?" is a timespan, not a new topic -- it must
            # never produce "One week has been keeping you busy lately."
            if entity and expected_answer_type in (None, "project_name"):
                # The user just named which thing to focus on first --
                # whether or not the prior question explicitly fished for
                # "which one" (expected_answer_type=="project_name"), or was
                # just a generic open question that happened to get a named
                # topic back (expected_answer_type is None) -- acknowledge it
                # as the chosen priority and go straight to what's blocking
                # them on THAT thing, never back to a generic time/attention
                # question (that would re-ask "how much time has X been
                # taking up" right after the user named X as the priority,
                # discarding their own answer).
                parts.append(pick(self.priority_choice_acks).replace("{entity}", entity))
                if ask_question:
                    parts.append(pick(self.priority_choice_followup))
                else:
                    # No question this turn (pacing throttle) -- still leave the
                    # user with something to react to instead of a bare,
                    # conversation-ending acknowledgment (the same dead-end this
                    # layer exists to avoid elsewhere). Force the ENTITY path
                    # (pass event=None) rather than the stale `event` from
                    # whatever was discussed before the user just named this
                    # priority -- _dead_end_bridge prefers event over entity,
                    # which would otherwise resurrect the old, now-superseded
                    # topic (e.g. "having to deal with three assignments due
                    # this week") right after the user said "my fyp".
                    parts.append(self._dead_end_bridge(None, entity, emotion_intent, pick, topic_label))
            else:
                # entity takes priority over event here (unlike other branches):
                # a short answer is typically naming a THING ("my core tech"), and
                # using it keeps the ack fresh instead of falling back to a stale
                # event phrase inferred from an earlier message.
                # follow_event is suppressed when entity was used for the ack, so the
                # follow-up references the SAME thing instead of a mismatched stale event.
                if expected_answer_type == "duration":
                    ack = pick(self.duration_answer_acks)
                    follow_event = event
                elif expected_answer_type == "quantity":
                    ack = pick(self.quantity_answer_acks)
                    follow_event = event
                elif expected_answer_type == "issue":
                    ack = self._issue_answer_line(entity, event, pick)
                    follow_event = None if entity else event
                elif entity:
                    ack = pick(self.answer_ack["general"]).replace("{topic}", entity)
                    follow_event = None
                elif event:
                    ack = pick(self.answer_ack["event"]).replace("{event}", event)
                    follow_event = event
                else:
                    ack = pick(self.answer_ack["fallback"])
                    follow_event = None
                parts.append(ack)
                if expected_answer_type == "issue":
                    # A named blocker ("backend problems") is already
                    # substantive content, not a bare topic mention -- dig
                    # into it the same way real distress content would be
                    # explored, rather than retreating to the neutral "how
                    # much time has X been taking up" framing, which would
                    # just re-ask what the user already told us.
                    if stage == "problem_solving":
                        parts.append(self._problem_solving_line(event_category, follow_event, entity, ask_question, pick, pick_diverse, has_evidence, known_slots))
                    else:
                        parts.append(self._investigate_line(event_category, follow_event, entity, action_options, ask_question, pick, pick_diverse, has_evidence, repetition_cue, known_slots))
                elif not has_emotional_evidence:
                    # Assumption Safety Layer (emotional): the user has only named
                    # a topic so far ("I'm doing my FYP") -- topic mention is NOT
                    # an emotional disclosure, so stay strictly in attention/
                    # focus/time-occupied territory regardless of stage. Once the
                    # user actually expresses distress/emotion (has_emotional_
                    # evidence flips True), the branches below apply instead.
                    parts.append(self._answer_neutral_followup(follow_event, entity, ask_question, pick))
                elif stage == "problem_solving":
                    parts.append(self._problem_solving_line(event_category, follow_event, entity, ask_question, pick, pick_diverse, has_evidence, known_slots))
                else:
                    parts.append(self._investigate_line(event_category, follow_event, entity, action_options, ask_question, pick, pick_diverse, has_evidence, repetition_cue, known_slots))

        elif (
            new_info and (event or entity) and event_category in self.SPECIFIC_CATEGORIES
            and stage != "validation"
        ):
            # Conversation Commitment Layer: the user just gave fresh, specific
            # information (a new entity/event was just extracted this turn) --
            # prioritize building on THAT over whatever the stage machinery
            # would have generated on its own, so the bot visibly continues
            # from the answer instead of reverting to an older topic/category.
            # Excludes "validation": on a cold open / right after a topic reset
            # there's no older topic to avoid reverting to, so the normal
            # validation-stage acknowledgment is more appropriate.
            # event is a verb phrase ("have problems") -- "having to {event}"
            # keeps it grammatical as a clause; entity is already a noun phrase.
            # Prefer whichever was actually FRESH this turn -- event is a
            # persisted field that can be stale (e.g. an old "10 modules to
            # go" from several turns back) while entity just changed; a stale
            # event must never outrank a fresh entity just because it's non-None.
            if entity and (new_entity_this_turn or not event):
                focus_clause = entity
            elif event:
                focus_clause = f"having to {event}"
            else:
                focus_clause = entity
            reframed = self._label_reframe(focus_clause, pick)
            if reframed:
                parts.append(reframed)
            else:
                # This branch fires every time a fresh entity/event shows up
                # in a SPECIFIC_CATEGORIES turn -- a single hardcoded f-string
                # here ("It sounds like {clause} is carrying most of the
                # weight right now.") meant that exact sentence (just the
                # noun swapped in) repeated verbatim turn after turn whenever
                # the conversation stayed in deadline/technical/etc. content,
                # which is exactly the "feels robotic/repetitive" complaint --
                # pick from the same varied bank _dead_end_bridge already uses
                # for this kind of reflective opener instead of one fixed line.
                GENERIC_PRONOUNS = ["everyone", "everything", "someone", "nobody", "it", "this", "all of this", "them", "that"]
                is_generic = focus_clause and focus_clause.lower() in GENERIC_PRONOUNS
                bank = self.observations["general"] if (focus_clause and not is_generic) else self.observations["fallback"]
                line = pick(bank)
                parts.append(_cap(line.replace("{topic}", focus_clause).replace("{Topic}", _cap(focus_clause))) if (focus_clause and not is_generic) else line)
            if workload_incomplete and entity:
                # Multi-Event Fusion: the user disclosed a deadline-flavored
                # event (presentation/exam/deadline) AND that the work itself
                # isn't ready, in the same breath -- naming only one half
                # (just "your FYP presentation sounds heavy") and then asking
                # a generic deadline question ignores the other half of what
                # was actually said. A fused line acknowledges both at once
                # instead of picking one category's generic observation bank.
                fused = pick(self.deadline_workload_fusion_observations).replace("{event}", entity)
                parts.append(_cap(fused))
            else:
                parts.append(self._event_observation_line(event_category, event, repetition_cue, pick, pick_diverse, has_evidence))
            if ask_question:
                parts.append(self._investigate_line(event_category, event, entity, action_options, True, pick, pick_diverse, has_evidence, repetition_cue, known_slots))

        elif stage == "reflection":
            if progress_detail:
                # Reflection Rewriter: paraphrase the progress, don't quote the
                # user's sentence back via a {progress_detail} placeholder.
                line = pick_diverse(self.progress_summaries)
            elif event:
                line = pick_diverse(self.reflection_summary["event"]).replace("{event}", event)
            elif entity:
                line = self._label_reframe(entity, pick) or pick_diverse(self.reflection_summary["general"]).replace("{topic}", entity)
            else:
                line = pick_diverse(self.reflection_summary["fallback"])
            parts.append(_cap(line))
            if ask_question:
                parts.append(pick(self.reflection_followup))

        elif stage == "exploration":
            parts.append(self._investigate_line(event_category, event, entity, action_options, ask_question, pick, pick_diverse, has_evidence, repetition_cue, known_slots))

        elif stage == "synthesis":
            # Problem 3/4: recap, don't interrogate -- no question appended
            # here regardless of ask_question, since synthesis's whole
            # point is to summarize before moving on.
            parts.append(self._synthesis_line(event_category, event, entity, pick))

        elif stage == "encouragement":
            parts.append(pick(self.encouragements))
            has_insight = False
            if event:
                parts.append(self._event_observation_line(event_category, event, repetition_cue, pick, pick_diverse, has_evidence))
                has_insight = True
            elif entity and not ask_question:
                reframed = self._label_reframe(entity, pick)
                if reframed:
                    parts.append(_cap(reframed))
                else:
                    GENERIC_PRONOUNS = ["everyone", "everything", "someone", "nobody", "it", "this", "all of this", "them", "that"]
                    is_generic = entity.lower() in GENERIC_PRONOUNS
                    if is_generic:
                        template = pick(self.observations["fallback"])
                        parts.append(_cap(template))
                    else:
                        template = pick(self.observations["general"])
                        parts.append(_cap(template.replace("{topic}", entity).replace("{Topic}", _cap(entity))))
                has_insight = True
            if ask_question:
                parts.append(pick(self.encouragement_followup))
            elif not has_insight:
                # Bare encouragement with no question and nothing else -- dead end.
                parts.append(self._dead_end_bridge(event, entity, emotion_intent, pick, topic_label))

        elif stage == "grief_processing":
            if action_options:
                parts.append(pick(action_options))
            else:
                parts.append(pick([
                    "It's completely normal to feel waves of sadness even when you thought you were doing okay.",
                    "Grief doesn't follow a straight line. Taking it one day at a time is sometimes all you can do."
                ]))
                if ask_question:
                    parts.append(pick([
                        "What's been the hardest part of letting go?",
                        "When do you notice the absence the most?"
                    ]))

        elif stage == "meaning_making":
            if action_options:
                parts.append(pick(action_options))
            else:
                parts.append(pick([
                    "It makes sense to feel conflicted—you can miss someone deeply and still know it wasn't right.",
                    "Holding two opposing feelings at the same time is really exhausting, but it's a normal part of processing this.",
                    "It sounds like part of you misses them, while another part recognizes the relationship wasn't healthy. Holding both of those feelings at the same time can be really confusing."
                ]))
                if ask_question:
                    parts.append(pick([
                        "Which feeling feels the heaviest right now?",
                        "What is it like to sit with both of those emotions today?"
                    ]))

        elif stage == "meaning_making":
            if action_options:
                parts.append(pick(action_options))
            else:
                parts.append(pick([
                    "Sometimes stepping back helps us see what the experience taught us, even if it was painful.",
                    "Finding meaning in what happened doesn't erase the hurt, but it can make it easier to carry."
                ]))
                if ask_question:
                    parts.append(pick([
                        "What do you think you've learned about yourself through all of this?",
                        "How has this experience changed what you're looking for going forward?"
                    ]))

        elif stage == "acceptance":
            if action_options:
                parts.append(pick(action_options))
            else:
                parts.append(pick(self.acceptance_validations))
                if ask_question:
                    parts.append(pick([
                        "How does it feel to be at this point now?",
                        "What's the next small step you want to take for yourself?"
                    ]))

        elif stage == "closure":
            if action_options:
                parts.append(pick(action_options))
            else:
                parts.append(pick([
                    "It takes a lot of strength to reach a point of peace with this.",
                    "Moving forward doesn't mean forgetting, just that it doesn't hurt as much anymore."
                ]))
                if ask_question:
                    parts.append(pick([
                        "What are you looking forward to next?",
                        "How are you going to take care of yourself today?"
                    ]))

        elif stage == "problem_solving":
            # action_options (e.g. academic_explore_strategy's own bank) is an
            # EXPLORATION question bank, not problem-solving content -- using it
            # here was why "stage=problem_solving" still produced generic
            # "what kind of issue" exploration questions instead of real
            # blocker/breakdown/prioritization content.
            parts.append(self._problem_solving_line(event_category, event, entity, ask_question, pick, pick_diverse, has_evidence, known_slots))

        else:  # validation (default/fallback stage)
            group = self._map_emotion_to_group(emotion_intent, topic_label, event_category)
            validation = pick_diverse(self.validations.get(group, self.validations["general"]))
            has_insight = True
            if event and repetition_cue:
                # recurring-failure framing is a full standalone sentence -- its own
                # part, not comma-joined onto the validation line.
                parts.append(f"{validation}.")
                parts.append(self._event_observation_line(event_category, event, repetition_cue, pick, pick_diverse, has_evidence))
            elif event:
                template = pick(self.reflections_event["general"])
                parts.append(f"{validation}, {template.replace('{event}', event)}")
            elif entity:
                if topic_label in ["relationship_loss", "grief"] or group in ["relationship_loss", "grief"]:
                    parts.append(f"{validation}.")
                else:
                    template = pick(self._get_safe_reflections(entity))
                    parts.append(f"{validation}, {template.replace('{topic}', entity)}")
            else:
                parts.append(f"{validation}.")
                has_insight = False
            if ask_question:
                parts.append(pick(self.light_curiosity))
            elif not has_insight:
                # Bare validation, no question, nothing to connect it to -- this
                # is the exact "I'm sad." -> "That sounds really heavy." dead end.
                parts.append(self._dead_end_bridge(event, entity, emotion_intent, pick, topic_label))

        response = " ".join(p.strip() for p in parts if p)
        return _cap(response), used, used_categories


# Quick test
if __name__ == "__main__":
    nlg = ComponentNLGEngine()
    print(nlg.generate_response("sadness_support", None, "validation", ask_question=True))
    print(nlg.generate_response("coding_pressure", "your backend", "exploration", ask_question=True))
    print(nlg.generate_response("coding_pressure", "your backend", "reflection", event_phrase="build your backend", ask_question=False))
    print(nlg.generate_response("coding_pressure", "your backend", "exploration", meaning_shift="acceptance", event_phrase="build your backend", ask_question=False))
