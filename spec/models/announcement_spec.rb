# frozen_string_literal: true

require 'rails_helper'

describe Announcement do
  describe 'Scopes' do
    context 'with published and unpublished records' do
      let!(:published) { Fabricate(:announcement, published: true) }
      let!(:unpublished) { Fabricate(:announcement, published: false, scheduled_at: 10.days.from_now) }

      describe '#unpublished' do
        it 'returns records with published false' do
          results = described_class.unpublished

          expect(results).to eq([unpublished])
        end
      end

      describe '#published' do
        it 'returns records with published true' do
          results = described_class.published

          expect(results).to eq([published])
        end
      end
    end

    context 'with timestamped announcements' do
      let!(:adam_announcement) { Fabricate(:announcement, starts_at: 100.days.ago, scheduled_at: 10.days.ago, published_at: 10.days.ago, ends_at: 5.days.from_now) }
      let!(:brenda_announcement) { Fabricate(:announcement, starts_at: 10.days.ago, scheduled_at: 100.days.ago, published_at: 10.days.ago, ends_at: 5.days.from_now) }
      let!(:clara_announcement) { Fabricate(:announcement, starts_at: 10.days.ago, scheduled_at: 10.days.ago, published_at: 100.days.ago, ends_at: 5.days.from_now) }
      let!(:darnelle_announcement) { Fabricate(:announcement, starts_at: 10.days.ago, scheduled_at: 10.days.ago, published_at: 10.days.ago, ends_at: 5.days.from_now, created_at: 100.days.ago) }

      describe '#chronological' do
        it 'orders the records correctly' do
          results = described_class.chronological

          expect(results).to eq(
            [
              adam_announcement,
              brenda_announcement,
              clara_announcement,
              darnelle_announcement,
            ]
          )
        end
      end

      describe '#reverse_chronological' do
        it 'orders the records correctly' do
          results = described_class.reverse_chronological

          expect(results).to eq(
            [
              darnelle_announcement,
              clara_announcement,
              brenda_announcement,
              adam_announcement,
            ]
          )
        end
      end
    end
  end

  describe 'Validations' do
    describe 'text' do
      it 'validates presence of attribute' do
        record = Fabricate.build(:announcement, text: nil)

        expect(record).to_not be_valid
        expect(record.errors[:text]).to be_present
      end
    end

    describe 'ends_at' do
      it 'validates presence when starts_at is present' do
        record = Fabricate.build(:announcement, starts_at: 1.day.ago)

        expect(record).to_not be_valid
        expect(record.errors[:ends_at]).to be_present
      end

      it 'does not validate presence when starts_at is missing' do
        record = Fabricate.build(:announcement, starts_at: nil)

        expect(record).to be_valid
        expect(record.errors[:ends_at]).to_not be_present
      end
    end
  end

  describe '#publish!' do
    it 'publishes an unpublished record' do
      announcement = Fabricate(:announcement, published: false, scheduled_at: 10.days.from_now)

      announcement.publish!

      expect(announcement).to be_published
      expect(announcement.published_at).to_not be_nil
      expect(announcement.scheduled_at).to be_nil
    end
  end

  describe '#unpublish!' do
    it 'unpublishes a published record' do
      announcement = Fabricate(:announcement, published: true)

      announcement.unpublish!

      expect(announcement).to_not be_published
      expect(announcement.scheduled_at).to be_nil
    end
  end

  describe '#reactions' do
    context 'with announcement_reactions present' do
      let!(:account) { Fabricate(:account) }
      let!(:announcement) { Fabricate(:announcement) }
      let!(:announcement_reaction) { Fabricate(:announcement_reaction, announcement: announcement, created_at: 10.days.ago) }
      let!(:announcement_reaction_account) { Fabricate(:announcement_reaction, announcement: announcement, created_at: 5.days.ago, account: account) }

      before do
        Fabricate(:announcement_reaction)
      end

      it 'returns the announcement reactions for the announcement' do
        results = announcement.reactions

        expect(results.first.name).to eq(announcement_reaction.name)
        expect(results.last.name).to eq(announcement_reaction_account.name)
      end

      it 'returns the announcement reactions for the announcement limited to account' do
        results = announcement.reactions(account)

        expect(results.first.name).to eq(announcement_reaction.name)
      end
    end
  end

  describe '#statuses' do
    let(:announcement) { Fabricate(:announcement, status_ids: status_ids) }

    context 'with empty status_ids' do
      let(:status_ids) { nil }

      it 'returns empty array' do
        results = announcement.statuses

        expect(results).to eq([])
      end
    end

    context 'with relevant status_ids' do
      let(:status) { Fabricate(:status, visibility: :public) }
      let(:direct_status) { Fabricate(:status, visibility: :direct) }
      let(:status_ids) { [status.id, direct_status.id] }

      it 'returns public and unlisted statuses' do
        results = announcement.statuses

        expect(results).to include(status)
        expect(results).to_not include(direct_status)
      end
    end
  end
end
