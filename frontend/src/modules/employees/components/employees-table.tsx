import { Anchor, Badge, Table, UnstyledButton } from '@mantine/core'
import { Link } from 'react-router-dom'
import { formatMoney } from '../../../shared/format-money'
import type { EmployeeSummary } from '../types'

type SortProps = { sort: string; onSort: (field: string) => void; salarySortable: boolean }

const COLUMNS: { field?: string; label: string }[] = [
  { field: 'employee_number', label: 'Employee no.' },
  { field: 'full_name', label: 'Name' },
  { label: 'Country' },
  { label: 'Department' },
  { label: 'Job title' },
  { field: 'hire_date', label: 'Hire date' },
  { label: 'Status' },
  { field: 'salary', label: 'Salary' },
]

export function EmployeesTable({ employees, ...sortProps }: { employees: EmployeeSummary[] } & SortProps) {
  return (
    <Table striped highlightOnHover aria-label="Employees" mt="md">
      <Table.Thead>
        <Table.Tr>
          {COLUMNS.map((column) => (
            <SortableHeader key={column.label} {...column} {...sortProps} />
          ))}
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>
        {employees.map((employee) => (
          <Table.Tr key={employee.id}>
            <Table.Td>{employee.employee_number}</Table.Td>
            <Table.Td>
              <Anchor component={Link} to={`/employees/${employee.id}`}>
                {employee.full_name}
              </Anchor>
            </Table.Td>
            <Table.Td>{employee.country_code}</Table.Td>
            <Table.Td>{employee.department}</Table.Td>
            <Table.Td>{employee.job_title}</Table.Td>
            <Table.Td>{employee.hire_date}</Table.Td>
            <Table.Td>
              <Badge variant="light" color={employee.status === 'active' ? 'teal' : 'gray'}>
                {employee.status}
              </Badge>
            </Table.Td>
            <Table.Td ta="right">
              {employee.current_salary ? formatMoney(employee.current_salary.amount, employee.current_salary.currency) : '—'}
            </Table.Td>
          </Table.Tr>
        ))}
      </Table.Tbody>
    </Table>
  )
}

function SortableHeader({ field, label, sort, onSort, salarySortable }: { field?: string; label: string } & SortProps) {
  const sortable = field !== undefined && (field !== 'salary' || salarySortable)
  const direction = sort === field ? 'ascending' : sort === `-${field}` ? 'descending' : 'none'
  const arrow = direction === 'ascending' ? ' ↑' : direction === 'descending' ? ' ↓' : ''

  return (
    <Table.Th aria-sort={sortable ? direction : undefined} ta={field === 'salary' ? 'right' : undefined}>
      {sortable ? (
        <UnstyledButton aria-label={`Sort by ${label}`} fw={600} fz="sm" onClick={() => onSort(field!)}>
          {label}
          {arrow}
        </UnstyledButton>
      ) : (
        <span title={field === 'salary' ? 'Choose a currency to sort by salary' : undefined}>{label}</span>
      )}
    </Table.Th>
  )
}
