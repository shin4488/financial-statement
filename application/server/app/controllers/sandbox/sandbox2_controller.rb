module Sandbox
    class Sandbox2Controller < ApplicationController
        def index
            render status: :ok, json: {
                status: 'SUCCESS', message: 'The SAND222!更新！', data: { num: 123, array: ["a", "b"] }
            }
        end
    end
end
