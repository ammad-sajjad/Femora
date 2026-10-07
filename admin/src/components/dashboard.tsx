"use client";

import { useEffect, useMemo, useState, useTransition } from "react";
import type { AppUser, Provider } from "@/lib/firebase";
import { logout, refreshUsers, setUserActive } from "@/app/actions";
import { Logo } from "./logo";

type Filter = "all" | "active" | "disabled";
type Toast = { id: number; kind: "ok" | "bad"; text: string };

const PAGE_SIZE = 20;
const WEEK = 7 * 24 * 60 * 60 * 1000;

const PROVIDERS: Record<Provider, { label: string; className: string }> = {
  google: { label: "Google", className: "bg-[#e8f0fe] text-[#1a56c4] dark:bg-[#17284a] dark:text-[#8ab4f8]" },
  password: { label: "Email & password", className: "bg-berry-soft text-berry" },
  "email-code": { label: "Email code", className: "bg-[#f1ebfb] text-[#6c2d7e] dark:bg-[#2a1d38] dark:text-[#c9a3e0]" },
  phone: { label: "Phone", className: "bg-warn-soft text-warn" },
  guest: { label: "Guest", className: "bg-surface-2 text-muted border border-line" },
};

function timeAgo(iso: string | null) {
  if (!iso) return "Never";
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.round(diff / 60000);
  if (m < 1) return "Just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.round(h / 24);
  if (d < 30) return `${d}d ago`;
  return new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
}

const fullDate = (iso: string | null) => (iso ? new Date(iso).toLocaleString() : "—");

const displayName = (u: AppUser) => u.name?.trim() || u.email?.split("@")[0] || (u.provider === "guest" ? "Guest user" : "Unnamed");

