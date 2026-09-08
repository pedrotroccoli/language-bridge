# Landing page when the user rejects an `lb login` request. Nothing to revoke —
# the one-time code is only minted on approval — so this simply confirms that no
# access was granted and the CLI was left waiting.
class Cli::RejectionsController < ApplicationController
  def show
  end
end
