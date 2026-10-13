require "rails_helper"

RSpec.describe UseCases::SequentialRunner do
  # 処理・記録・待ち時間の呼び出しを順に記録する
  let(:events) { [] }

  def run_each(items, on_success: ->(item) { events << [ :success, item ] },
               on_failure: ->(item, error) { events << [ :failure, item, error ] }, &block)
    described_class.each(items, sleeper: ->(seconds) { events << [ :sleep, seconds ] },
                                on_success: on_success, on_failure: on_failure, &block)
  end

  it "1件ずつ順に処理し、失敗した件はその例外を渡して次へ進み、各件の後（失敗の後も）に本番の間隔（1秒）を待つ" do
    error = RuntimeError.new("download failed")

    run_each(%w[S1000001 S1000002 S1000003]) do |doc_id|
      events << [ :process, doc_id ]
      raise error if doc_id == "S1000002"
    end

    expect(events).to eq [
      [ :process, "S1000001" ], [ :success, "S1000001" ], [ :sleep, 1 ],
      [ :process, "S1000002" ], [ :failure, "S1000002", error ], [ :sleep, 1 ],
      [ :process, "S1000003" ], [ :success, "S1000003" ], [ :sleep, 1 ]
    ]
  end

  it "成功の記録で起きた例外も、その件の失敗として扱う" do
    error = RuntimeError.new("log failed")

    run_each(%w[S1000001], on_success: ->(_item) { raise error }) { |_doc_id| }

    expect(events).to eq [ [ :failure, "S1000001", error ], [ :sleep, 1 ] ]
  end

  # 日次取込はこの例外を日単位の隔離で受け、その日の残りの書類を取り込まずに list failed として記録する
  it "失敗の記録で起きた例外は隔離せずに伝え、その件の後に待たず、後の件を処理しない" do
    error = RuntimeError.new("sentry failed")

    expect do
      run_each(%w[S1000001 S1000002], on_failure: ->(_item, _error) { raise error }) do |doc_id|
        events << [ :process, doc_id ]
        raise "download failed"
      end
    end.to raise_error(error)

    expect(events).to eq [ [ :process, "S1000001" ] ]
  end

  it "対象が空なら、処理も待ちもしない" do
    run_each([]) { |doc_id| events << [ :process, doc_id ] }

    expect(events).to be_empty
  end

  it "StandardError でない例外（rakeの中断など）は隔離せず、後の件を処理しない" do
    expect do
      run_each(%w[S1000001 S1000002]) do |doc_id|
        events << [ :process, doc_id ]
        raise Interrupt
      end
    end.to raise_error(Interrupt)

    expect(events).to eq [ [ :process, "S1000001" ] ]
  end
end
