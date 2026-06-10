# Per-user bearer tokens for API clients. Only a digest is stored, so the plaintext
# token is surfaced once (via flash) right after creation and never again.
class ApiTokensController < ApplicationController
  def index
    @api_token = Current.user.api_tokens.new
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)
  end

  def create
    @api_token = Current.user.api_tokens.new(api_token_params)
    if @api_token.save
      flash[:new_token] = @api_token.token
      redirect_to api_tokens_path,
        notice: "API token “#{@api_token.name}” created. Copy it now — it won't be shown again."
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
