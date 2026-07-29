class Translation::Version < ApplicationRecord
  belongs_to :translation
  belongs_to :author, class_name: "User", optional: true
end
