import { Alert, Badge, Button, Center, Group, Loader, Modal, MultiSelect, Paper, PasswordInput, Stack, Table, Text, TextInput, Title } from '@mantine/core'
import { useMemo } from 'react'
import { useState, type FormEvent } from 'react'
import { ApiError } from '../../shared/api-client'
import { ROLE_LABELS } from '../auth/types'
import { generalError } from '../auth/password-errors'
import { NewPasswordFields } from '../auth/password-fields'
import { useCreateUser, useSendPasswordLinks, useSetUserPassword, useUpdateRoles, useUsers, type UserRow } from './api'

const ROLE_OPTIONS = Object.entries(ROLE_LABELS).map(([value, label]) => ({ value, label }))
const ROLE_ORDER = Object.keys(ROLE_LABELS)
/** Roles in a fixed order, so the same set always looks (and is sent) the same. */
const ordered = (roles: string[]) => ROLE_ORDER.filter((role) => roles.includes(role))

const fieldErrors = (error: unknown) => (error instanceof ApiError ? error.details : {})
const LABELS: Record<string, string> = { email: 'Email', roles: 'Roles', password: 'Password' }
const capitalised = (text?: string) => text && text[0].toUpperCase() + text.slice(1)
const describe = (error: unknown, key: string) => fieldErrors(error)[key] && `${LABELS[key]} ${fieldErrors(error)[key].join(', ')}`

const PASSWORD_STATUS_OPTIONS = [
  { value: 'set', label: 'Set' },
  { value: 'invited', label: 'Invited (no password yet)' },
]
const MAX_LINKS = 50

type Filters = { query: string; roles: string[]; status: string[] }
const NO_FILTERS: Filters = { query: '', roles: [], status: [] }

/** OR within a filter, AND across filters (as in the employee directory). */
function matches(user: UserRow, { query, roles, status }: Filters) {
  return (
    user.email.includes(query.trim().toLowerCase()) &&
    (roles.length === 0 || roles.some((role) => user.roles.includes(role))) &&
    (status.length === 0 || status.includes(user.password_set ? 'set' : 'invited'))
  )
}

/**
 * Admin only: add accounts, change roles, and manage passwords. A user may hold several roles; access is their
 * union. No password is ever emailed: the Admin sends password links (set-password or reset) to chosen users.
 */
export function UsersPage() {
  const users = useUsers()
  const [filters, setFilters] = useState<Filters>(NO_FILTERS)
  const shown = useMemo(() => (users.data ?? []).filter((user) => matches(user, filters)), [users.data, filters])

  return (
    <Stack gap="md">
      <Title order={2}>Users</Title>
      <AddUserForm />
      {users.isPending ? (
        <Center p="xl">
          <Loader aria-label="Loading users" />
        </Center>
      ) : users.isError ? (
        <Alert color="red" role="alert">
          {users.error.message}
        </Alert>
      ) : (
        <Paper withBorder p="md">
          <Stack gap="sm">
            <UserFilters filters={filters} onChange={setFilters} />
            <SendPasswordLinks users={users.data} shown={shown} />
            <Text size="sm" c="dimmed">
              Showing {shown.length} of {users.data.length} users
            </Text>
            <Table aria-label="Users" verticalSpacing="sm">
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>Email</Table.Th>
                  <Table.Th>Current roles</Table.Th>
                  <Table.Th>Change roles</Table.Th>
                  <Table.Th />
                  <Table.Th>Password</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {shown.map((user) => (
                  <UserRowEditor key={user.id} user={user} />
                ))}
              </Table.Tbody>
            </Table>
          </Stack>
        </Paper>
      )}
    </Stack>
  )
}

