module Sandbox
    class SandboxController < ApplicationController
        def index
            render status: :ok, json: {
                status: 'SUCCESS', added_data: "追加したデータ", message: 'The SAND!更新！', data: { num: 123, array: ["a", "b"] }
            }
        end
    end
end