export function Dashboard({ initialUsers, initialError }: { initialUsers: AppUser[]; initialError: string | null }) {
  const [users, setUsers] = useState(initialUsers);
  const [error, setError] = useState(initialError);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [page, setPage] = useState(0);
  const [busy, setBusy] = useState<Set<string>>(new Set());
  const [confirming, setConfirming] = useState<AppUser | null>(null);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [refreshing, startRefresh] = useTransition();
  const [updatedAt, setUpdatedAt] = useState(() => Date.now());

  const toast = (kind: Toast["kind"], text: string) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, kind, text }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4000);
  };

  const refresh = (quiet = false) =>
    startRefresh(async () => {
      const r = await refreshUsers();
      if (r.ok) {
        setUsers(r.data);
        setError(null);
        setUpdatedAt(Date.now());
        if (!quiet) toast("ok", "User list refreshed");
      } else if (!quiet) {
        toast("bad", r.error);
      }
    });

  // Keep the list fresh: every 30 seconds, and whenever the tab comes back into view.
  useEffect(() => {
    const tick = setInterval(() => document.visibilityState === "visible" && refresh(true), 30_000);
    const onFocus = () => refresh(true);
    window.addEventListener("focus", onFocus);
    return () => {
      clearInterval(tick);
      window.removeEventListener("focus", onFocus);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const stats = useMemo(() => {
    const now = updatedAt;
    return {
      total: users.length,
      active: users.filter((u) => !u.disabled).length,
      disabled: users.filter((u) => u.disabled).length,
      newThisWeek: users.filter((u) => u.createdAt && now - new Date(u.createdAt).getTime() < WEEK).length,
    };
  }, [users, updatedAt]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return users.filter((u) => {
      if (filter === "active" && u.disabled) return false;
      if (filter === "disabled" && !u.disabled) return false;
      if (!q) return true;
      return [u.name, u.email, u.uid, u.phone].some((v) => v?.toLowerCase().includes(q));
    });
  }, [users, query, filter]);

  const pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const current = Math.min(page, pages - 1);
  const visible = filtered.slice(current * PAGE_SIZE, current * PAGE_SIZE + PAGE_SIZE);

  async function toggle(user: AppUser, active: boolean) {
    setBusy((b) => new Set(b).add(user.uid));
    // Optimistic: flip it now, put it back if the server says no.
    setUsers((list) => list.map((u) => (u.uid === user.uid ? { ...u, disabled: !active } : u)));
    const r = await setUserActive(user.uid, active);
    setBusy((b) => {
      const next = new Set(b);
      next.delete(user.uid);
      return next;
    });
    if (r.ok) {
      setUsers((list) => list.map((u) => (u.uid === user.uid ? r.data : u)));
      toast("ok", active ? `${displayName(user)} is active again` : `${displayName(user)} was deactivated and signed out`);
    } else {
      setUsers((list) => list.map((u) => (u.uid === user.uid ? user : u)));
      toast("bad", r.error);
    }
  }

  const onSwitch = (user: AppUser) => (user.disabled ? toggle(user, true) : setConfirming(user));

  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-20 border-b border-line bg-surface/80 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
          <div className="flex items-center gap-3">
            <Logo />
            <div className="leading-tight">
              <p className="text-[15px] font-bold tracking-tight">Femora</p>
              <p className="text-xs text-muted">Admin console</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => refresh()}
              disabled={refreshing}
              className="flex h-9 items-center gap-2 rounded-lg border border-line bg-surface px-3 text-sm font-medium transition hover:bg-surface-2 disabled:opacity-60"
              title="Refresh"
            >
              <RefreshIcon spinning={refreshing} />
              <span className="hidden sm:inline">Refresh</span>
            </button>
            <form action={logout}>
              <button className="flex h-9 items-center gap-2 rounded-lg px-3 text-sm font-medium text-muted transition hover:bg-surface-2 hover:text-ink">
                <LogoutIcon />
                <span className="hidden sm:inline">Sign out</span>
              </button>
            </form>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
        <div className="fade-up mb-6 flex flex-wrap items-end justify-between gap-2">
          <div>
            <h1 className="text-2xl font-bold tracking-tight sm:text-[28px]">Users</h1>
            <p className="mt-1 text-sm text-muted">
              Everyone with a Femora account. Deactivated users are signed out of the app within seconds.
            </p>
          </div>
          <p className="text-xs text-faint">Updated {timeAgo(new Date(updatedAt).toISOString()).toLowerCase()}</p>
        </div>

        {error && (
          <div className="mb-6 rounded-xl border border-bad/30 bg-bad-soft px-4 py-3 text-sm text-bad">
            <strong className="font-semibold">Could not load users.</strong> {error}
          </div>
        )}

        <section className="fade-up mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4" style={{ animationDelay: "50ms" }}>
          <Stat label="Total users" value={stats.total} tone="berry" icon={<UsersIcon />} />
          <Stat label="Active" value={stats.active} tone="ok" icon={<CheckIcon />} />
          <Stat label="Deactivated" value={stats.disabled} tone="bad" icon={<BanIcon />} />
          <Stat label="New this week" value={stats.newThisWeek} tone="warn" icon={<SparkIcon />} />
        </section>

        <section
          className="fade-up overflow-hidden rounded-2xl border border-line bg-surface shadow-card"
          style={{ animationDelay: "100ms" }}
        >
          <div className="flex flex-col gap-3 border-b border-line p-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="relative w-full sm:max-w-xs">
              <SearchIcon />
              <input
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  setPage(0);
                }}
                placeholder="Search name, email or ID"
                className="h-10 w-full rounded-xl border border-line bg-surface-2 pr-3 pl-9 text-sm outline-none transition focus:border-berry focus:ring-4 focus:ring-berry/10"
              />
            </div>
            <div className="flex rounded-xl bg-surface-2 p-1 text-sm">
              {(
                [
                  ["all", "All", stats.total],
                  ["active", "Active", stats.active],
                  ["disabled", "Deactivated", stats.disabled],
                ] as const
              ).map(([key, label, count]) => (
                <button
                  key={key}
                  onClick={() => {
                    setFilter(key);
                    setPage(0);
                  }}
                  className={`flex-1 rounded-lg px-3 py-1.5 font-medium whitespace-nowrap transition sm:flex-none ${
                    filter === key ? "bg-surface text-ink shadow-sm" : "text-muted hover:text-ink"
                  }`}
                >
                  {label} <span className="ml-0.5 text-xs text-faint">{count}</span>
                </button>
              ))}
            </div>
          </div>

          {visible.length === 0 ? (
            <Empty searching={!!query || filter !== "all"} />
          ) : (
            <>
              {/* Wide screens: table */}
              <table className="hidden w-full text-sm md:table">
                <thead>
                  <tr className="border-b border-line text-left text-xs font-semibold tracking-wide text-faint uppercase">
                    <th className="px-5 py-3">User</th>
                    <th className="px-3 py-3">Sign-in</th>
                    <th className="px-3 py-3">Joined</th>
                    <th className="px-3 py-3">Last active</th>
                    <th className="px-3 py-3">Status</th>
                    <th className="px-5 py-3 text-right">Access</th>
                  </tr>
                </thead>
                <tbody>
                  {visible.map((u) => (
                    <tr
                      key={u.uid}
                      className={`border-b border-line transition last:border-0 hover:bg-surface-2 ${u.disabled ? "opacity-70" : ""}`}
                    >
                      <td className="px-5 py-3.5">
                        <UserCell user={u} />
                      </td>
                      <td className="px-3 py-3.5">
                        <ProviderBadge provider={u.provider} />
                      </td>
                      <td className="px-3 py-3.5 text-muted" title={fullDate(u.createdAt)}>
                        {timeAgo(u.createdAt)}
                      </td>
                      <td className="px-3 py-3.5 text-muted" title={fullDate(u.lastActive ?? u.lastSignIn)}>
                        {timeAgo(u.lastActive ?? u.lastSignIn)}
                      </td>
                      <td className="px-3 py-3.5">
                        <StatusPill disabled={u.disabled} />
                      </td>
                      <td className="px-5 py-3.5">
                        <div className="flex justify-end">
                          <Switch on={!u.disabled} busy={busy.has(u.uid)} onClick={() => onSwitch(u)} label={displayName(u)} />
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {/* Phones: cards */}
              <ul className="divide-y divide-line md:hidden">
                {visible.map((u) => (
                  <li key={u.uid} className={`p-4 ${u.disabled ? "opacity-70" : ""}`}>
                    <div className="flex items-start justify-between gap-3">
                      <UserCell user={u} />
                      <Switch on={!u.disabled} busy={busy.has(u.uid)} onClick={() => onSwitch(u)} label={displayName(u)} />
                    </div>
                    <div className="mt-3 flex flex-wrap items-center gap-2 pl-[52px] text-xs text-muted">
                      <StatusPill disabled={u.disabled} />
                      <ProviderBadge provider={u.provider} />
                      <span>Joined {timeAgo(u.createdAt).toLowerCase()}</span>
                    </div>
                  </li>
                ))}
              </ul>
            </>
          )}

          {filtered.length > PAGE_SIZE && (
            <div className="flex items-center justify-between border-t border-line px-5 py-3 text-sm text-muted">
              <span>
                {current * PAGE_SIZE + 1}–{Math.min(filtered.length, (current + 1) * PAGE_SIZE)} of {filtered.length}
              </span>
              <div className="flex gap-2">
                <PageButton disabled={current === 0} onClick={() => setPage(current - 1)}>
                  Previous
                </PageButton>
                <PageButton disabled={current >= pages - 1} onClick={() => setPage(current + 1)}>
                  Next
                </PageButton>
              </div>
            </div>
          )}
        </section>
      </main>

      {confirming && (
        <ConfirmDialog
          user={confirming}
          onCancel={() => setConfirming(null)}
          onConfirm={() => {
            const u = confirming;
            setConfirming(null);
            toggle(u, false);
          }}
        />
      )}

      <div className="pointer-events-none fixed right-4 bottom-4 left-4 z-50 flex flex-col items-end gap-2 sm:left-auto">
        {toasts.map((t) => (
          <div
            key={t.id}
            role="status"
            className={`fade-up pointer-events-auto flex max-w-sm items-center gap-2.5 rounded-xl border px-4 py-3 text-sm font-medium shadow-card ${
              t.kind === "ok" ? "border-ok/25 bg-surface text-ink" : "border-bad/30 bg-bad-soft text-bad"
            }`}
          >
            <span className={`h-2 w-2 shrink-0 rounded-full ${t.kind === "ok" ? "bg-ok" : "bg-bad"}`} />
            {t.text}
          </div>
        ))}
      </div>
    </div>
  );
}

function Stat({ label, value, tone, icon }: { label: string; value: number; tone: "berry" | "ok" | "bad" | "warn"; icon: React.ReactNode }) {
  const tones = {
    berry: "bg-berry-soft text-berry",
    ok: "bg-ok-soft text-ok",
    bad: "bg-bad-soft text-bad",
    warn: "bg-warn-soft text-warn",
  };
  return (
    <div className="rounded-2xl border border-line bg-surface p-4 shadow-card sm:p-5">
      <div className="flex items-center justify-between">
        <p className="text-xs font-semibold text-muted sm:text-sm">{label}</p>
        <span className={`grid h-8 w-8 place-items-center rounded-lg ${tones[tone]}`}>{icon}</span>
      </div>
      <p className="mt-2 text-2xl font-bold tracking-tight tabular-nums sm:text-3xl">{value.toLocaleString()}</p>
    </div>
  );
}

function UserCell({ user }: { user: AppUser }) {
  const name = displayName(user);
  const initials = name
    .split(/[\s._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]!.toUpperCase())
    .join("");
  return (
    <div className="flex min-w-0 items-center gap-3">
      {user.photo ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={user.photo} alt="" referrerPolicy="no-referrer" className="h-10 w-10 shrink-0 rounded-full object-cover" />
      ) : (
        <div
          className={`grid h-10 w-10 shrink-0 place-items-center rounded-full text-sm font-bold ${
            user.provider === "guest" ? "bg-surface-2 text-faint border border-line" : "brand-gradient text-white"
          }`}
        >
          {initials || "?"}
        </div>
      )}
      <div className="min-w-0">
        <p className="truncate font-semibold">{name}</p>
        <p className="truncate text-xs text-muted" title={user.uid}>
          {user.email ?? user.phone ?? `ID ${user.uid.slice(0, 10)}…`}
        </p>
      </div>
    </div>
  );
}

