import { formatMoney } from './format-money'

describe('formatMoney', () => {
  it('formats an amount in its own currency, hiding .00', () => {
    expect(formatMoney('120000.00', 'USD')).toBe('$120,000')
    expect(formatMoney('2400000.00', 'INR')).toBe('₹2,400,000')
    expect(formatMoney('72000.00', 'EUR')).toBe('€72,000')
  })

  it('never shows two different currencies with the same symbol', () => {
    const dollars = ['USD', 'CAD', 'AUD', 'SGD'].map((currency) => formatMoney('1000.00', currency))

    expect(new Set(dollars).size).toBe(4)
    expect(formatMoney('83100.00', 'CAD')).toBe('CA$83,100')
    expect(formatMoney('83100.00', 'AUD')).toBe('A$83,100')
  })

  it('keeps cents when they exist', () => {
    expect(formatMoney('120000.50', 'USD')).toBe('$120,000.50')
  })
})
