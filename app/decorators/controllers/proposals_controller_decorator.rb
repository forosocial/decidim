# frozen_string_literal: true

Rails.application.config.to_prepare do
  Decidim::Proposals::ProposalsController.class_eval do
    private

    def default_states
      []
    end
  end
end