function ProviderBadge({ provider }: { provider: Provider }) {
  const p = PROVIDERS[provider];
  return <span className={`inline-flex rounded-md px-2 py-0.5 text-xs font-medium whitespace-nowrap ${p.className}`}>{p.label}</span>;
}

function StatusPill({ disabled }: { disabled: boolean }) {
  return disabled ? (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-bad-soft px-2.5 py-0.5 text-xs font-semibold text-bad">
      <span className="h-1.5 w-1.5 rounded-full bg-bad" /> Deactivated
    </span>
  ) : (
    <span className="inline-flex items-center gap-1.5 rounded-full bg-ok-soft px-2.5 py-0.5 text-xs font-semibold text-ok">
      <span className="h-1.5 w-1.5 rounded-full bg-ok" /> Active
    </span>
  );
}

function Switch({ on, busy, onClick, label }: { on: boolean; busy: boolean; onClick: () => void; label: string }) {
  return (
    <button
      role="switch"
      aria-checked={on}
      aria-label={`${on ? "Deactivate" : "Activate"} ${label}`}
      title={on ? "Deactivate" : "Activate"}
      disabled={busy}
      onClick={onClick}
      className={`relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition-colors focus-visible:ring-4 focus-visible:ring-berry/20 focus-visible:outline-none disabled:cursor-wait ${
        on ? "bg-ok" : "bg-line"
      }`}
    >
      <span
        className={`grid h-5.5 w-5.5 place-items-center rounded-full bg-white shadow transition-transform ${on ? "translate-x-[23px]" : "translate-x-[3px]"}`}
      >
        {busy && <span className="spin h-3 w-3 rounded-full border-2 border-black/15 border-t-black/50" />}
      </span>
    </button>
  );
}

