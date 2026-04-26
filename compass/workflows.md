---
tags: [rails, 37signals, workflows, commands, undo]
---

# Workflows

> Event-driven state, undoable commands, custom Turbo actions.

See also: [[models]], [[hotwire]], [[filtering]]

---

## Event-Driven State
Store transitions as events with metadata, not just update fields.

## After-Commit for Defaults
```ruby
after_create_commit :create_default_stages
def create_default_stages
  Workflow::Stage.insert_all DEFAULT_STAGES.collect { |name| { workflow_id: id, name: name } }
end
```

## Undoable Command Pattern
```ruby
class Command::Stage < Command
  store_accessor :data, :stage_id, :original_stage_ids_by_card_id
  def execute
    transaction do
      cards.find_each do |card|
        original_stage_ids_by_card_id[card.id] = card.stage_id
        card.change_stage_to stage
      end
      update! original_stage_ids_by_card_id: original_stage_ids_by_card_id
    end
  end
  def undo
    transaction do
      original_stage_ids_by_card_id.each do |card_id, stage_id|
        card = affected_cards[card_id.to_i]
        card&.change_stage_to stages_by_id[stage_id.to_i]
      end
    end
  end
end
```

## Custom Turbo Stream Actions
```javascript
Turbo.StreamActions.set_css_variable = function() {
  this.targetElements.forEach(el =>
    el.style.setProperty(this.getAttribute("name"), this.getAttribute("value"))
  )
}
```

## Computed State from Associations
```ruby
def color
  color_from_stage || Colorable::DEFAULT_COLOR
end
```
Derive state, don't store redundantly.

## Cascading Changes
```ruby
after_save :update_bubbles_workflow, if: :saved_change_to_workflow_id?
def update_bubbles_workflow
  bubbles.update_all(stage_id: workflow&.stages&.first&.id)
end
```
