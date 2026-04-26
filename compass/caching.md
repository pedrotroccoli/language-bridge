---
tags: [compass, rails, caching, performance]
---

# Caching

See also: [[views]], [[performance]], [[controllers]]

## HTTP Caching (ETags)

HTTP caching lets the browser skip downloading a response it already has. Rails makes this easy with `fresh_when`.

### How ETags Work

```
1. Browser requests GET /projects/1
2. Server renders response, computes ETag from content hash
3. Server sends response with header: ETag: "abc123"
4. Browser caches response locally

5. Browser requests GET /projects/1 again
6. Browser sends header: If-None-Match: "abc123"
7. Server computes ETag, sees it matches
8. Server sends 304 Not Modified (empty body)
9. Browser uses cached version
```

The server still runs the controller action and computes the ETag, but skips rendering the view and sending the body. This saves rendering time and bandwidth.

### fresh_when with Arrays

Pass an array to `fresh_when` to build a composite ETag from multiple objects:

```ruby
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
    @tasks = @project.tasks.order(:position)

    fresh_when [@project, @tasks]
  end
end
```

Rails calls `cache_key_with_version` on each element. If any object changes (updated_at changes), the ETag changes, and the browser gets a fresh response.

For collections, ActiveRecord computes a single cache key from the count and maximum `updated_at`:

```ruby
# @tasks.cache_key_with_version
# => "tasks/query-3-20240115120000000000"
#    (3 records, max updated_at)
```

### Don't HTTP Cache Forms

Never use `fresh_when` on actions that render forms. Rails CSRF tokens are embedded in forms, and a 304 response means the browser reuses a stale CSRF token, resulting in a 422 Unprocessable Entity on form submission.

```ruby
# BAD — will cause 422 errors on form submit
class ProjectsController < ApplicationController
  def edit
    @project = Current.account.projects.find(params[:id])
    fresh_when @project  # Don't do this!
  end
end

# GOOD — only use fresh_when on read-only actions
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
    fresh_when @project
  end

  def edit
    @project = Current.account.projects.find(params[:id])
    # No fresh_when here
  end
end
```

### Public Caching

For content that's the same for all users (marketing pages, public API responses), use `expires_in` with `public: true`:

```ruby
class HomePagesController < ApplicationController
  allow_unauthenticated_access

  def show
    expires_in 30.seconds, public: true
  end
end
```

This sets `Cache-Control: public, max-age=30`. CDNs and proxies can cache this response and serve it directly without hitting your server at all. Keep the duration short (30 seconds is a good default) so updates propagate quickly.

## Fragment Caching

Fragment caching stores rendered HTML fragments and reuses them when the underlying data hasn't changed.

### Bad vs Good: Include Context

```ruby
# BAD — cache key doesn't reflect all inputs
<% cache project do %>
  <div class="project">
    <h2><%= project.name %></h2>
    <p><%= project.tasks.count %> tasks</p>
    <% if Current.user.admin? %>
      <%= link_to "Edit", edit_project_path(project) %>
    <% end %>
  </div>
<% end %>
```

This is broken: the admin link will be cached for the first user who views it, then shown (or hidden) for everyone. The cache key is just the project's cache_key_with_version — it doesn't account for the user's role.

```ruby
# GOOD — cache key includes everything that affects output
<% cache [project, Current.user.admin?] do %>
  <div class="project">
    <h2><%= project.name %></h2>
    <p><%= project.tasks.count %> tasks</p>
    <% if Current.user.admin? %>
      <%= link_to "Edit", edit_project_path(project) %>
    <% end %>
  </div>
<% end %>
```

The cache key now includes the admin boolean, so admins and non-admins get separate cached fragments.

### Include What Affects Output

The cache key must include everything that changes the rendered HTML:

```ruby
# Object being rendered
<% cache project do %>

# Object + related data that appears in the fragment
<% cache [project, project.tasks] do %>

# Object + user-specific rendering
<% cache [project, Current.user.admin?] do %>

# Object + locale
<% cache [project, I18n.locale] do %>

# Multiple varying inputs
<% cache [project, project.tasks, Current.user.admin?, I18n.locale] do %>
```

### Touch Chains

When a child record changes, the parent's cache must be invalidated. Use `touch: true` on belongs_to associations to propagate changes up the chain (#566):

```ruby
class Task < ApplicationRecord
  belongs_to :project, touch: true
end

class Comment < ApplicationRecord
  belongs_to :task, touch: true
end
```

