import { ApiError } from './api-client'

type GraphqlBody<T> = { data?: T; errors?: { message: string }[] }

/** POST a GraphQL operation to the same-origin /graphql endpoint. Any GraphQL error becomes an ApiError. */
export async function graphqlRequest<T>(query: string, variables: Record<string, unknown> = {}): Promise<T> {
  const response = await fetch(new URL('/graphql', window.location.origin), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ query, variables }),
  })
  const body = (await response.json().catch(() => ({}))) as GraphqlBody<T>

  if (body.errors?.length) {
    throw new ApiError(response.status, 'graphql_error', body.errors.map((error) => error.message).join('; '))
  }
  if (!response.ok || !body.data) throw new ApiError(response.status, 'http_error', `Request failed (${response.status})`)
  return body.data
}
