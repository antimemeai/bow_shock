# Extract and organize a live page visit

Operator clarification, 2026-10-16. The motivating example is a complex profile:
ordinary offline HTML retains little of what a person can explore through nested
scroll regions, collapsed sections and dynamically loaded content. Oxcart's
primary value is extracting and organizing the information encountered through
that live visit. General Blackbird-driven navigation is advanced work.

## Current implementation and gap

The visible native CEF browser loads live sites. A requested reading saves the
complete DOMSnapshot dataset returned by its current target, plus full derived
text/index files and large-string blobs. Blackbird receives the file locator and
can inspect it using ordinary tools. This is one state, not the whole visit.
There is no visit accumulator, continuous collection, semantic result workspace,
or browser-input executor in the active target. Existing capture limitations
include images/network bodies and separately attached out-of-process targets.

## Next product unit

Build a visit collection that links successive immutable reading archives to
the browser visit and exposes them together to extraction. Keep full readings;
derive incremental indexes rather than rewriting old observations. Document
replacement, navigation and recycled node IDs must not merge unrelated sources.
Retain observed content after it disappears from the current DOM.

Collection must follow the live visit as the person scrolls and expands content.
Study the actual native change/capture callbacks before choosing the trigger
mechanism. Repeated expensive full snapshots and snapshots only after scrolling
stops have different loss/cost risks. Record collection gaps and in-progress or
failed captures; never claim that a later snapshot recovered already-lost content.

Give extraction the visit's collected readings and let the agent organize their
information into a useful result. It may combine fragments into records, group
topics, normalize dates, deduplicate repeated observations and summarize. Output
shape follows the information and task; it is not a DOM mirror or a selector-only
table. Store source references for extracted claims, separate source wording from
normalization or inference, and retain conflicting observations when identity is
uncertain. Reused DOM nodes and equal text alone are not durable entity IDs.

Show the growing result beside the browser, with access to supporting readings
and clear collection progress/gaps. Persist results and source links using owned
native/binary formats and existing machinery. No dependency selection is implied
by this direction.

## Exploration in service of extraction

Human scrolling/expansion can establish the first useful end-to-end collection.
Then add page-local exploration where it is needed: scroll the relevant nested
region, expand a post or section, and observe newly available content. That work
uses the separate native OS executor, current-target checks, Stop and human
takeover; none of those capabilities exists merely because a model can name a
node. This is narrower than autonomous browsing across destinations.

Distinguish all captured bytes from all available information: each requested
reading preserves everything harvested, while visit coverage identifies states
observed, sections not opened, unavailable content and interrupted collection.
An infinite or changing feed does not acquire a claim of completeness merely
because collection temporarily stops producing new records.

## Direct live check

Use a real page with dynamic scrolling and expansion. During one visit, expose
content across successive states, including content removed from the live DOM.
Inspect the resulting organized collection: earlier content survives; repeats
do not multiply records; distinct equal-looking items are not silently lost;
each factual result leads back to its source; interpretation is identifiable;
unopened regions and capture failures remain visible. Exercise actual nested
scrolling and virtualization where the chosen page has them. Fix actual failures
without introducing owned-page progression or certification gates.

The current Wikipedia file-reading run remains a separate unfinished check of
the single-reading implementation. Its macOS Keychain prompt is not a product
milestone for this visit-extraction work.
