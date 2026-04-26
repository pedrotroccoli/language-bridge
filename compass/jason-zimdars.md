---
tags:
  - compass
  - design
  - ux
  - css
  - product
see-also:
  - "[[css]]"
  - "[[philosophy]]"
  - "[[views]]"
---

# Jason Zimdars' Design & Product Patterns

> This document was AI-compiled from Jason Zimdars' (JZ) pull request comments, design decisions, and code review feedback across multiple PRs. Patterns were extracted and organized to serve as a reference for product and design thinking.

## UX-First Decision Making

### Perceived Performance > Technical Performance (PR #131)

Jason consistently prioritizes how interactions *feel* over how they technically perform. In PR #131, reviewing a filtering UI, he noted:

> "The filtering UI feels slow — like one of those shopping websites where you click a filter and the whole page reloads."

The takeaway is not about milliseconds or benchmarks. It is about whether the user *perceives* the interaction as responsive. A technically fast operation that visually stutters or causes layout shift will feel worse than a slightly slower operation with smooth, predictable transitions.

**Pattern:** When evaluating performance, ask "does this feel fast?" before asking "is this fast?" Optimize for perceived responsiveness — skeleton screens, optimistic updates, and smooth transitions matter more than shaving milliseconds off server response times.

### Simplify by Removing, Not Just Hiding (PR #131)

Rather than toggling visibility or layering UI states on top of each other, Jason advocates for genuinely simplifying what the user sees at any given moment:

> "We shouldn't show the filter chips while the form is open. It's just noise at that point."

This is a principle of *reducing cognitive load by subtraction*. When a user is actively editing filters in a form, showing the existing filter chips alongside the form creates redundant information. The user already knows what filters exist — they are editing them.

**Pattern:** When a new UI state opens (a modal, a form, an expanded section), actively remove the elements it supersedes rather than simply overlaying the new state. Every visible element should earn its place in the current context.

## Prototype Quality Shipping

### Explicitly Label Implementation Quality (PR #335)

Jason is transparent about the quality level of shipped code. In PR #335, he described his own implementation:

> "This is prototype quality code."

And followed it with a direct calibration for reviewers:

> "Factor your appetite accordingly."

This framing is powerful because it sets expectations without apology. It acknowledges that not all code needs to be production-hardened on the first pass, and it gives reviewers permission to focus on the *concept* rather than the *implementation details*.

**Pattern:** When shipping exploratory or early-stage work, explicitly label it. Use clear language like "prototype quality" or "proof of concept" in PR descriptions. This prevents reviewers from spending time on polish that will be revisited, and it creates a shared understanding of what "done" means at this stage.

### Ship to Validate, But Document Known Issues (PR #335)

Jason ships work that he knows has flaws — but he enumerates those flaws upfront. In PR #335, the description included a structured list of known issues and areas that need future attention.

**PR Description Template Pattern:**
- What does this PR do? (one paragraph)
- What is the quality level? (prototype / production-ready / needs-review)
- What are the known issues? (numbered list)
- What areas need future investigation? (numbered list)

**Pattern:** Shipping imperfect work is fine — expected, even — but document what you know is wrong. This turns "technical debt" from a vague concern into a trackable, addressable list. It also shows reviewers that you are aware of the gaps, which builds trust.

## Real Usage Trumps Speculation

### Prefer Production Validation Over Local Perfection (PR #335)

Jason explicitly chose to ship to production rather than continue perfecting locally. He noted the difference between synthetic and real-world conditions:

> "Performance on Digital Ocean is going to be different from what we see locally. We need to get this in front of real data."

**Decision Framework:**
1. Does the feature work correctly in the happy path? Ship it.
2. Are there known edge cases? Document them, ship anyway.
3. Is performance uncertain? Production data will answer faster than local profiling.
4. Is the UI rough? Real usage feedback will prioritize polish better than guessing.

**Pattern:** When you are uncertain about performance, usability, or edge cases, production is a better laboratory than your local machine. Ship to validate, not to perfect.

### Name Technical Debt, Don't Block on It (PR #335)

Jason identifies technical debt with specificity rather than using it as a reason to delay shipping:

> "The Bubble namespace is confusing here — it's doing too many things. But that's a refactor for another day."

He names the problem (namespace confusion), acknowledges it, and explicitly defers it. This is different from ignoring technical debt — it is cataloging it while maintaining forward momentum.

**Pattern:** When you encounter technical debt during a PR, name it specifically (what is wrong, where it lives, why it matters). Then explicitly decide: fix it now, or defer it. Never leave it unnamed — unnamed debt is invisible debt.

## Incremental Feature Addition

### Add Escape Hatches Without Removing Primary Path (PR #608)

In PR #608, Jason added a "Create and add another" flow alongside the existing "Create" flow. The implementation used a `creation_type` parameter to differentiate between the two paths:

```ruby
# Controller implementation pattern
def create
  @record = Record.new(record_params)

  if @record.save
    if params[:creation_type] == "create_and_add_another"
      redirect_to new_record_path, notice: "Created. Add another?"
    else
      redirect_to @record
    end
  else
    render :new
  end
end
```

The key insight is that the new path (`create_and_add_another`) was added *alongside* the default path, not as a replacement. The primary "Create" button still works exactly as before. The new option is an escape hatch for power users who need to create multiple records in sequence.

**Pattern:** When adding a new workflow variant, implement it as a parallel path with a distinguishing parameter. The original path should remain the default. New paths should be opt-in, never forced.

## Visual Polish Through Iteration

### Ship Visual Redesigns Big (PR #305)

PR #305 touched 95 files in a single visual redesign. Jason chose to ship the redesign as one large PR rather than breaking it into incremental visual changes.

