import { jsxs as a, Fragment as l, jsx as e } from "react/jsx-runtime";
import { useAppInfo as o } from "@kirocrew/app-sdk";
import { PageHeader as c, StatCard as r, Card as t, CardTitle as i, Badge as d } from "@kirocrew/app-sdk/ui";
const m = [
  { name: "kodama", role: "Orchestrator", icon: "🌳" },
  { name: "kodama-scout", role: "Reconnaissance", icon: "🔍" },
  { name: "kodama-scholar", role: "Research", icon: "📚" },
  { name: "kodama-sage", role: "Reasoning", icon: "🧠" },
  { name: "kodama-artist", role: "UI/UX", icon: "🎨" },
  { name: "kodama-smith", role: "Implementation", icon: "⚒️" },
  { name: "kodama-critic", role: "Review", icon: "🔬" },
  { name: "kodama-forge", role: "Infrastructure", icon: "🔥" },
  { name: "kodama-scribe", role: "Documentation", icon: "✍️" }
];
function x() {
  const s = o();
  return /* @__PURE__ */ a(l, { children: [
    /* @__PURE__ */ e(
      c,
      {
        title: "🌳 Kodama",
        subtitle: "Portable multi-agent pack"
      }
    ),
    /* @__PURE__ */ a("div", { className: "px-6 pb-8 overflow-y-auto flex-1 min-h-0", children: [
      /* @__PURE__ */ a("div", { className: "grid gap-3.5 grid-cols-[repeat(auto-fit,minmax(150px,1fr))] mb-6", children: [
        /* @__PURE__ */ e(r, { label: "Version", value: (s == null ? void 0 : s.version) ?? "0.8.0" }),
        /* @__PURE__ */ e(r, { label: "Agents", value: "9", accent: !0 }),
        /* @__PURE__ */ e(r, { label: "Skills", value: "3" })
      ] }),
      /* @__PURE__ */ a(t, { children: [
        /* @__PURE__ */ e(i, { children: "Getting Started" }),
        /* @__PURE__ */ a("div", { className: "py-3 space-y-2", children: [
          /* @__PURE__ */ e("p", { className: "text-sm text-muted", children: "To use Kodama in Crew:" }),
          /* @__PURE__ */ a("div", { className: "text-sm text-muted space-y-1.5", children: [
            /* @__PURE__ */ a("div", { className: "flex gap-2", children: [
              /* @__PURE__ */ e("span", { className: "text-foreground w-4 shrink-0", children: "1." }),
              /* @__PURE__ */ a("span", { children: [
                "Go to ",
                /* @__PURE__ */ e("span", { className: "font-medium text-foreground", children: "Sessions" })
              ] })
            ] }),
            /* @__PURE__ */ a("div", { className: "flex gap-2", children: [
              /* @__PURE__ */ e("span", { className: "text-foreground w-4 shrink-0", children: "2." }),
              /* @__PURE__ */ a("span", { children: [
                "Start a ",
                /* @__PURE__ */ e("span", { className: "font-medium text-foreground", children: "New Session" })
              ] })
            ] }),
            /* @__PURE__ */ a("div", { className: "flex gap-2", children: [
              /* @__PURE__ */ e("span", { className: "text-foreground w-4 shrink-0", children: "3." }),
              /* @__PURE__ */ a("span", { children: [
                "Change the agent from ",
                /* @__PURE__ */ e("span", { className: "font-mono text-xs bg-muted/50 px-1 py-0.5 rounded", children: "default" }),
                " to ",
                /* @__PURE__ */ e("span", { className: "font-mono text-xs bg-muted/50 px-1 py-0.5 rounded", children: "kodama" })
              ] })
            ] }),
            /* @__PURE__ */ a("div", { className: "flex gap-2", children: [
              /* @__PURE__ */ e("span", { className: "text-foreground w-4 shrink-0", children: "4." }),
              /* @__PURE__ */ e("span", { children: "Start chatting — Kodama will delegate to specialists automatically" })
            ] })
          ] })
        ] })
      ] }),
      /* @__PURE__ */ a(t, { children: [
        /* @__PURE__ */ e(i, { children: "Agent Roster" }),
        /* @__PURE__ */ e("div", { className: "divide-y divide-border", children: m.map((n) => /* @__PURE__ */ a("div", { className: "flex items-center gap-3 py-3", children: [
          /* @__PURE__ */ e("span", { className: "text-lg", children: n.icon }),
          /* @__PURE__ */ a("div", { className: "flex-1 min-w-0", children: [
            /* @__PURE__ */ e("p", { className: "text-sm font-mono truncate", children: n.name }),
            /* @__PURE__ */ e("p", { className: "text-xs text-muted", children: n.role })
          ] }),
          /* @__PURE__ */ e(d, { children: n.name === "kodama" ? "orchestrator" : "specialist" })
        ] }, n.name)) })
      ] })
    ] })
  ] });
}
export {
  x as default
};
