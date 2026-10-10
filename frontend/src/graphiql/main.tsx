import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { GraphiQL } from 'graphiql'
import { createGraphiQLFetcher } from '@graphiql/toolkit'
import 'graphiql/style.css'
import { DEFAULT_QUERY, DEFAULT_VARIABLES } from './default-query'

// Same-origin endpoint: Rails serves this page and /graphql together.
const fetcher = createGraphiQLFetcher({ url: '/graphql' })

createRoot(document.getElementById('graphiql')!).render(
  <StrictMode>
    <GraphiQL fetcher={fetcher} defaultQuery={DEFAULT_QUERY} defaultEditorToolsVisibility="variables" variables={DEFAULT_VARIABLES} />
  </StrictMode>,
)
