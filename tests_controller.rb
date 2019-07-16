# app\controllers\admin\tests_controller.rb

class TestsController < ApplicationController

  # ファイルアップロード
  def csv_upload
    respond_to do |format|
      csv_manager = CsvManager.new
      csv_manager.upload(params[:file])
      if csv_manager.valid?
        format.json { render json: { file_path: csv_manager.file_path, character_code: csv_manager.character_code.to_s }, status: :ok }
      else
        format.json { render json: csv_manager.errors, status: :unprocessable_entity }
      end
    end
  end

  # 登録処理実行
  def csv_load
    respond_to do |format|
      csv_manager = CsvManager.new(params[:csv_file_path])
      begin
        result = insert_all(
          csv_manager.read_csv(params[:csv_character_code]),
          params[:test_id]
        )
        format.json { render json: result, status: :ok }
      rescue => e
        format.json { render json: e.message, status: :unprocessable_entity }
      end
    end
  end

  private

  # 一括登録
  def insert_all(request, test_id)
    ActiveRecord::Base.transaction(isolation: :read_committed) do

      result = {}
      # 総数
      result[:total_count] = request.count
      # 処理件数
      result[:process_count] = 0
      # エラー件数
      result[:error_count] = 0
      # エラーメッセージ一覧
      result[:errors] = []

      request.each_with_index do |value, index|
        is_register = true
        line_number = index + 1
        tests_param = format_tests_param(value)

        if ! tests_param[:name].present?
          # 必須チェック
          is_register = false
          result[:errors] << "#{line_number}行目：名前が入力されていません。"
        end

        if ! tests_param[:age].present?
          # 必須チェック
          is_register = false
          result[:errors] << "#{line_number}行目：年齢が入力されていません。"
        else
          if ! numerical?(tests_param[:age])
            # 半角数字チェック
            is_register = false
            result[:errors] << "#{line_number}行目：年齢は半角数字で入力してください。"
          end
        end

        # 入力エラーの場合 登録処理スキップ
        result[:error_count] += 1 unless is_register
        next unless is_register

        test = ::Test.find(test_id)
        test = ::Test.new if test.blank?
        test.assign_attributes tests_param
        test.save!
        result[:process_count] += 1
      end

      # 件数フォーマット処理
      result[:total_count] = result[:total_count].to_s(:delimited)
      result[:process_count] = result[:process_count].to_s(:delimited)
      result[:error_count] = result[:error_count].to_s(:delimited)

      raise ActiveRecord::ActiveRecordError.new result.to_json if result[:errors].present?

      result
    end
  end

  # CSVデータから取得したパラメータ
  def format_tests_param(params)
    # listのパラメータの記載順はアップロードされたcsvのデータカラム順
    column_name_list = [
      :name,   # 1列目 名前
      :age,    # 2列目 年齢
    ]
    # listの対象となるcsvのカラム列
    column_name_list_target_index = [1,2]
    formatted_params = {}
    column_name_list_target_index.each_with_index  do |value, index|
      param = nil
      if params[value - 1].present?
        # 全角半角スペーストリム
        param = params[value - 1]&.gsub(/[[:space:]]/, '')
      end
      formatted_params[column_name_list[index]] = param
    end
    formatted_params
  end

  # 数値のみか
  def numerical?(str)
    str.to_s.match(/^[0-9]+$/).present? ? true : false
  end

end