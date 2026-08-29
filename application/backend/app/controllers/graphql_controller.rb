class GraphqlController < ApplicationController
  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    result = FinancialStatementSchema.execute(query, variables: variables, context: {}, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # variablesはPOSTのJSONボディでもフォームデータ（JSON文字列）でも届くため、どちらもHashに揃える
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # 変数名・型の妥当性はこの後graphql-rubyが検証する
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end
end
