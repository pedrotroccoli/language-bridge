---
tags: [compass, rails, ai, llm]
see-also:
  - "[[models]]"
  - "[[controllers]]"
  - "[[security]]"
---

# AI / LLM Integration

## Command Pattern with STI (#460, #464, #466)

Commands use Single Table Inheritance for a clean execute/undo pattern:

### Base Command Class

```ruby
# app/models/command.rb
class Command < ApplicationRecord
  belongs_to :bucket
  belongs_to :creator, class_name: "User"
  belongs_to :commandable, polymorphic: true, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :undoable, -> { where(undone_at: nil) }

  def execute
    raise NotImplementedError
  end

  def undo
    return false unless undoable?
    undo!
  end

  def undo!
    raise NotImplementedError
  end

  def undoable?
    undone_at.nil?
  end

  def needs_confirmation?
    false
  end

  private

  def mark_undone!
    update!(undone_at: Time.current)
  end
end
```

### Concrete Command: Command::Assign

```ruby
# app/models/command/assign.rb
class Command::Assign < Command
  store_accessor :details, :assignee_id, :previous_assignee_id

  validates :assignee_id, presence: true

  def execute
    card = commandable
    self.previous_assignee_id = card.assignee_id
    card.update!(assignee_id: assignee_id)
    save!
    card
  end

  def undo!
    commandable.update!(assignee_id: previous_assignee_id)
    mark_undone!
  end

  def summary
    assignee = User.find(assignee_id)
    "Assigned #{commandable.title} to #{assignee.name}"
  end
end
```

### Other Command Examples

```ruby
# app/models/command/close.rb
class Command::Close < Command
  def execute
    commandable.close(by: creator)
    save!
    commandable
  end

  def undo!
    commandable.reopen
    mark_undone!
  end
end

# app/models/command/move.rb
class Command::Move < Command
  store_accessor :details, :target_bucket_id, :source_bucket_id

  def execute
    card = commandable
    self.source_bucket_id = card.bucket_id
    card.update!(bucket_id: target_bucket_id)
    save!
    card
  end

  def undo!
    commandable.update!(bucket_id: source_bucket_id)
    mark_undone!
  end
end
```

---

## Context Objects for Parsing (#460)

Commands are parsed from natural language using a context object that extracts structured data:

```ruby
# app/models/command/parser/context.rb
class Command::Parser::Context
  attr_reader :bucket, :user, :text

  def initialize(bucket:, user:, text:)
    @bucket = bucket
    @user = user
    @text = text
  end

  def urls
    @urls ||= text.scan(%r{https?://\S+}).uniq
  end

  def mentioned_cards
    @mentioned_cards ||= urls.filter_map { |url| card_from_url(url) }
  end

  def mentioned_users
    @mentioned_users ||= bucket.account.users.where(
      name: text.scan(/@(\w+)/).flatten
    )
  end

  private

  def card_from_url(url)
    path = URI.parse(url).path
    route = Rails.application.routes.recognize_path(path)

    if route[:controller] == "cards" && route[:id]
      bucket.cards.find_by(id: route[:id])
    end
  rescue ActionController::RoutingError, URI::InvalidURIError
    nil
  end
end
```

Usage in the parser:

```ruby
class Command::Parser
  def parse(text)
    context = Context.new(bucket: @bucket, user: @user, text: text)

    # Pass context to LLM for command extraction
    response = ai_client.chat(
      messages: build_messages(context),
      tools: available_tools
    )

    build_commands(response, context)
  end
end
```

---

## Cost Tracking in Microcents (#978)

Track AI API costs using microcents (1/10,000th of a cent) to avoid floating-point precision issues:

```ruby
# app/models/ai/usage.rb
class Ai::Usage < ApplicationRecord
  belongs_to :account

  # Store costs in microcents: 1 cent = 10,000 microcents
  # $0.015 per 1K tokens = 150 microcents per token
  #
  # Column names use _in_microcents suffix for clarity
  # e.g., input_cost_in_microcents, output_cost_in_microcents

  def total_cost_in_microcents
    input_cost_in_microcents + output_cost_in_microcents
  end

  def total_cost_in_dollars
    total_cost_in_microcents / 1_000_000.0
  end

  def self.total_for(account, period: 30.days)
    where(account: account)
      .where(created_at: period.ago..)
      .sum(:input_cost_in_microcents) + sum(:output_cost_in_microcents)
  end
end
```

The `_in_` naming convention makes the unit explicit at every call site. No ambiguity about whether a value is dollars, cents, or microcents.

---

## Result Objects for Responses (#460, #857)

LLM responses are wrapped in Struct-based result objects for pattern matching:

```ruby
# app/models/ai/result.rb
Ai::Result = Struct.new(:commands, :response_text, :usage, keyword_init: true) do
  def success?
    commands.any? || response_text.present?
  end

  def has_commands?
    commands.any?
  end

  def needs_confirmation?
    commands.any?(&:needs_confirmation?)
  end
end
```

