class Translation::Publication < ApplicationRecord
  belongs_to :translation, touch: true
  belongs_to :publisher, class_name: "User", optional: true,
    default: -> { Current.user }
end
