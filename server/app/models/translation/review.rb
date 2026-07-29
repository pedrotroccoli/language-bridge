class Translation::Review < ApplicationRecord
  belongs_to :translation, touch: true
  belongs_to :requester, class_name: "User", default: -> { Current.user }
end
