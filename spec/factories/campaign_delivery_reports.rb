# frozen_string_literal: true

FactoryBot.define do
  factory :campaign_delivery_report do
    association :campaign
    provider { 'resend' }
    status { 'pending' }
    total { 0 }
    succeeded { 0 }
    failed { 0 }
    delivery_errors { [] }
    started_at { nil }
    completed_at { nil }

    trait :running do
      status { 'running' }
      started_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :completed_with_errors do
      status { 'completed_with_errors' }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      failed { 1 }
    end
  end
end
