# frozen_string_literal: true

# Process-global rate limiter for Resend API requests.
# Adapts automatically to Resend's rate limit headers (ratelimit-limit, ratelimit-remaining,
# ratelimit-reset, retry-after) so if the plan changes, no code update is needed.
#
# Supports two priority levels:
#   :high   — Interactive/live requests (domain management, inbox setup, conversation replies).
#             Skips the pre-wait so the user isn't blocked by background batch sends.
#             Still updates next_allowed_at to keep background sends spaced.
#   :normal — Background batch sends. Waits for the full interval before proceeding.
#
# Both priorities share the same next_allowed_at timestamp so they stay coordinated.
# High-priority requests that coincide with a batch send may hit 429, but
# Client#request auto-retries once using the retry-after header.
class Resend::RateLimiter
  FALLBACK_INTERVAL = 0.55
  DEFAULT_RETRY_AFTER = 2.0
  SAFETY_MARGIN = 1.1

  @mutex = Mutex.new
  @next_allowed_at = 0.0
  @interval = FALLBACK_INTERVAL

  class << self
    def throttle!(priority: :normal)
      @mutex.synchronize do
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        if priority == :high
          Rails.logger.debug { '[Resend RateLimiter] High-priority request, skipping wait' }
        else
          wait = @next_allowed_at - now
          if wait > 0
            Rails.logger.debug { "[Resend RateLimiter] Throttling for #{wait.round(3)}s (interval=#{@interval.round(3)}s)" }
            sleep(wait)
          end
        end

        @next_allowed_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @interval
      end
    end

    # Called after every successful response to adapt pacing from ratelimit-* headers.
    def update_from_headers!(headers)
      return unless headers

      limit = headers['ratelimit-limit']
      return unless limit

      limit_val = limit.to_f
      return unless limit_val > 0

      new_interval = (1.0 / limit_val) * SAFETY_MARGIN

      @mutex.synchronize do
        if (@interval - new_interval).abs > 0.01
          Rails.logger.info("[Resend RateLimiter] Adapted interval: #{@interval.round(3)}s -> #{new_interval.round(3)}s (limit=#{limit_val.to_i} req/s)")
          @interval = new_interval
        end
      end
    end

    def backoff!(retry_after)
      @mutex.synchronize do
        delay = (retry_after || DEFAULT_RETRY_AFTER).to_f
        Rails.logger.info("[Resend RateLimiter] Backing off for #{delay}s (retry-after)")
        @next_allowed_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + delay
      end
    end

    def reset!
      @mutex.synchronize do
        @next_allowed_at = 0.0
        @interval = FALLBACK_INTERVAL
      end
    end

    def current_interval
      @interval
    end
  end
end
