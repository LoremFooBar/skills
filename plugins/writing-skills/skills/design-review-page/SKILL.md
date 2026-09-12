---
name: design-review-page
description: Write or rewrite a design review page (Notion or markdown) and its opening slide deck for a time-boxed meeting, usually 30 minutes. Use when asked to "prepare a design review", "write the review page", "rewrite this design page for the meeting", "make a deck for the design review", or when an existing design page is too long for participants to read before the meeting. Produces a main page readable in about 5 minutes with 2 or 3 decisions and a stated recommendation, detail subpages, and an 8-slide artifact. Applies the state-not-history writing rules.
---

# design-review-page

A design review meeting decides a small number of things. The page exists so
the room can decide them. Everything that does not help the room decide goes
one level down.

## Step 1: get the three inputs

Ask with one AskUserQuestion call unless the user already gave them:

1. **Who is in the room.** Platform team only, infra, security or compliance,
   wider engineering. This sets how much context each section needs and
   which costs to name.
2. **Which decisions get meeting time.** Offer the candidates you see in the
   source material, recommend at most three, and say the rest become
   subpages with a one-line mention.
3. **Recommendation or neutral choice.** For each decision, does the author
   want the page to state their position and ask the room to agree or object,
   or to lay out the options and ask the room to pick. Default to a stated
   recommendation; a review reacts to a position better than to a survey.

Do not ask about anything else. Meeting length defaults to 30 minutes.

## Step 2: sort the source material

Read everything the author has (existing page, decision log, plans, spike
results). Put each fact in one of four buckets:

| Bucket | Goes to |
| --- | --- |
| Needed to make one of the chosen decisions | Main page, in that decision's section |
| Settled, must not be re-opened | Main page, one paragraph, no dates |
| Detail that supports a decision but is not needed to make it | A subpage, linked from the decision |
| Mechanics that copy an existing pattern, measurements, history, terms | A subpage, linked at the end |

If a piece of detail "would make or break the project" or "would benefit from
the room's feedback", it belongs on the main page. Otherwise it does not.

## Step 3: create the subpages first

Create the subpages before writing the main page, so the main page can link
to them. Typical set, four to six pages:

- Evidence for the main trade-off (spike results, what was tried, what would
  change the answer).
- The verification story (gates, checks, acceptance test).
- Infrastructure and process that follow an existing pattern.
- Parameters and sizing.
- Decision log, terms, measured table, not-tested list, delivery table,
  sources.

Move content into subpages without loss. Nothing the previous version said is
deleted; it is relocated. In Notion, create them as children of the main page
(`notion-create-pages` with the main page as parent), then include a `<page>`
tag for each when replacing the main page's content, or the replace fails.

## Step 4: write the main page

Target: about 5 minutes of reading. Eight sections, in this order:

1. **Header.** Owner, ticket, meeting length. A callout linking the deck and
   saying which sections the review acts on.
2. **The goal.** Three sentences. Then the two or three rules the design never
   breaks.
3. **The design in one picture.** One diagram. The stages in one line each
   with a status word. One line on what is out of scope.
4. **What we ask the review to decide.** The chosen decisions, numbered, each
   pointing at its section. Then requests to other teams that need only an
   owner and a date. Then one line on what is not asked.
5. **One section per decision.** A callout with the recommendation. Why, as
   bullets. The cost, stated plainly. What would change the answer. The last
   line is always `**Asked of the review:** ...`.
6. **Where we stand.** Two columns: measured, not yet done. Five bullets each.
7. **Settled, please do not re-open.** One paragraph. Names with the decision
   ID in parentheses. Dates and wording live in the decision log subpage.
8. **Detail pages.** The subpage links, and the path to the working files.

Apply `state-not-history` throughout: no change log at the top, no decision
IDs as headings, no per-sentence status labels, numbers only where they change
a decision, plain words.

## Step 5: build the deck

An artifact with about 8 slides, vertical scroll-snap with arrow-key
navigation, readable at meeting distance, both themes. Slides:

1. Title, agenda with minutes (5 / 10 / 10 / 5 for a 30-minute meeting),
   owner, ticket, link to the page.
2. Why: what is wrong today, what the goal is, scope in one line.
3. The design in one picture. Colour raw data and safe data differently.
4. The stages with status pills.
5. One slide per decision: recommendation as the headline, why, what was
   tried, the cost, the ask.
6. Where we stand: measured versus not yet done.
7. Requests to other teams: each needs an owner and a date. The first
   milestone that depends on nothing. Link back to the page.

Every claim on a slide must also be on the page or a subpage. The deck adds
no new facts.

## Step 6: link both ways and hand over

- Put the deck link in the page header callout and the page link on the
  deck's first and last slides.
- The Artifact tool cannot set sharing. Tell the author to set the deck's
  sharing to the organization from its share menu.
- Also update the author's working files (decision log, plans) if the rewrite
  changed how a decision is framed.

## Before publishing

1. First screen of the page: a reader who was not there can say what is
   proposed, what it costs, and what is asked of them.
2. Every decision section ends with an "Asked of the review" line.
3. No sentence on the page describes how the page changed.
4. Each subpage has the content that left the main page, complete.
5. Reading time of the main page is about 5 minutes; the deck about 5 minutes
   to present.

## Reply to the author

Lead with the two things they must do: set the deck's sharing, and read the
"Asked of the review" lines. Then, in five bullets or fewer: what the main
page now holds, what moved where, and anything you inferred that the source
material did not state, so they can correct it.
