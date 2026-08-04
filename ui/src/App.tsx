import { useAppInfo } from '@kirocrew/app-sdk'
import { Card, CardTitle, PageHeader, Badge, StatCard } from '@kirocrew/app-sdk/ui'


const AGENTS = [
  { name: 'kodama', role: 'Orchestrator', icon: '🌳' },
  { name: 'kodama-scout', role: 'Reconnaissance', icon: '🔍' },
  { name: 'kodama-scholar', role: 'Research', icon: '📚' },
  { name: 'kodama-sage', role: 'Reasoning', icon: '🧠' },
  { name: 'kodama-artist', role: 'UI/UX', icon: '🎨' },
  { name: 'kodama-smith', role: 'Implementation', icon: '⚒️' },
  { name: 'kodama-critic', role: 'Review', icon: '🔬' },
  { name: 'kodama-forge', role: 'Infrastructure', icon: '🔥' },
  { name: 'kodama-scribe', role: 'Documentation', icon: '✍️' },
]

export default function KodamaSettings() {
  const appInfo = useAppInfo()

  return (
    <>
      <PageHeader
        title="🌳 Kodama"
        subtitle="Portable multi-agent pack"
      />
      <div className="px-6 pb-8 overflow-y-auto flex-1 min-h-0">
        {/* Stats row */}
        <div className="grid gap-3.5 grid-cols-[repeat(auto-fit,minmax(150px,1fr))] mb-6">
          <StatCard label="Version" value={appInfo?.version ?? '0.8.0'} />
          <StatCard label="Agents" value="9" accent />
          <StatCard label="Skills" value="3" />
        </div>



        {/* Getting started */}
        <Card>
          <CardTitle>Getting Started</CardTitle>
          <div className="py-3 space-y-2">
            <p className="text-sm text-muted">To use Kodama in Crew:</p>
            <div className="text-sm text-muted space-y-1.5">
              <div className="flex gap-2"><span className="text-foreground w-4 shrink-0">1.</span><span>Go to <span className="font-medium text-foreground">Sessions</span></span></div>
              <div className="flex gap-2"><span className="text-foreground w-4 shrink-0">2.</span><span>Start a <span className="font-medium text-foreground">New Session</span></span></div>
              <div className="flex gap-2"><span className="text-foreground w-4 shrink-0">3.</span><span>Change the agent from <span className="font-mono text-xs bg-muted/50 px-1 py-0.5 rounded">default</span> to <span className="font-mono text-xs bg-muted/50 px-1 py-0.5 rounded">kodama</span></span></div>
              <div className="flex gap-2"><span className="text-foreground w-4 shrink-0">4.</span><span>Start chatting — Kodama will delegate to specialists automatically</span></div>
            </div>
          </div>
        </Card>

        {/* Agent roster */}
        <Card>
          <CardTitle>Agent Roster</CardTitle>
          <div className="divide-y divide-border">
            {AGENTS.map((agent) => (
              <div key={agent.name} className="flex items-center gap-3 py-3">
                <span className="text-lg">{agent.icon}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-mono truncate">{agent.name}</p>
                  <p className="text-xs text-muted">{agent.role}</p>
                </div>
                <Badge>{agent.name === 'kodama' ? 'orchestrator' : 'specialist'}</Badge>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  )
}
