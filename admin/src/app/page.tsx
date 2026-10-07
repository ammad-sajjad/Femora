import { Suspense } from "react";
import { requireAdmin } from "@/lib/session";
import { listAllUsers, type AppUser } from "@/lib/firebase";
import { Dashboard } from "@/components/dashboard";
import { Logo } from "@/components/logo";

export default function Home() {
  return (
    <Suspense fallback={<Loading />}>
      <Users />
    </Suspense>
  );
}

async function Users() {
  await requireAdmin();
  let users: AppUser[] = [];
  let error: string | null = null;
  try {
    users = await listAllUsers();
  } catch (e) {
    error = e instanceof Error ? e.message : "Could not load users.";
  }
  return <Dashboard initialUsers={users} initialError={error} />;
}

function Loading() {
  return (
    <div className="grid min-h-screen place-items-center">
      <div className="flex flex-col items-center gap-4">
        <div className="animate-pulse">
          <Logo size={48} />
        </div>
        <p className="text-sm text-muted">Loading users…</p>
      </div>
    </div>
  );
}