### Controller Pattern Matching

```ruby
# app/controllers/ai/chats_controller.rb
class Ai::ChatsController < ApplicationController
  def create
    result = Ai::Chat.new(
      bucket: current_bucket,
      user: current_user
    ).ask(params[:message])

    case result
    in { commands: [] , response_text: String => text }
      # Pure text response - no commands extracted
      render_response(text)
    in { commands: [Command => cmd] } if !cmd.needs_confirmation?
      # Single command, no confirmation needed
      cmd.execute
      redirect_to cmd.commandable, notice: cmd.summary
    in { commands: _ } if result.needs_confirmation?
      # Commands need user confirmation
      @pending_commands = result.commands
      render :confirm, status: :conflict
    in { commands: [*] }
      # Multiple commands, execute all
      result.commands.each(&:execute)
      redirect_to current_bucket, notice: "#{result.commands.size} actions completed"
    end
  end
end
```

---

## Tool Pattern for LLM Function Calling (#857)

### Ai::Tool Base Class

```ruby
# app/models/ai/tool.rb
class Ai::Tool
  class_attribute :tool_description
  class_attribute :tool_params, default: {}

  class << self
    def description(text)
      self.tool_description = text
    end

    def param(name, type:, description:, required: true, enum: nil)
      self.tool_params = tool_params.merge(
        name => { type: type, description: description, required: required, enum: enum }
      )
    end

    def tool_name
      name.demodulize.underscore
    end

    def schema
      {
        type: "function",
        function: {
          name: tool_name,
          description: tool_description,
          parameters: {
            type: "object",
            properties: tool_params.transform_values { |v|
              v.slice(:type, :description, :enum).compact
            },
            required: tool_params.select { |_, v| v[:required] }.keys.map(&:to_s)
          }
        }
      }
    end
  end

  attr_reader :bucket, :user, :arguments

  def initialize(bucket:, user:, arguments: {})
    @bucket = bucket
    @user = user
    @arguments = arguments.symbolize_keys
  end

  def call
    raise NotImplementedError
  end

  private

  def paginated_response(scope, page: 1, per: 20)
    records = scope.page(page).per(per)

    {
      results: records.map { |r| serialize(r) },
      total: records.total_count,
      page: records.current_page,
      total_pages: records.total_pages
    }
  end

  def serialize(record)
    record.as_json
  end
end
```

### Ai::ListCardsTool with DSL

```ruby
# app/models/ai/list_cards_tool.rb
class Ai::ListCardsTool < Ai::Tool
  include Ai::Tool::Filter

  description "Search and list cards in the current project. Returns paginated results."

  param :query,    type: "string",  description: "Search query to filter cards by title or body", required: false
  param :status,   type: "string",  description: "Filter by status", required: false, enum: %w[open closed archived]
  param :assignee, type: "string",  description: "Filter by assignee name", required: false
  param :tag,      type: "string",  description: "Filter by tag", required: false
  param :sort,     type: "string",  description: "Sort order", required: false, enum: %w[newest oldest updated due]
  param :page,     type: "integer", description: "Page number (default 1)", required: false

  register_filters :status, :assignee, :tag, :query

  def call
    scope = bucket.cards.visible_to(user)
    scope = apply_filters(scope)
    scope = apply_sort(scope)

    paginated_response(scope, page: arguments.fetch(:page, 1))
  end

  private

  def apply_sort(scope)
    case arguments[:sort]
    when "newest"  then scope.order(created_at: :desc)
    when "oldest"  then scope.order(created_at: :asc)
    when "updated" then scope.order(updated_at: :desc)
    when "due"     then scope.order(due_on: :asc)
    else scope.order(position: :asc)
    end
  end

  def serialize(card)
    {
      id: card.id,
      title: card.title,
      status: card.status,
      assignee: card.assignee&.name,
      due_on: card.due_on,
      tags: card.tags
    }
  end
end
```

Note the user-scoping: `bucket.cards.visible_to(user)` ensures the LLM can never access cards the user cannot see.

---

## Confirmation Pattern for Bulk Operations (#464)

### HTTP 409 Conflict for Confirmation

```ruby
# app/controllers/ai/chats_controller.rb
class Ai::ChatsController < ApplicationController
  def create
    result = process_message(params[:message])

    if result.needs_confirmation?
      @pending_commands = result.commands
      @confirmation_token = sign_commands(result.commands)

      render :confirm, status: :conflict # 409
      return
    end

    execute_commands(result.commands)
  end

  def confirm
    commands = verify_commands(params[:confirmation_token])

    commands.each(&:execute)
    redirect_to current_bucket, notice: "#{commands.size} actions completed"
  end

  private

  def sign_commands(commands)
    Rails.application.message_verifier(:ai_commands).generate(
      commands.map(&:attributes),
      expires_in: 5.minutes
    )
  end

  def verify_commands(token)
    attrs_list = Rails.application.message_verifier(:ai_commands).verify(token)
    attrs_list.map { |attrs| Command.new(attrs) }
  end
end
```