function UserRowEditor({ user }: { user: UserRow }) {
  const [roles, setRoles] = useState(user.roles)
  const update = useUpdateRoles(user.id)
  const changed = ordered(roles).join() !== ordered(user.roles).join()

  return (
    <Table.Tr>
      <Table.Td>{user.email}</Table.Td>
      <Table.Td>
        <Group gap={4}>
          {user.roles.map((role) => (
            <Badge key={role} variant="light">
              {ROLE_LABELS[role] ?? role}
            </Badge>
          ))}
        </Group>
      </Table.Td>
      <Table.Td>
        <MultiSelect
          aria-label={`Roles for ${user.email}`}
          data={ROLE_OPTIONS}
          value={roles}
          onChange={(next) => {
            update.reset()
            setRoles(next)
          }}
          error={capitalised(fieldErrors(update.error).roles?.join(', '))}
          miw={260}
        />
      </Table.Td>
      <Table.Td>
        <Group gap="xs" wrap="nowrap">
          <Button size="xs" disabled={!changed} loading={update.isPending} onClick={() => update.mutate(ordered(roles))}>
            Save
          </Button>
          {update.isSuccess && !changed && (
            <Text size="sm" c="teal">
              Saved
            </Text>
          )}
          {update.isError && !(update.error instanceof ApiError && Object.keys(update.error.details).length) && (
            <Text size="sm" c="red">
              {update.error.message}
            </Text>
          )}
        </Group>
      </Table.Td>
      <Table.Td>
        <PasswordActions user={user} />
      </Table.Td>
    </Table.Tr>
  )
}

function UserFilters({ filters, onChange }: { filters: Filters; onChange: (next: Filters) => void }) {
  const active = filters.query !== '' || filters.roles.length > 0 || filters.status.length > 0
  return (
    <Group align="flex-end" role="search" aria-label="Filter users">
      <TextInput label="Search email" placeholder="e.g. priya" value={filters.query} onChange={(e) => onChange({ ...filters, query: e.currentTarget.value })} />
      <MultiSelect label="Filter by role" placeholder="Any role" data={ROLE_OPTIONS} value={filters.roles} onChange={(roles) => onChange({ ...filters, roles })} miw={220} />
      <MultiSelect
        label="Filter by password"
        placeholder="Any"
        data={PASSWORD_STATUS_OPTIONS}
        value={filters.status}
        onChange={(status) => onChange({ ...filters, status })}
        miw={220}
      />
      {active && (
        <Button variant="subtle" onClick={() => onChange(NO_FILTERS)}>
          Clear filters
        </Button>
      )}
    </Group>
  )
}

/**
 * Choose users (or everyone currently shown) and email each one a password link: a set-password link to anyone
 * without a password yet, a reset link to anyone with one. Nothing is sent when a user is created.
 */
function SendPasswordLinks({ users, shown }: { users: UserRow[]; shown: UserRow[] }) {
  const send = useSendPasswordLinks()
  const [chosen, setChosen] = useState<string[]>([])
  const options = users.map((user) => ({ value: String(user.id), label: user.password_set ? user.email : `${user.email} (invited)` }))
  const choose = (ids: string[]) => {
    send.reset()
    setChosen(ids)
  }

  return (
    <Stack gap={4}>
      <Group align="flex-end">
        <MultiSelect
          label="Send a password link to"
          placeholder="Choose users"
          description="Invited users get a link to set their password (24 h); others a reset link (2 h)"
          data={options}
          value={chosen}
          onChange={choose}
          maxValues={MAX_LINKS}
          searchable
          miw={360}
        />
        <Button variant="default" disabled={shown.length === 0} onClick={() => choose(shown.slice(0, MAX_LINKS).map((user) => String(user.id)))}>
          Choose everyone shown
        </Button>
        <Button
          disabled={chosen.length === 0}
          loading={send.isPending}
          onClick={() => send.mutate(chosen.map(Number), { onSuccess: () => setChosen([]) })}
        >
          Send password link
        </Button>
      </Group>
      {send.isSuccess && (
        <Text size="sm" c="teal" role="status">
          Password link sent to {send.data === 1 ? '1 user' : `${send.data} users`}
        </Text>
      )}
      {send.isError && (
        <Text size="sm" c="red" role="alert">
          {send.error.message}
        </Text>
      )}
    </Stack>
  )
}

