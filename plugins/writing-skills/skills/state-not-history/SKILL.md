---
name: state-not-history
description: Write prose for a reader who arrives now and was not there while the work happened. Use for ANY text meant for other people - design docs, Notion pages, PR descriptions, RFCs, Slack updates, status reports, tickets - and whenever asked to "rewrite this so people can follow it", "make this readable", "this is too long", "shorten this doc", or when a document you are about to publish has grown out of a multi-day working session. Turns a running log of proposals, measurements, corrections and cross-references into a page that states the current position, the cost, and the ask.
---

# state-not-history

The reader arrives now. They were not there while you thought. Write what is
true now, for them. Put the story of how you got there somewhere else.

## Why working documents become unreadable

Someone who works on a problem for days writes each step down as it happens.
The document turns into a log: proposed, measured, softened, retracted,
amended, moved to section 5.1. Every sentence carries its date, its source
file and its confidence label. Every section points at other sections. The
result is complete, honest, and impossible to read, because the reader has to
replay the whole history to learn the present state.

Signs that a document has become a log:

- The first paragraph says what changed since the last version.
- Headings are identifiers (D23, IA5, RA4) instead of names.
- Sentences contain "softened", "retracted", "withdrawn", "amended", "an
  earlier version claimed".
- The same idea appears three times because it was written on three days.
- The reader is sent elsewhere mid-sentence: "see 5.1 and 6.5".
- The ask sits in the last section.

## Rules

1. **State, do not narrate.** Write the current position as a fact. What was
   proposed before, what changed, and when, go to a log or an appendix.
   Banned in the body: "updated", "softened", "amended", "retracted",
   "withdrawn", "moved to section", "an earlier version".
2. **Position before evidence.** Say what you recommend, then why, then what
   it costs. Do not lay out evidence and leave the reader to conclude. If you
   have no position, say so in one sentence and ask a specific question.
3. **The ask on the first screen.** If the document wants something from the
   reader (a decision, a review, an owner), say so before anything else, and
   repeat it at the section where it applies.
4. **One level of detail per page.** Decide what the page is for. Everything
   at that level stays. Everything below it moves to a subpage or an appendix,
   replaced by one sentence and a link. Anything that follows an existing
   pattern ("works like backups do today") gets one sentence.
5. **Names, not codes.** Call things what they are: "the shared database",
   "the acceptance test". An identifier may appear once, in parentheses, so a
   reader can find it in the log.
6. **Provenance at the end.** The body says "a copy runs at about 45 MB/s".
   The script name, the date, the role used and the monitoring window go in a
   sources section or a subpage.
7. **Status once, not per sentence.** One "measured" list and one "not yet
   done" list. Do not label every sentence measured / proposed / from reading.
8. **Each section stands alone.** No cross-references as structure. If two
   sections need each other, merge them, or move one to a subpage.
9. **Numbers only where they change a decision.** Otherwise words: "about a
   minute", "most of the database", "four times larger than assumed".
10. **Plain words for a reader whose first language is not English.** Short
    sentences. No idioms, no metaphors, no clever headings. When a simpler
    word exists, use it. Prefer the vocabulary of ASD-STE100 Simplified
    Technical English.
11. **Do not write defensively.** "Please do not re-open", "not asked of this
    review", and repeated corrections of your own earlier claims protect the
    writer, not the reader. List what is settled once, plainly, and move on.

## Where the history goes

The history is valuable. Keep it in a decisions file, a log file, a
"measurements" subpage, or a collapsed appendix. Link to it once, at the end.
Never delete it, never inline it.

## The test before publishing

1. Read only the first screen. Can a reader who was not there say in one
   sentence what is proposed, what it costs, and what you want from them? If
   not, rewrite the first screen.
2. Search the body for the banned words in rule 1 and for identifiers used as
   names. Fix each one.
3. Delete every sentence about how the document came to be.
4. Read each heading alone. Does the list of headings tell the story? If a
   heading is a code or a date, rename it.

## Relation to other skills

- `design-review-page` applies these rules to one document type: a page and
  a deck for a time-boxed design review meeting.
- `i-have-adhd` shapes chat replies. This skill shapes documents. Both agree:
  lead with the action or the position, one idea per sentence, no preamble.
