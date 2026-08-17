class PasswordsController < Devise::PasswordsController
  respond_to :json
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      render json: { message: "Reset instructions sent. Check your email." }, status: :ok
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def edit
    frontend_url = ENV.fetch("FRONTEND_URL", "https://vertical-drama-five.vercel.app")
    redirect_to "#{frontend_url}/reset-password?reset_password_token=#{params[:reset_password_token]}", allow_other_host: true
  end

  def update
    self.resource = resource_class.reset_password_by_token(resource_params)
    yield resource if block_given?

    if resource.errors.empty?
      token = request.env["warden-jwt_auth.token"]
      render json: {
        message: "Password updated successfully.",
        token:   token
      }, status: :ok
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def resource_params
    params.require(:user).permit(
      :email,
      :password,
      :password_confirmation,
      :reset_password_token
    )
  end
end
