# frozen_string_literal: true

class Comfy < ApplicationCommand
  requires :organisms

  def call
    organisms.each do |organism|
      payload = ApplicationController.renderer.render template: 'application/workflow_api',
                                                      assigns: { o: organism.to_hsh, organism: }
      Net::HTTP.post(uri, payload, { 'Content-Type': 'application/json' })
    end
  end

  private

  def uri
    URI('http://localhost:8188/prompt')
  end
end