### Command::Cards with needs_confirmation?

```ruby
# app/models/command/cards.rb
class Command::Cards < Command
  store_accessor :details, :card_ids, :action

  def needs_confirmation?
    card_ids.size > 1  # Bulk operations always need confirmation
  end

  def execute
    cards.each { |card| apply_action(card) }
    save!
  end

  def summary
    "#{action.titleize} #{card_ids.size} cards"
  end

  private

  def cards
    bucket.cards.where(id: card_ids)
  end

  def apply_action(card)
    case action
    when "close"  then card.close(by: creator)
    when "assign" then card.update!(assignee_id: details["assignee_id"])
    when "move"   then card.update!(bucket_id: details["target_bucket_id"])
    end
  end
end
```

---

## Filter Registry Pattern (#857)

Reusable filter application for AI tools:

```ruby
# app/models/ai/tool/filter.rb
module Ai::Tool::Filter
  extend ActiveSupport::Concern

  class_methods do
    def register_filters(*filter_names)
      self.registered_filters = filter_names
    end

    def registered_filters
      @registered_filters || []
    end

    def registered_filters=(filters)
      @registered_filters = filters
    end
  end

  def apply_filters(scope)
    self.class.registered_filters.each do |filter_name|
      scope = filter(scope, filter_name)
    end
    scope
  end

  def filter(scope, name)
    value = arguments[name]
    return scope if value.blank?

    case name
    when :status
      scope.where(status: value)
    when :assignee
      user = bucket.account.users.find_by("name ILIKE ?", "%#{value}%")
      user ? scope.where(assignee: user) : scope.none
    when :tag
      scope.tagged_with(value)
    when :query
      scope.search(value)
    else
      scope
    end
  end
end
```

Tools declare their filters with `register_filters` and get `apply_filters` for free:

```ruby
class Ai::ListCardsTool < Ai::Tool
  include Ai::Tool::Filter

  register_filters :status, :assignee, :tag, :query

  def call
    scope = bucket.cards.visible_to(user)
    scope = apply_filters(scope)
    paginated_response(scope)
  end
end
```

---

## Order Clause Parser (#857)

Safely parse user-provided sort instructions into SQL order clauses:

```ruby
# app/models/ai/order_clause_parser.rb
class Ai::OrderClauseParser
  ALLOWED_DIRECTIONS = %w[asc desc].freeze

  PERMITTED_COLUMNS = {
    "cards" => %w[created_at updated_at position due_on title status],
    "comments" => %w[created_at updated_at],
    "users" => %w[name created_at]
  }.freeze

  def initialize(table:)
    @table = table
  end

  def parse(sort_string)
    return default_order if sort_string.blank?

    clauses = sort_string.split(",").map(&:strip)
    clauses.filter_map { |clause| parse_clause(clause) }
           .presence || default_order
  end

  private

  def parse_clause(clause)
    parts = clause.downcase.split(/\s+/)
    column = parts[0]
    direction = parts[1] || "asc"

    return nil unless permitted_column?(column)
    return nil unless ALLOWED_DIRECTIONS.include?(direction)

    # Return Arel node - never interpolate into SQL strings
    Arel.sql("#{@table}.#{column} #{direction}")
  end

  def permitted_column?(column)
    permitted = PERMITTED_COLUMNS[@table] || []
    permitted.include?(column)
  end

  def default_order
    [Arel.sql("#{@table}.created_at desc")]
  end
end
```

### SQL Injection Prevention

The parser prevents SQL injection by:
1. Whitelisting columns per table in `PERMITTED_COLUMNS`
2. Whitelisting directions to only `asc`/`desc`
3. Rejecting any clause that doesn't match known columns
4. Never interpolating user input directly into SQL

```ruby
# Usage in a tool
class Ai::ListCardsTool < Ai::Tool
  def apply_sort(scope)
    parser = Ai::OrderClauseParser.new(table: "cards")
    order_clauses = parser.parse(arguments[:sort])
    scope.order(order_clauses)
  end
end
```

---

## Code Review Culture

Four observations from reviewing AI-related PRs in the codebase:

1. **Security is non-negotiable** - Every AI tool that touches data scopes through `visible_to(user)`. The LLM never gets unscoped access. Review comments consistently flag missing user-scoping.

2. **Cost awareness is built in** - Microcent tracking is added from day one, not bolted on later. Every API call records its cost. This enables per-account usage limits.

3. **Undo is a first-class concern** - Commands store enough state to reverse themselves. The `undo!` method is not optional - if a command cannot be undone, it must override `undoable?` to return `false`.

4. **Confirmation before bulk changes** - The 409 Conflict pattern ensures the LLM cannot silently modify many records. The user always sees what will happen before it happens. Signed tokens prevent tampering with the pending command list.
