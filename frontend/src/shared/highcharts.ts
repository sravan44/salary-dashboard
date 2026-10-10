import Highcharts from 'highcharts/esm/highcharts.js'
import 'highcharts/esm/highcharts-more.js' // columnrange (pay ranges)
import 'highcharts/esm/modules/accessibility.js' // keyboard navigation and screen-reader descriptions

// Highcharts is free for personal/non-commercial use; commercial use needs a licence (docs/rejected-suggestions.md).
Highcharts.setOptions({
  lang: { thousandsSep: ',' },
  chart: { style: { fontFamily: 'inherit' }, backgroundColor: 'transparent' },
  title: { text: undefined },
  credits: { enabled: true },
})

export { Highcharts }

/** Single-series colour: dataviz reference slot 1, validated (ALL CHECKS PASS). */
export const SERIES_COLOR = '#2a78d6'
export const MUTED_MARK = '#c9c8c1'
export const SURFACE = '#ffffff'
/** Dataviz reference categorical order, assigned in fixed order (used by the pie: at most 8 countries). */
export const CATEGORICAL = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#6250d6', '#e34948']
