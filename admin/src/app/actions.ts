"use server";

import { redirect } from "next/navigation";
import { adminAuth, listAllUsers, toAppUser, type AppUser } from "@/lib/firebase";
import { checkCredentials, endSession, isSignedIn, startSession } from "@/lib/session";

type Result<T> = { ok: true; data: T } | { ok: false; error: string };

const failure = (e: unknown) => ({ ok: false as const, error: e instanceof Error ? e.message : "Something went wrong." });

export async function login(_: { error?: string } | undefined, form: FormData) {
  const email = String(form.get("email") ?? "");
  const password = String(form.get("password") ?? "");
  if (!process.env.ADMIN_EMAIL || !process.env.ADMIN_PASSWORD) {
    return { error: "The admin login is not configured. Set ADMIN_EMAIL and ADMIN_PASSWORD." };
  }
  if (!checkCredentials(email, password)) return { error: "That email or password is not correct." };
  await startSession();
  redirect("/");
}

export async function logout() {
  await endSession();
  redirect("/login");
}

export async function refreshUsers(): Promise<Result<AppUser[]>> {
  if (!(await isSignedIn())) return { ok: false, error: "Your session has ended. Please sign in again." };
  try {
    return { ok: true, data: await listAllUsers() };
  } catch (e) {
    return failure(e);
  }
}

/**
 * Activates or deactivates an account. Deactivating also revokes its sessions, and the app checks every
 * few seconds, so the user is signed out of the app straight away.
 */
export async function setUserActive(uid: string, active: boolean): Promise<Result<AppUser>> {
  if (!(await isSignedIn())) return { ok: false, error: "Your session has ended. Please sign in again." };
  try {
    const auth = adminAuth();
    const user = await auth.updateUser(uid, { disabled: !active });
    if (!active) await auth.revokeRefreshTokens(uid);
    return { ok: true, data: toAppUser(user) };
  } catch (e) {
    return failure(e);
  }
}