function ConfirmDialog({ user, onCancel, onConfirm }: { user: AppUser; onCancel: () => void; onConfirm: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onCancel();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onCancel]);
  return (
    <div className="fixed inset-0 z-40 grid place-items-center bg-black/40 px-4 backdrop-blur-sm" onClick={onCancel}>
      <div
        role="dialog"
        aria-modal
        aria-labelledby="confirm-title"
        onClick={(e) => e.stopPropagation()}
        className="fade-up w-full max-w-md rounded-2xl border border-line bg-surface p-6 shadow-2xl"
      >
        <div className="mb-4 grid h-11 w-11 place-items-center rounded-xl bg-bad-soft text-bad">
          <BanIcon />
        </div>
        <h2 id="confirm-title" className="text-lg font-bold">
          Deactivate {displayName(user)}?
        </h2>
        <p className="mt-2 text-sm leading-relaxed text-muted">
          They will be signed out of the Femora app within a few seconds and won&apos;t be able to sign back in until you
          activate the account again. Their health data stays on their phone.
        </p>
        <div className="mt-6 flex justify-end gap-2">
          <button onClick={onCancel} className="h-10 rounded-xl border border-line px-4 text-sm font-semibold transition hover:bg-surface-2">
            Cancel
          </button>
          <button
            autoFocus
            onClick={onConfirm}
            className="h-10 rounded-xl bg-bad px-4 text-sm font-semibold text-white transition hover:opacity-90"
          >
            Deactivate &amp; sign out
          </button>
        </div>
      </div>
    </div>
  );
}

