import { buildSchema, parse, validate } from 'graphql'
import { DEFAULT_QUERY } from '../graphiql/default-query'
import { DASHBOARD_CONVERTED, DASHBOARD_CURRENCY_DETAIL, DASHBOARD_OVERVIEW } from '../modules/dashboard/queries'
import sdl from './schema.graphql?raw'

// schema.graphql is generated from the Rails schema and checked by a backend spec, so these tests
// catch a query the server would reject before it ever reaches a browser.
const schema = buildSchema(sdl)

describe.each([
  ['DashboardOverview', DASHBOARD_OVERVIEW],
  ['DashboardCurrencyDetail', DASHBOARD_CURRENCY_DETAIL],
  ['DashboardConverted', DASHBOARD_CONVERTED],
  ['GraphiQL starting query', DEFAULT_QUERY],
])('%s', (_name, query) => {
  it('is valid against the server schema', () => {
    expect(validate(schema, parse(query)).map((error) => error.message)).toEqual([])
  })
})