The rationale: visual consistency matters. Shipping a redesign piecemeal creates a period where the application looks inconsistent — some screens have the new style, others have the old. This is jarring for users and creates confusion about which style is "correct" for developers working on other parts of the codebase.

**Pattern:** Visual redesigns benefit from wholesale shipping. Unlike feature work (which should be incremental), design system changes and visual overhauls should land as a single, coordinated change. The temporary inconsistency of a piecemeal rollout is worse than the review burden of a large PR.

## Feature Design Principles

### Reuse Robust Systems for New Features (PR #335)

When building new features, Jason looks for existing systems that already handle complexity well, rather than building from scratch:

> "The filter system already handles all of this — multiple conditions, persistence, URL serialization. We should use it for this new feature too."

In PR #335, he extended the existing filter infrastructure to support a new use case rather than building a parallel system. The form example followed the same principle — reusing the established form patterns rather than inventing a new approach.

**Pattern:** Before building a new system, audit existing infrastructure. If a robust system already handles 80% of what you need, extend it rather than building from scratch. This reduces maintenance burden, leverages battle-tested code, and maintains consistency for users who already understand the existing patterns.

## Feedback Style

### Give Product Context, Not Implementation Mandates (PR #131)

Jason's code review comments provide the *why* — the product reasoning — rather than dictating the *how*. His feedback often starts with phrases like:

> "I'd imagined this working more like..."

This framing is collaborative rather than directive. It shares his mental model without mandating a specific implementation. It gives the developer room to find a solution that achieves the product goal while respecting the technical constraints they understand best.

**Pattern:** When giving feedback, lead with the product intent or user experience goal. Describe what you imagined the interaction feeling like, not what code to write. Use phrases like "I'd imagined...", "The goal here is...", "Users would expect..." to frame feedback in product terms.

### Trust, Then Verify in Production (PR #335)

Jason extends trust to the implementation while setting up verification:

> "Factor your appetite accordingly."

This phrase delegates judgment to the reviewer while implicitly saying: "I trust you to make the right call about how much to invest here." It is a form of empowerment — giving others the context they need to make decisions without micromanaging the outcome.

**Pattern:** Set the context, share your assessment of quality and risk, then trust others to calibrate their response. Follow up by verifying in production rather than demanding perfection in review.

## CSS Container Query Patterns (PRs #305, #335)

Jason uses CSS container queries extensively for component-level responsive design. Rather than relying on viewport-based media queries, components respond to their own container's size.

Key patterns from the PRs:

- **Container query with `cqi` units:** Components use container query inline (cqi) units to size themselves relative to their container, not the viewport. This makes components truly portable — they adapt to wherever they are placed.

```css
.card {
  container-type: inline-size;
}

.card__title {
  font-size: clamp(1rem, 4cqi, 1.5rem);
}

@container (min-width: 300px) {
  .card__layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
}
```

- **Self-sizing cards:** Cards define their own container and respond to their own width. This eliminates the need for parent components to dictate child layout through props or classes.

**Pattern:** Use `container-type: inline-size` on wrapper elements and `cqi` units for fluid sizing within those containers. Prefer container queries over media queries for any component that might appear in different layout contexts (sidebars, modals, main content area).

## Data-Driven Development

### List Specific Investigation Areas (PR #335)

Rather than vaguely saying "we need to test this more," Jason lists specific, numbered areas of concern that need investigation:

1. Performance with large datasets (500+ records)
2. Behavior when filters return zero results
3. Interaction between new filters and saved views
4. URL serialization with special characters
5. Mobile touch interaction with filter chips

Each area is concrete enough to be assigned, tested, and resolved independently.

**Pattern:** When identifying areas that need investigation, be specific and number them. Each item should be concrete enough that someone unfamiliar with the context could pick it up and investigate. Vague concerns ("performance might be an issue") are less actionable than specific ones ("performance with 500+ records in the unfiltered state").

## Key Takeaways

1. **Perceived performance matters more than technical performance.** Optimize for how interactions feel, not just how fast they are.
2. **Label the quality level of your work explicitly.** "Prototype quality" is a valid and useful designation that sets expectations for everyone.
3. **Ship to validate, don't polish to perfection locally.** Production data answers questions faster than local testing.
4. **Name technical debt specifically.** Unnamed debt is invisible debt. Named debt is manageable debt.
5. **Add new workflows as parallel paths, not replacements.** The primary path should remain untouched; new options are escape hatches.
6. **Ship visual redesigns as a single coordinated change.** Piecemeal visual changes create inconsistency that is worse than a large PR.
7. **Reuse existing robust systems rather than building new ones.** Extend what works before inventing something new.
8. **Give product context in feedback, not implementation mandates.** Share the "why" and trust others to find the "how."

## Application to Your Projects

### PR Template Addition

Add a shipping standard checklist to your PR template:

```markdown
## Shipping Standard
- [ ] Quality level: (prototype / production-ready / needs-review)
- [ ] Known issues documented: (list or "none")
- [ ] Investigation areas identified: (numbered list or "none")
- [ ] Perceived performance checked: (feels fast? transitions smooth?)
- [ ] New UI states simplify rather than layer: (old elements removed when superseded?)
```

### Code Review Questions

When reviewing PRs, ask these five questions inspired by Jason's patterns:

1. **Does this feel fast?** Not "is this fast" — does the interaction *feel* responsive to a user? Are there optimistic updates, smooth transitions, or skeleton states?
2. **What is the quality level?** Is this prototype-quality exploration or production-ready code? Has the author labeled it?
3. **Are known issues documented?** If there are rough edges, are they enumerated? Can they be tracked independently?
4. **Does new UI simplify or layer?** When a new state appears, does it remove the elements it supersedes, or does it pile on top of them?
5. **Is this extending an existing system or inventing a new one?** If inventing, is there a good reason not to reuse what already exists?
