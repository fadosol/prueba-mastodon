# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::Statuses::ReblogsController do
  render_views

  let(:user)  { Fabricate(:user) }
  let(:app)   { Fabricate(:application, name: 'Test app', website: 'http://testapp.com') }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:statuses', application: app) }

  context 'with an oauth token' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token }
    end

    describe 'POST #create' do
      let(:status) { Fabricate(:status, account: user.account) }

      before do
        post :create, params: { status_id: status.id }
      end

      context 'with public status' do
        it 'reblogs the status', :aggregate_failures do
          expect(response).to have_http_status(200)

          expect(status.reblogs.count).to eq 1

          expect(user.account.reblogged?(status)).to be true

          hash_body = body_as_json

          expect(hash_body[:reblog][:id]).to eq status.id.to_s
          expect(hash_body[:reblog][:reblogs_count]).to eq 1
          expect(hash_body[:reblog][:reblogged]).to be true
        end
      end

      context 'with private status of not-followed account' do
        let(:status) { Fabricate(:status, visibility: :private) }

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end
    end

    describe 'POST #destroy', :sidekiq_inline do
      context 'with public status' do
        let(:status) { Fabricate(:status, account: user.account) }

        before do
          ReblogService.new.call(user.account, status)
          post :destroy, params: { status_id: status.id }
        end

        it 'destroys the reblog', :aggregate_failures do
          expect(response).to have_http_status(200)

          expect(status.reblogs.count).to eq 0

          expect(user.account.reblogged?(status)).to be false

          hash_body = body_as_json

          expect(hash_body[:id]).to eq status.id.to_s
          expect(hash_body[:reblogs_count]).to eq 0
          expect(hash_body[:reblogged]).to be false
        end
      end

      context 'with public status when blocked by its author' do
        let(:status) { Fabricate(:status, account: user.account) }

        before do
          ReblogService.new.call(user.account, status)
          status.account.block!(user.account)
          post :destroy, params: { status_id: status.id }
        end

        it 'destroys the reblog', :aggregate_failures do
          expect(response).to have_http_status(200)

          expect(status.reblogs.count).to eq 0

          expect(user.account.reblogged?(status)).to be false

          hash_body = body_as_json

          expect(hash_body[:id]).to eq status.id.to_s
          expect(hash_body[:reblogs_count]).to eq 0
          expect(hash_body[:reblogged]).to be false
        end
      end

      context 'with private status that was not reblogged' do
        let(:status) { Fabricate(:status, visibility: :private) }

        before do
          post :destroy, params: { status_id: status.id }
        end

        it 'returns http not found' do
          expect(response).to have_http_status(404)
        end
      end
    end
  end
end
