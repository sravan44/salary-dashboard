import { graphql, http, HttpResponse } from 'msw'
import { server } from '../test/api-mock'
import { graphqlRequest } from './graphql-client'

describe('graphqlRequest', () => {
  it('returns data and sends the variables', async () => {
    let received: unknown
    server.use(
      graphql.query('Ping', ({ variables }) => {
        received = variables
        return HttpResponse.json({ data: { ping: 'pong' } })
      }),
    )

    await expect(graphqlRequest('query Ping($x: Int) { ping }', { x: 1 })).resolves.toEqual({ ping: 'pong' })
    expect(received).toEqual({ x: 1 })
  })

  it('turns GraphQL errors into one readable error', async () => {
    server.use(graphql.query('Ping', () => HttpResponse.json({ errors: [{ message: 'first' }, { message: 'second' }] })))

    await expect(graphqlRequest('query Ping { ping }')).rejects.toMatchObject({ code: 'graphql_error', message: 'first; second' })
  })

  it('reports a failed HTTP response that has no GraphQL body (e.g. a gateway error)', async () => {
    server.use(http.post('*/graphql', () => new HttpResponse('<html>Bad Gateway</html>', { status: 502 })))

    await expect(graphqlRequest('query Ping { ping }')).rejects.toMatchObject({ status: 502, code: 'http_error', message: 'Request failed (502)' })
  })
})
