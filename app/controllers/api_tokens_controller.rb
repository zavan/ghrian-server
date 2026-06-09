# Per-user bearer tokens for API clients. Tokens are stored plaintext (simple by
# design) so they can be copied from the list at any time.
class ApiTokensController < ApplicationController
  def index
    @api_token = Current.user.api_tokens.new
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)
  end

  def create
    @api_token = Current.user.api_tokens.new(api_token_params)
    if @api_token.save
      redirect_to api_tokens_path, notice: "API token “#{@api_token.name}” created."
    else
      @api_tokens = Current.user.api_tokens.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy
    redirect_to api_tokens_path, notice: "API token revoked."
  end

  private
    def api_token_params
      params.require(:api_token).permit(:name)
    end
end
