# lib\csv_manager.rb

require 'nkf'
require 'csv'
require 'objspace'

class CsvManager

  DEFAULT_MAX_LINE_COUNT = 50000
  DEFAULT_MAX_LINE_COUNT.freeze

  attr_accessor :max_line_count

  # 初期化
  def initialize(file_path = nil)
    # ファイルパス
    @file_path = file_path
    # 最大行設定
    @max_line_count = DEFAULT_MAX_LINE_COUNT
  end

  # ファイルアップロード
  def upload(file)
    # CSVアップロードのインスタンス生成
    csv_uploader = CsvUploader.new()
    # 現在日時取得
    timestamp = Time.zone.now.tap { |t| break t.to_i.to_s + format('%06d', t.usec) }
    # ファイル名は「現在日時-オリジナルファイル名」
    file_name = "#{timestamp}-#{file.original_filename}"

    file.original_filename = file_name
    csv_uploader.store! file

    if Rails.env.development? || Rails.env.test?
      @file_path = csv_uploader.path
    else
      @file_path = file_download(csv_uploader.url, file_name)
    end
  end

  # ファイルパス取得
  def file_path
    @file_path
  end

  # 文字コード取得
  def character_code
    return @character_code if @character_code.present?

    File.open(@file_path) do |file|
      contents = file.read
      @character_code = NKF.guess(contents)
      @character_code.present? && (@character_code == NKF::UTF8 || NKF::SJIS)
    end

    @character_code
  end

  # エラーの配列取得
  def errors
    @errors
  end

  def valid?(company_id=nil, processing_type=nil)
    @errors = {}
    # ファイル存在チェック
    @errors[:file_not_found] = 'ファイルが見つかりません' unless file_present?
    # 拡張子チェック
    @errors[:not_supported_extension] = '不正な拡張子です。csvファイルが許可されてます' if ! supported_extension? && @errors.blank?
    # 行数チェック
    @errors[:not_supported_max_line_count] = "最大処理件数を超過しています (最大#{@max_line_count.to_s(:delimited)}件)" if ! supported_max_line_count? && @errors.blank?
    # 文字コードチェック
    @errors[:not_supported_character_code] = '文字コードはUTF-8またはShift-JISでアップロードしてください' if ! supported_character_code? && @errors.blank?
    # チェック結果 OK : true NG : false
    @errors.blank?
  end

  # CSVファイル読み込み 一行ずつの配列で返却
  def read_csv(character_code, header_skip = true)
    encoding = ''
    case character_code
    when NKF::UTF8.to_s
      encoding = 'UTF-8:UTF-8'
    when NKF::SJIS.to_s
      # encoding = 'CP932:UTF-8'
      encoding = 'Shift_JIS:UTF-8'
    when "Windows-31J"
      encoding = 'Windows-31J:UTF-8'
    end
    if header_skip
      return CSV.read(@file_path, headers: true, encoding: encoding).map(&:values_at)
    else
      return CSV.read(@file_path, encoding: encoding)
    end
  end

  private

  # ファイル存在チェック
  def file_present?
    File.exist?(@file_path)
  end

  # 拡張子チェック
  def supported_extension?
    File.extname(@file_path)&.downcase&.eql? '.csv'
  end

  # 最大行数チェック
  def supported_max_line_count?
    file_line_count = 0
    open(@file_path) { |f|
      while
        f.gets
      end
      file_line_count = f.lineno
    }
    # ヘッダー行込でカウントするので +1
    file_line_count <= @max_line_count + 1
  end

  # 文字コードチェック
  # 旧漢字を許容する為、Sjis-Winも許可する
  def supported_character_code?
    self.character_code == NKF::UTF8 ||self.character_code == NKF::SJIS || self.character_code.to_s == 'Windows-31J'
  end

  def file_download(url, file_name)
    parent_path = Dir.tmpdir
    csv_file_path = Pathname.new(Dir.tmpdir).join(file_name).to_s

    open(url) do |file|
      open(csv_file_path, "w+b") do |out|
        out.write(file.read)
      end
    end

    csv_file_path
  end

end