/** Password status, and setting it directly (links are sent in bulk, above the table). */
function PasswordActions({ user }: { user: UserRow }) {
  const [setting, setSetting] = useState(false)
  const [notice, setNotice] = useState<string | null>(null)

  return (
    <Stack gap={4}>
      <Group gap="xs" wrap="nowrap">
        <Badge variant="light" color={user.password_set ? 'teal' : 'yellow'}>
          {user.password_set ? 'Set' : 'Invited'}
        </Badge>
        <Button
          size="compact-xs"
          variant="subtle"
          onClick={() => {
            setNotice(null)
            setSetting(true)
          }}
        >
          Set password
        </Button>
      </Group>
      {notice && (
        <Text size="xs" c="teal" role="status">
          {notice}
        </Text>
      )}
      <SetPasswordModal
        user={user}
        opened={setting}
        onClose={() => setSetting(false)}
        onDone={() => {
          setSetting(false)
          setNotice(`Password set for ${user.email}; they’ve been signed out everywhere`)
        }}
      />
    </Stack>
  )
}

function SetPasswordModal({ user, opened, onClose, onDone }: { user: UserRow; opened: boolean; onClose: () => void; onDone: () => void }) {
  const save = useSetUserPassword(user.id)
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const close = () => {
    save.reset()
    setPassword('')
    setConfirmation('')
    onClose()
  }

  const submit = (event: FormEvent) => {
    event.preventDefault()
    save.mutate(
      { password, password_confirmation: confirmation },
      {
        onSuccess: () => {
          setPassword('')
          setConfirmation('')
          onDone()
        },
      },
    )
  }

  return (
    <Modal opened={opened} onClose={close} title={`Set a password for ${user.email}`}>
      <form onSubmit={submit} noValidate>
        <Stack>
          <Text size="sm" c="dimmed">
            Share it with them securely. They’ll be signed out everywhere and can change it later.
          </Text>
          {generalError(save.error) && (
            <Alert color="red" role="alert">
              {generalError(save.error)}
            </Alert>
          )}
          <NewPasswordFields password={password} confirmation={confirmation} onPassword={setPassword} onConfirmation={setConfirmation} error={save.error} />
          <Group justify="flex-end">
            <Button variant="default" onClick={close}>
              Cancel
            </Button>
            <Button type="submit" loading={save.isPending}>
              Save password
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}

function AddUserForm() {
  const create = useCreateUser()
  const [email, setEmail] = useState('')
  const [roles, setRoles] = useState<string[]>([])
  const [password, setPassword] = useState('')
  const [added, setAdded] = useState<string | null>(null)

  const submit = (event: FormEvent) => {
    event.preventDefault()
    setAdded(null)
    create.mutate(
      { email, roles: ordered(roles), password },
      {
        onSuccess: (user) => {
          setAdded(user.password_set ? `Added ${user.email}` : `Added ${user.email}. They have no password yet: send them a password link when ready.`)
          setEmail('')
          setRoles([])
          setPassword('')
        },
      },
    )
  }
  const general = create.isError && Object.keys(fieldErrors(create.error)).length === 0 ? create.error.message : null

  return (
    <Paper withBorder p="md">
      <form onSubmit={submit} noValidate>
        <Stack gap="sm">
          <Title order={4}>Add a user</Title>
          {general && (
            <Alert color="red" role="alert">
              {general}
            </Alert>
          )}
          {added && (
            <Alert color="teal">
              {added}
            </Alert>
          )}
          <Group align="flex-start" grow>
            <TextInput label="Email" type="email" value={email} error={describe(create.error, 'email')} onChange={(e) => setEmail(e.currentTarget.value)} />
            <MultiSelect label="Roles" placeholder="Choose one or more" data={ROLE_OPTIONS} value={roles} error={describe(create.error, 'roles')} onChange={setRoles} />
            <PasswordInput
              label="First password (optional)"
              description="Leave empty to send them a password link later"
              value={password}
              error={describe(create.error, 'password')}
              onChange={(e) => setPassword(e.currentTarget.value)}
            />
          </Group>
          <Group>
            <Button type="submit" loading={create.isPending}>
              Add user
            </Button>
          </Group>
        </Stack>
      </form>
    </Paper>
  )
}