function Empty({ searching }: { searching: boolean }) {
  return (
    <div className="flex flex-col items-center px-6 py-16 text-center">
      <div className="mb-3 grid h-12 w-12 place-items-center rounded-2xl bg-berry-soft text-berry">
        <UsersIcon />
      </div>
      <p className="font-semibold">{searching ? "No matching users" : "No users yet"}</p>
      <p className="mt-1 text-sm text-muted">
        {searching ? "Try a different search or filter." : "People who sign up in the app will appear here."}
      </p>
    </div>
  );
}

function PageButton(props: { disabled: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      {...props}
      className="h-8 rounded-lg border border-line px-3 font-medium text-ink transition hover:bg-surface-2 disabled:opacity-40"
    />
  );
}

const icon = { width: 16, height: 16, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 2, strokeLinecap: "round", strokeLinejoin: "round" } as const;

function UsersIcon() {
  return (
    <svg {...icon}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  );
}
function CheckIcon() {
  return (
    <svg {...icon}>
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
      <path d="m9 11 3 3L22 4" />
    </svg>
  );
}
function BanIcon() {
  return (
    <svg {...icon}>
      <circle cx="12" cy="12" r="10" />
      <path d="m4.9 4.9 14.2 14.2" />
    </svg>
  );
}
function SparkIcon() {
  return (
    <svg {...icon}>
      <path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1" />
    </svg>
  );
}
function SearchIcon() {
  return (
    <svg {...icon} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-faint">
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </svg>
  );
}
function RefreshIcon({ spinning }: { spinning: boolean }) {
  return (
    <svg {...icon} className={spinning ? "spin" : ""}>
      <path d="M21 12a9 9 0 1 1-2.64-6.36L21 8" />
      <path d="M21 3v5h-5" />
    </svg>
  );
}
function LogoutIcon() {
  return (
    <svg {...icon}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
    </svg>
  );
}
