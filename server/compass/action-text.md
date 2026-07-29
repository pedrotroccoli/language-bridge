---
tags: [rails, 37signals, action-text, rich-text]
---

# Action Text

> Sanitizer config, autolinking, link retargeting, remote images.

See also: [[security]], [[views]], [[stimulus]]

---

## Sanitizer Config (CRITICAL for production)
```ruby
Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
end
```

## Autolink at Render Time (not save time)
Override `app/views/layouts/action_text/contents/_content.html.erb`:
```erb
<div class="action-text-content"><%= format_html yield -%></div>
```
Nokogiri traversal for URL/email autolinking, excluding `<a>`, `<pre>`, `<code>`.

## Link Retargeting (Stimulus)
```javascript
export default class extends Controller {
  connect() {
    this.element.querySelectorAll("a").forEach(link => {
      link.target = link.href.startsWith(window.location.origin) ? "_top" : "_blank"
    })
  }
}
```

## Remote Images: `skip_pipeline: true`
```erb
<%= image_tag remote_image.url, skip_pipeline: true %>
```

## Rich Text CSS
- `.rich-text-content p:empty { display: none; }` — hide empty paragraphs
- Constrain media: `max-block-size: 32rem; object-fit: contain;`
- Code blocks: `overflow-x: auto; tab-size: 2;`
