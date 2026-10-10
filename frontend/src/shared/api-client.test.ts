import { http, HttpResponse } from 'msw'
import { server } from '../test/api-mock'
import { ApiError, getJson } from './api-client'

describe('getJson', () => {
  it('turns an API error body into an ApiError with code, message and field details', async () => {
    server.use(
      http.get('*/api/v1/broken', () =>
        HttpResponse.json({ error: { code: 'invalid_parameters', message: 'Bad sort', details: { sort: ['nope'] } } }, { status: 400 }),
      ),
    )

    const error = await getJson('/api/v1/broken').catch((e: unknown) => e)

    expect(error).toBeInstanceOf(ApiError)
    expect(error).toMatchObject({ status: 400, code: 'invalid_parameters', message: 'Bad sort', details: { sort: ['nope'] } })
  })

  it('still gives a readable error when the server returns a non-JSON page (e.g. a gateway error)', async () => {
    server.use(http.get('*/api/v1/down', () => new HttpResponse('<html>Bad Gateway</html>', { status: 502 })))

    const error = await getJson('/api/v1/down').catch((e: unknown) => e)

    expect(error).toMatchObject({ status: 502, code: 'http_error', message: 'Request failed (502)', details: {} })
  })
})
