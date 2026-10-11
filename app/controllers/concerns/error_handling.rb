module ErrorHandling
  extend ActiveSupport::Concern

  class InvalidParams < StandardError
    attr_reader :details

    def initialize(details)
      @details = details
      super("Invalid query parameters")
    end
  end

  included do
    rescue_from StandardError, with: :render_internal_error
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_malformed_body
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed
    rescue_from InvalidParams, with: :render_invalid_params
  end

  private

  def render_error(status, code, message, details = {})
    render json: { error: { code: code, message: message, details: details } }, status: status
  end

  def render_not_found(_error)
    render_error(:not_found, "not_found", "Resource not found")
  end

  def render_validation_failed(error)
    render_error(:unprocessable_entity, "validation_failed", "Validation failed", error.record.errors.to_hash)
  end

  def render_invalid_params(error)
    render_error(:unprocessable_entity, "invalid_params", error.message, error.details)
  end

  def render_bad_request(error)
    render_error(:bad_request, "bad_request", error.message)
  end

  def render_malformed_body(_error)
    render_error(:bad_request, "bad_request", "Malformed request body")
  end

  def render_internal_error(error)
    Rails.logger.error("#{error.class}: #{error.message}\n#{Rails.backtrace_cleaner.clean(error.backtrace).join("\n")}")
    render_error(:internal_server_error, "internal_error", "Internal server error")
  end
end
