import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'

/** Opens the multi-select labelled `label`, picks each option by its visible name, then closes it. */
export async function chooseOptions(label: string, ...options: string[]) {
  await userEvent.click(screen.getByRole('textbox', { name: label }))
  for (const name of options) await userEvent.click(await screen.findByRole('option', { name }))
  await userEvent.keyboard('{Escape}')
}

/** The values shown as pills inside the multi-select labelled `label`. */
export function selectedOptions(label: string) {
  const root = screen.getByRole('textbox', { name: label }).closest('.mantine-MultiSelect-root')
  return Array.from(root?.querySelectorAll('.mantine-MultiSelect-pill') ?? []).map((pill) => pill.textContent)
}
