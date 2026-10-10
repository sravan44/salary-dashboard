import { parse } from 'graphql'
import { DEFAULT_QUERY, DEFAULT_VARIABLES } from './default-query'

describe('GraphiQL starting query', () => {
  it('is valid GraphQL with one named operation', () => {
    const document = parse(DEFAULT_QUERY)

    expect(document.definitions).toHaveLength(1)
    expect(document.definitions[0]).toMatchObject({ kind: 'OperationDefinition', name: { value: 'Dashboard' } })
  })

  it('comes with valid JSON variables for its filters', () => {
    expect(JSON.parse(DEFAULT_VARIABLES)).toEqual({ filters: { country: 'US' } })
  })
})
