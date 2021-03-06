class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :user_logged_in
  before_action :load_whatspp_message_ids, except: [:verify_phone_number, :submit_phone_otp, :index, :change_role_to_worker, :change_role_to_admin]
  before_action :check_if_admin, only: [:index, :change_role_to_worker, :change_role_to_admin]
  # before_action :verified_phone_number?, only: [:show]
  layout :resolve_layout

  def index
    @users = User.all
  end
  # GET /users/1
  # GET /users/1.json
  def show
    @event_data_by_category_and_minute = Event.where(whatspp_message_id: @whatspp_message_ids).group(:category).group_by_minute(:created_at).count
    @event_data_by_category = Event.where(whatspp_message_id: @whatspp_message_ids).group(:category).count
  end

  def events_count
    if params['category'].present?
      event_data = Event.where(category: params['category']).where(whatspp_message_id: @whatspp_message_ids).group_by_minute(:created_at).count.count
    else
      event_data = Event.where(whatspp_message_id: @whatspp_message_ids).group(:category).group_by_minute(:created_at).count.count
    end
    respond_to do |format|
      format.json { render json: event_data }
    end    
  end

  def event_data_by_category_and_minute
    if params['category'].present?
      event_data_by_category_and_minute = Event.where(category: params['category']).where(whatspp_message_id: @whatspp_message_ids).group_by_minute(:created_at).count
    else
      event_data_by_category_and_minute = Event.where(whatspp_message_id: @whatspp_message_ids).group(:category).group_by_minute(:created_at).count
    end
    respond_to do |format|
      format.json { render json: JSON.parse(event_data_by_category_and_minute.chart_json) }
    end
  end

  def events_by_category_data
    if params['category'].present?
      event_data_by_category = Event.where(category: params['category']).where(whatspp_message_id: @whatspp_message_ids).group(:category).count
    else
      event_data_by_category = Event.where(whatspp_message_id: @whatspp_message_ids).group(:category).count
    end
    respond_to do |format|
      format.json { render json: event_data_by_category }
    end
  end

  # GET /users/new
  # def new
  #   @user = User.new
  # end

  # GET /users/1/edit
  # def edit
  # end

  # # POST /users
  # # POST /users.json
  # def create
  #   @user = User.new(user_params)

  #   respond_to do |format|
  #     if @user.save
  #       format.html { redirect_to @user, notice: 'User was successfully created.' }
  #       format.json { render :show, status: :created, location: @user }
  #     else
  #       format.html { render :new }
  #       format.json { render json: @user.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        # format.json { redire :index, status: :ok, location: @user }
      else
        format.html { redirect_to action: 'edit' }
        # format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def verify_phone_number
    if @user.verified_phone_number
      redirect_to @user
    else
      @user.generate_new_mobile_otp
      @user.send_otp_to_user_mobile
    end
  end

  def submit_phone_otp
    if params['otp'].to_i == @user.sms_otp
      @user.verified_phone_number = 1
      @user.save
      redirect_to @user, notice: 'Phone Verified'
    else
      redirect_to verify_phone_number_user_path(id: @user.id)
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  # def destroy
  #   @user.destroy
  #   respond_to do |format|
  #     format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
  #     format.json { head :no_content }
  #   end
  # end

  def change_role_to_admin
    user = User.find(params['id'])
    user.number_of_admin_users_requested = 0
    user.role = 0
    user.save
    redirect_to users_url
  end

  def change_role_to_worker
    user = User.find(params['id'])
    user.number_of_admin_users_requested += 1
    if user.number_of_admin_users_requested > (0.75 * (User.where(role: 0).count-1))
      user.role = 1
    end
    user.save
    redirect_to users_url
  end

  private
    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:first_name, :second_name, :password, :password_confirmation, :otp)
    end

    def resolve_layout
      case action_name
      when 'verify_phone_number'
        'devise'
      else
        'application'
      end
    end

    def load_whatspp_message_ids
      whatspp_messages = WhatsppMessage.none
      if @user.admin?
        whatspp_messages = WhatsppMessage.all
        whatspp_messages = whatspp_messages.where(user_id: params['user']) if params['user'].present?
      else
        whatspp_messages = @user.whatspp_messages
      end      
      whatspp_messages = whatspp_messages.where('created_at > ?', Time.parse(params['start_date'])) if params['start_date'].present?
      whatspp_messages = whatspp_messages.where('created_at < ?', Time.parse(params['end_date'])) if params['end_date'].present?
      # @whatspp_messages = @whatspp_messages.where(user_id: params['user') if params['user']
      # if params['category'].present?
      #   @whatspp_message_ids = Event.where(category: params['category']).where(whatspp_message_id: whatspp_messages.ids).pluck(:whatspp_message_id)
      # end
      @whatspp_message_ids = whatspp_messages.pluck(:id)
    end

    def check_if_admin
      redirect_to @user unless @user.admin?
    end

    # def verified_phone_number?
    #   redirect_to verify_phone_number_user_path(id: @user.id) unless @user.verified_phone_number
    # end
end
