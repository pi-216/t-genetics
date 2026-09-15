# frozen_string_literal: true

# Step definitions for issue #172 — template-parity force-live Turbo/Stimulus
# wiring. Both steps are @javascript (feature tag): Stimulus boot and element
# connection exist only in a real browser executing the served JS, so a
# request-layer green here would be the exact dead-Turbo failure the
# elo-picker incident shipped.

Then(/^the page body enables page morphing$/) do
  morph = page.evaluate_script("document.body.hasAttribute('data-turbo-morph')")
  expect(morph).to be(true)
end

Then(/^a Stimulus controller element receives its connected behavior$/) do
  # Dead-Stimulus regression: if the importmap pins, application.js, or the
  # controllers dir never load, window.Stimulus is undefined and the probe can
  # never connect. A dynamic-import probe uses the real Controller base class
  # (a bare object gets no this.element from Stimulus), then polls via the
  # async-completion callback until Stimulus's MutationObserver has connected
  # it. A result string keeps a JS boot failure readable instead of nil.
  result = page.evaluate_async_script(<<~JS)
    const done = arguments[arguments.length - 1]
    ;(async () => {
      try {
        if (typeof window.Stimulus === 'undefined') return done('no-stimulus')
        const { Controller } = await import('@hotwired/stimulus')
        window.Stimulus.register('probe', class extends Controller {
          connect() { this.element.dataset.connected = 'true' }
        })
        const el = document.createElement('div')
        el.setAttribute('data-controller', 'probe')
        document.body.appendChild(el)
        for (let i = 0; i < 100 && el.dataset.connected !== 'true'; i++) {
          await new Promise(r => setTimeout(r, 20))
        }
        done(el.dataset.connected === 'true')
      } catch (e) {
        done('error: ' + e.message)
      }
    })()
  JS

  expect(result).to be(true)
end
