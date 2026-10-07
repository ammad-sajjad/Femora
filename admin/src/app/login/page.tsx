import { Suspense } from "react";
import { redirect } from "next/navigation";
import { isSignedIn } from "@/lib/session";
import { Logo } from "@/components/logo";
import { LoginForm } from "./login-form";

async function RedirectIfSignedIn() {
  if (await isSignedIn()) redirect("/");
  return null;
}

export default function LoginPage() {
  return (
    <main className="relative grid min-h-screen place-items-center overflow-hidden px-4">
      <div className="pointer-events-none absolute -top-40 left-1/2 h-[480px] w-[480px] -translate-x-1/2 rounded-full bg-rose/20 blur-3xl" />
      <Suspense>
        <RedirectIfSignedIn />
      </Suspense>
      <div className="fade-up relative w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center text-center">
          <Logo size={52} />
          <h1 className="mt-5 text-2xl font-bold tracking-tight">Femora Admin</h1>
          <p className="mt-1.5 text-sm text-muted">Sign in to manage users</p>
        </div>
        <div className="rounded-2xl border border-line bg-surface p-6 shadow-card">
          <LoginForm />
        </div>
      </div>
    </main>
  );
}
