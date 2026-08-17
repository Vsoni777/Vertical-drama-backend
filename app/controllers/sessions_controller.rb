class SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    token = request.env['warden-jwt_auth.token']

    render json: {
      user: resource,
      token: token
    }, status: :ok
  end

  def respond_to_on_destroy(_resource = nil)
    render json: {
      status: 200,
      message: "Logged out successfully"
    }
  end
end