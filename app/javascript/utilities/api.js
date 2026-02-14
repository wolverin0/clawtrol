// Shared fetch utility with CSRF token and error handling
export function fetchAPI(url, options = {}) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

  const defaults = {
    headers: {
      'X-CSRF-Token': csrfToken,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    },
    credentials: 'same-origin'
  }

  // Merge headers
  const mergedHeaders = { ...defaults.headers, ...(options.headers || {}) }
  const mergedOptions = { ...defaults, ...options, headers: mergedHeaders }

  // Don't set Content-Type for FormData
  if (options.body instanceof FormData) {
    delete mergedHeaders['Content-Type']
  }

  // Auto-stringify body if object
  if (mergedOptions.body && typeof mergedOptions.body === 'object' && !(mergedOptions.body instanceof FormData)) {
    mergedOptions.body = JSON.stringify(mergedOptions.body)
  }

  return fetch(url, mergedOptions).then(response => {
    if (!response.ok) {
      return response.json().catch(() => ({})).then(data => {
        throw Object.assign(new Error(data.error || `HTTP ${response.status}`), { status: response.status, data })
      })
    }

    const contentType = response.headers.get('content-type') || ''
    if (contentType.includes('application/json')) {
      return response.json()
    }
    if (contentType.includes('turbo-stream')) {
      return response.text().then(html => {
        if (window.Turbo) Turbo.renderStreamMessage(html)
        return html
      })
    }
    return response.text()
  })
}

// Convenience methods
export const getJSON = (url) => fetchAPI(url, { method: 'GET' })
export const postJSON = (url, body) => fetchAPI(url, { method: 'POST', body })
export const patchJSON = (url, body) => fetchAPI(url, { method: 'PATCH', body })
export const deleteJSON = (url) => fetchAPI(url, { method: 'DELETE' })
