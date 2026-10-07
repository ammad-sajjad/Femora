"use client";

import { useActionState } from "react";
import { login } from "../actions";

export function LoginForm() {
  const [state, action, pending] = useActionState(login, undefined);
  return (
    <form action={action} className="space-y-4">
      <Field label="Email" name="email" type="email" autoComplete="username" />
      <Field label="Password" name="password" type="password" autoComplete="current-password" />
      {state?.error && (
        <p role="alert" className="rounded-lg bg-bad-soft px-3 py-2 text-sm text-bad">
          {state.error}
        </p>
      )}
      <button
        disabled={pending}
        className="brand-gradient flex h-11 w-full items-center justify-center gap-2 rounded-xl text-sm font-semibold text-white transition hover:opacity-95 active:scale-[0.99] disabled:opacity-70"
      >
        {pending && <span className="spin h-4 w-4 rounded-full border-2 border-white/40 border-t-white" />}
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}

function Field(props: { label: string; name: string; type: string; autoComplete: string }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-semibold text-muted">{props.label}</span>
      <input
        required
        name={props.name}
        type={props.type}
        autoComplete={props.autoComplete}
        className="h-11 w-full rounded-xl border border-line bg-surface-2 px-3.5 text-sm outline-none transition focus:border-berry focus:ring-4 focus:ring-berry/10"
      />
    </label>
  );
}
