class Translation::Approval < ApplicationRecord
  belongs_to :translation, touch: true
  belongs_to :approver, class_name: "User", default: -> { Current.user }
end
