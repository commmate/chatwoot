# frozen_string_literal: true

class Resend::BatchSenderService
  BATCH_SIZE = 100

  def initialize(client:)
    @client = client
  end

  # Sends all entries, routing to batch or individual API based on attachments.
  # Rate limiting is handled globally by Resend::RateLimiter inside Client#request.
  #
  # @param entries [Array<Hash>] Each entry has :payload (Resend email hash) and :meta (caller context)
  # @yield [entry, result] Called for each entry after sending
  # @yieldparam entry [Hash] The original entry
  # @yieldparam result [Hash] { ok: true, email_id: } or { ok: false, error_code:, error_message: }
  def send_all(entries, &)
    with_attachments, without_attachments = entries.partition { |e| e[:payload][:attachments].present? }

    send_in_batches(without_attachments, &) if without_attachments.any?
    send_individually(with_attachments, &) if with_attachments.any?
  end

  private

  def send_in_batches(entries, &)
    entries.each_slice(BATCH_SIZE) do |chunk|
      send_chunk(chunk, &)
    end
  end

  def send_individually(entries, &)
    entries.each do |entry|
      send_single(entry, &)
    end
  end

  def send_chunk(chunk)
    payloads = chunk.map { |entry| entry[:payload] }
    response = @client.send_batch(emails: payloads, priority: :normal)
    ids = response['data'] || []

    chunk.each_with_index do |entry, i|
      email_id = ids.dig(i, 'id')
      yield entry, { ok: true, email_id: email_id }
    end
  rescue Resend::Client::ApiError => e
    Rails.logger.error("[Resend::BatchSenderService] Batch API error: #{e.message}")
    chunk.each do |entry|
      yield entry, { ok: false, error_code: e.error_code, error_message: e.message }
    end
  rescue StandardError => e
    Rails.logger.error("[Resend::BatchSenderService] Unexpected error: #{e.message}")
    chunk.each do |entry|
      yield entry, { ok: false, error_code: nil, error_message: e.message }
    end
  end

  def send_single(entry)
    payload = entry[:payload]
    response = @client.send_email(**payload, priority: :normal)
    yield entry, { ok: true, email_id: response['id'] }
  rescue Resend::Client::ApiError => e
    Rails.logger.error("[Resend::BatchSenderService] Single send error: #{e.message}")
    yield entry, { ok: false, error_code: e.error_code, error_message: e.message }
  rescue StandardError => e
    Rails.logger.error("[Resend::BatchSenderService] Unexpected error: #{e.message}")
    yield entry, { ok: false, error_code: nil, error_message: e.message }
  end
end