Now when a comment is created or updated:
1. `comment.save!` triggers `task.touch` (updates task's `updated_at`)
2. `task.touch` triggers `project.touch` (updates project's `updated_at`)
3. Any fragment cached on `project` is automatically invalidated

This creates a chain: Comment → Task → Project. The project's `cache_key_with_version` changes, so `<% cache project do %>` produces a cache miss and re-renders.

Be deliberate about touch chains. Don't add `touch: true` everywhere — only where a child change should invalidate the parent's cached representation.

### Domain Models for Cache Keys

Sometimes you need a cache key that represents a concept, not a single record. Create a domain model for it (#1132):

```ruby
# app/models/project/cache_key.rb
class Project::CacheKey
  attr_reader :project

  def initialize(project)
    @project = project
  end

  def cache_key_with_version
    "project_summary/#{project.id}-#{project.updated_at.to_i}-#{tasks_key}-#{members_key}"
  end

  private

  def tasks_key
    project.tasks.maximum(:updated_at).to_i
  end

  def members_key
    project.members.maximum(:updated_at).to_i
  end
end
```

```ruby
<% cache Project::CacheKey.new(@project) do %>
  <!-- complex rendering that depends on project, tasks, and members -->
<% end %>
```

This gives you explicit control over what invalidates the cache, without relying on touch chains for everything.

## Lazy-Loaded Content with Turbo Frames

For content that is expensive to render or rarely seen, load it lazily with Turbo Frames (#1089).

### Menu Example with Dialog

A navigation menu that loads its content only when the user hovers over it:

```erb
<!-- In the navigation bar -->
<details data-controller="lazy-menu" data-action="mouseenter->lazy-menu#load">
  <summary>Projects</summary>
  <turbo-frame id="projects_menu" src="" loading="lazy">
    <!-- Skeleton placeholder shown while loading -->
    <div class="menu-skeleton">
      <div class="skeleton-item"></div>
      <div class="skeleton-item"></div>
      <div class="skeleton-item"></div>
    </div>
  </turbo-frame>
</details>
```

```javascript
// app/javascript/controllers/lazy_menu_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  load() {
    const frame = this.element.querySelector("turbo-frame")
    if (!frame.src || frame.src === "") {
      frame.src = this.element.dataset.menuUrl
    }
  }
}
```

The Turbo Frame has no `src` initially. On `mouseenter`, the Stimulus controller sets the `src`, triggering a fetch. The skeleton placeholder gives visual feedback while loading.

### Controller with fresh_when

The endpoint that serves the lazy-loaded content can use HTTP caching:

```ruby
class Menus::ProjectsController < ApplicationController
  def show
    @projects = Current.account.projects.order(:name)
    fresh_when @projects
  end
end
```

```erb
<!-- app/views/menus/projects/show.html.erb -->
<turbo-frame id="projects_menu">
  <ul class="menu">
    <% @projects.each do |project| %>
      <li><%= link_to project.name, project_path(project) %></li>
    <% end %>
  </ul>
</turbo-frame>
```

The first hover fetches and renders the menu. Subsequent hovers get a 304 Not Modified if the project list hasn't changed.

## User-Specific Content in Cached Fragments

When a fragment is mostly the same for everyone but has small user-specific elements (like "Edit" buttons visible only to the owner), avoid splitting the cache by user. Instead, cache one version and use JavaScript to show/hide user-specific elements.

### Data Attributes with Stimulus

```erb
<% cache project do %>
  <div class="project"
       data-controller="ownership"
       data-ownership-owner-id-value="<%= project.creator_id %>">
    <h2><%= project.name %></h2>
    <p><%= project.description %></p>

    <div data-ownership-target="ownerOnly" class="hidden">
      <%= link_to "Edit", edit_project_path(project) %>
      <%= button_to "Delete", project_path(project), method: :delete %>
    </div>
  </div>
<% end %>
```

```javascript
// app/javascript/controllers/ownership_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ownerOnly"]
  static values = { ownerId: Number }

  connect() {
    if (this.isOwner) {
      this.ownerOnlyTargets.forEach(el => el.classList.remove("hidden"))
    }
  }

  get isOwner() {
    return this.ownerIdValue === window.currentUserId
  }
}
```

The cached fragment includes the owner-only elements but hides them with CSS. The Stimulus controller reveals them client-side if the current user matches. This way the fragment is cached once for all users, and authorization is still enforced server-side on the actual edit/delete endpoints.

### JS Show/Hide Pattern

The general pattern:
1. Render all possible UI elements in the cached fragment
2. Hide user-specific elements with `class="hidden"`
3. Add data attributes with the relevant IDs/roles
4. Use a Stimulus controller to show/hide based on the current user
5. Always enforce authorization server-side on mutations

This is not a security mechanism — it's a caching optimization. The server must still check permissions on every write action.

## Extract Dynamic Content to Turbo Frames

When a mostly-static page has one dynamic section, extract the dynamic part into a Turbo Frame so the rest can be cached (#317).

### Assignment Dropdown Extraction

A project page where everything is cacheable except the "Assign to" dropdown (which shows different users based on permissions):

```erb
<!-- app/views/projects/show.html.erb -->
<% cache @project do %>
  <div class="project">
    <h1><%= @project.name %></h1>
    <p><%= @project.description %></p>

    <!-- Everything above is cacheable -->

    <!-- This part varies by user, so extract it -->
    <turbo-frame id="assignment_dropdown" src="<%= project_assignments_path(@project) %>">
      <span class="loading">Loading assignments...</span>
    </turbo-frame>

    <!-- Continue with cacheable content -->
    <div class="project-details">
      <%= render @project.tasks %>
    </div>
  </div>
<% end %>
```

```ruby
class Projects::AssignmentsController < ApplicationController
  def index
    @project = Current.account.projects.find(params[:project_id])
    @assignable_users = @project.assignable_users_for(Current.user)
  end
end
```

```erb
<!-- app/views/projects/assignments/index.html.erb -->
<turbo-frame id="assignment_dropdown">
  <select name="assigned_to">
    <% @assignable_users.each do |user| %>
      <option value="<%= user.id %>"><%= user.name %></option>
    <% end %>
  </select>
</turbo-frame>
```

The main project page is cached for everyone. The assignment dropdown is loaded separately per-user via a Turbo Frame. This gives you the caching benefit for 95% of the page while still personalizing the dynamic 5%.
