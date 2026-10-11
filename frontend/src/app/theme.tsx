import { CheckboxIndicator, createTheme, Group, MultiSelect, type ComboboxItem, type ComboboxLikeRenderOptionInput } from '@mantine/core'

// Each multi-select option shows a checkbox, ticked when it is chosen, so several choices read as a checklist.
// The checkbox is only a picture of the option's state (no form control): clicks go to the option, and screen
// readers hear the option's own "selected" state, so it is hidden from them to avoid announcing it twice.
function checkboxOption({ option, checked }: ComboboxLikeRenderOptionInput<ComboboxItem>) {
  return (
    <Group gap="sm" wrap="nowrap">
      <CheckboxIndicator checked={checked} size="xs" aria-hidden />
      <span>{option.label}</span>
    </Group>
  )
}

export const theme = createTheme({
  components: {
    MultiSelect: MultiSelect.extend({ defaultProps: { renderOption: checkboxOption, withCheckIcon: false } }),
  },
})
