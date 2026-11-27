import { useEffect, useState } from 'react'
import {
  Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer,
  Tooltip, XAxis, YAxis,
} from 'recharts'

type Task = {
  id: number; title: string; category: string; weight: number
  status: string; priority: string; notes: string; updated_at: string
}
type Problem = {
  id: number; title: string; severity: string; status: string
  detail: string; requested_from_user: string; updated_at: string
}
type Build = { id: number; label: string; status: string; detail: string; artifact: string; ts: string }
type Activity = { id: number; ts: string; level: string; source: string; message: string }
type State = {
  project: string; overall_progress: number
  counts: Record<string, number>
  by_category: { category: string; weight: number; progress: number; completed: number; total: number }[]
  current_activity: string; next_task: string
  last_successful_build: Build | null
  ipa: { ipa_exists: boolean; ipa_bytes: number; build_report_exists: boolean }
  on_iphone: boolean; fidelity: string; agent_state: string
  environment: Record<string, string | boolean | number>
  git: Record<string, unknown>
  repository: Record<string, unknown>
  audit: Record<string, unknown>
  legal: Record<string, unknown>
  tasks: Task[]; problems: Problem[]; critical_blockers: number
  activity: Activity[]; builds: Build[]
}

const statusColors: Record<string, string> = {
  'COMPLETED': '#22c55e', 'NEEDS TESTING': '#eab308',
  'IN PROGRESS': '#38bdf8', 'BLOCKED': '#ef4444', 'NOT STARTED': '#475569',
}

function Badge({ status }: { status: string }) {
  return <span className="badge" style={{ background: statusColors[status] ?? '#475569', color: '#08111f' }}>{status}</span>
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return <div className="card"><div className="mb-3 text-xs font-bold uppercase tracking-widest text-slate-400">{title}</div>{children}</div>
}

export default function App() {
  const [state, setState] = useState<State | null>(null)
  const [tab, setTab] = useState('overview')
  const [level, setLevel] = useState('ALL')
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    fetch('/api/state').then(r => r.json()).then(setState).catch(console.error)
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const ws = new WebSocket(`${proto}://${location.host}/ws`)
    ws.onopen = () => setConnected(true)
    ws.onclose = () => setConnected(false)
    ws.onmessage = e => {
      try {
        const msg = JSON.parse(e.data)
        if (msg.type === 'state') setState(msg.state)
      } catch { /* ignore malformed frames */ }
    }
    return () => ws.close()
  }, [])

  const agentAction = async (action: string) => {
    await fetch(`/api/agent/${action}`, { method: 'POST' })
    const s = await fetch('/api/state').then(r => r.json()); setState(s)
  }
  const patchTask = async (id: number, status: string) => {
    await fetch(`/api/tasks/${id}`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status }),
    })
    setState(await fetch('/api/state').then(r => r.json()))
  }
  const patchProblem = async (id: number, status: string) => {
    await fetch(`/api/problems/${id}`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status }),
    })
    setState(await fetch('/api/state').then(r => r.json()))
  }

  if (!state) return <div className="p-10 text-center text-slate-400">Loading control center…</div>

  const c = state.counts
  const pieData = Object.entries(c).map(([name, value]) => ({ name, value })).filter(d => d.value > 0)
  const bars = state.by_category.map(x => ({ name: x.category.replace(' & ', '/'), progress: x.progress }))

  return (
    <div className="min-h-screen p-4 md:p-8 max-w-7xl mx-auto">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black tracking-tight text-amber-300">DUNGEON KEEPER II — iOS PORT</h1>
          <p className="text-sm text-slate-400">Local development control center · real project data only</p>
        </div>
        <div className="flex items-center gap-2">
          <span className={`badge ${connected ? 'bg-emerald-500' : 'bg-red-500'} text-slate-950`}>
            WS {connected ? 'LIVE' : 'OFFLINE'}
          </span>
          <button className="badge bg-slate-700 hover:bg-slate-600" onClick={() => agentAction('pause')}>PAUSE AGENT</button>
          <button className="badge bg-slate-700 hover:bg-slate-600" onClick={() => agentAction('resume')}>RESUME AGENT</button>
          <a className="badge bg-slate-700 hover:bg-slate-600" href="/api/report/html" target="_blank">EXPORT REPORT</a>
        </div>
      </header>

      <Card title="Total progress (verified completion)">
        <div className="mb-2 flex items-baseline gap-3">
          <span className="text-4xl font-black text-amber-300">{state.overall_progress}%</span>
          <span className="text-xs text-slate-500">Agent: {state.agent_state}</span>
        </div>
        <div className="h-4 w-full overflow-hidden rounded bg-slate-800">
          <div className="h-full bg-gradient-to-r from-amber-600 to-amber-300 transition-all"
               style={{ width: `${state.overall_progress}%` }} />
        </div>
        <div className="mt-3 grid grid-cols-2 gap-2 text-sm md:grid-cols-5">
          {['COMPLETED', 'IN PROGRESS', 'NEEDS TESTING', 'BLOCKED', 'NOT STARTED'].map(k => (
            <div key={k} className="rounded border border-slate-700 p-2">
              <div className="text-lg font-bold">{c[k] ?? 0}</div>
              <div className="text-[10px] uppercase tracking-wide text-slate-400">{k}</div>
            </div>
          ))}
        </div>
      </Card>

      <div className="mt-4 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card title="Current activity"><p className="text-sm text-sky-300">{state.current_activity}</p></Card>
        <Card title="Next task"><p className="text-sm text-amber-200">{state.next_task}</p></Card>
        <Card title="Release status">
          <p className="text-sm">IPA: <b className={state.ipa.ipa_exists ? 'text-emerald-400' : 'text-red-400'}>{state.ipa.ipa_exists ? 'PRESENT' : 'ABSENT'}</b></p>
          <p className="text-sm">On iPhone: <b className="text-red-400">{String(state.on_iphone)}</b></p>
          <p className="text-sm">Fidelity: <b className="text-red-400">{state.fidelity}</b></p>
        </Card>
        <Card title="Last successful build">
          <p className="text-sm">{state.last_successful_build ? state.last_successful_build.label : 'NONE — no build has succeeded'}</p>
          <p className="mt-1 text-xs text-slate-500">Critical blockers: {state.critical_blockers}</p>
        </Card>
      </div>

      <nav className="mt-6 flex flex-wrap gap-2">
        {['overview', 'tasks', 'problems', 'build', 'activity'].map(t => (
          <button key={t} onClick={() => setTab(t)}
            className={`badge uppercase ${tab === t ? 'bg-amber-400 text-slate-950' : 'bg-slate-800 text-slate-300'}`}>{t}</button>
        ))}
      </nav>

      {tab === 'overview' && (
        <div className="mt-4 grid gap-4 lg:grid-cols-2">
          <Card title="Progress by category">
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={bars} layout="vertical" margin={{ left: 10 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
                <XAxis type="number" domain={[0, 100]} stroke="#64748b" />
                <YAxis type="category" dataKey="name" width={120} stroke="#64748b" tick={{ fontSize: 10 }} />
                <Tooltip />
                <Bar dataKey="progress" fill="#f59e0b" />
              </BarChart>
            </ResponsiveContainer>
          </Card>
          <Card title="Task status distribution">
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={pieData} dataKey="value" nameKey="name" outerRadius={100} label>
                  {pieData.map(p => <Cell key={p.name} fill={statusColors[p.name] ?? '#475569'} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </Card>
          <Card title="Environment (real host data)">
            <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
              {Object.entries(state.environment).map(([k, v]) => (
                <div key={k} className="flex justify-between gap-2 border-b border-slate-800 py-1">
                  <span className="text-slate-500">{k}</span><span className="truncate text-right">{String(v)}</span>
                </div>
              ))}
            </div>
          </Card>
          <Card title="Source & audit">
            <div className="space-y-1 text-xs">
              <div>Branch: <b>{String(state.git.branch ?? 'n/a')}</b> @ {String(state.git.head ?? 'n/a')}</div>
              <div>Commit: {String(state.git.commit_message ?? 'n/a')}</div>
              <div>Dirty files: {Array.isArray(state.git.dirty_files) ? state.git.dirty_files.length : 'n/a'}</div>
              <div>Java files: {String(state.repository.java_files ?? 'n/a')} · assets: {String(state.repository.asset_files ?? 'n/a')}</div>
              <div>Technical audit: {state.audit.available ? `present (${String(state.audit.bytes)} bytes)` : 'not written yet'}</div>
              <div>Legal report: {state.legal.available ? 'present' : 'not written yet'}</div>
            </div>
          </Card>
        </div>
      )}

      {tab === 'tasks' && (
        <div className="card mt-4">
          <table className="w-full text-left text-xs">
            <thead className="text-slate-400"><tr><th className="p-2">#</th><th>Task</th><th>Category</th><th>Priority</th><th>Status</th></tr></thead>
            <tbody>
              {state.tasks.map(t => (
                <tr key={t.id} className="border-t border-slate-800">
                  <td className="p-2 text-slate-500">{t.id}</td>
                  <td className="p-2">{t.title}{t.notes && <div className="text-[10px] text-slate-500">{t.notes}</div>}</td>
                  <td className="p-2 text-slate-400">{t.category}</td>
                  <td className="p-2 text-slate-400">{t.priority}</td>
                  <td className="p-2">
                    <select value={t.status} onChange={e => patchTask(t.id, e.target.value)}
                      className="rounded bg-slate-800 p-1 text-xs">
                      {Object.keys(statusColors).map(s => <option key={s}>{s}</option>)}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === 'problems' && (
        <div className="mt-4 space-y-3">
          {state.problems.map(p => (
            <div key={p.id} className="card">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-rose-300">{p.title}</h3>
                <Badge status={p.status === 'OPEN' ? 'BLOCKED' : 'COMPLETED'} />
              </div>
              <p className="mt-2 text-xs text-slate-400">{p.detail}</p>
              {p.requested_from_user && <p className="mt-2 text-xs text-amber-300">Needed from user: {p.requested_from_user}</p>}
              <select value={p.status} onChange={e => patchProblem(p.id, e.target.value)}
                className="mt-2 rounded bg-slate-800 p-1 text-xs">
                <option>OPEN</option><option>IN PROGRESS</option><option>RESOLVED</option>
              </select>
            </div>
          ))}
        </div>
      )}

      {tab === 'build' && (
        <div className="card mt-4">
          <p className="text-sm text-slate-400">No IPA has been built. Builds appear here only when a real command succeeds.</p>
          <p className="mt-2 text-sm">IPA path expected: <code>output/DungeonKeeperII.ipa</code> — currently <b>{state.ipa.ipa_exists ? 'present' : 'absent'}</b>.</p>
          <p className="mt-2 text-sm">Last build: {state.last_successful_build?.label ?? 'none'}</p>
        </div>
      )}

      {tab === 'activity' && (
        <div className="card mt-4">
          <div className="mb-3 flex gap-2">
            {['ALL', 'SUCCESS', 'ERRORS', 'WARNINGS', 'BUILD', 'TESTING', 'SOURCE CODE', 'PERFORMANCE'].map(l => (
              <button key={l} onClick={() => setLevel(l)}
                className={`badge ${level === l ? 'bg-amber-400 text-slate-950' : 'bg-slate-800'}`}>{l}</button>
            ))}
          </div>
          <div className="space-y-1 font-mono text-xs">
            {state.activity.filter(a => level === 'ALL' || a.level === level).map(a => (
              <div key={a.id} className="border-b border-slate-800 py-1">
                <span className="text-slate-500">[{a.ts}]</span>{' '}
                <span className={a.level === 'ERROR' ? 'text-rose-400' : 'text-emerald-400'}>{a.level}</span>{' '}
                <span className="text-sky-400">{a.source}</span>: {a.message}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
