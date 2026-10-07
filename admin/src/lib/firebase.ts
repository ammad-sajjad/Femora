import "server-only";
import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth, type UserRecord } from "firebase-admin/auth";

/** The Firebase service account, from FIREBASE_SERVICE_ACCOUNT (the JSON itself, or base64 of it). */
function credentials() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT is not set.");
  const json = raw.startsWith("{") ? raw : Buffer.from(raw, "base64").toString("utf8");
  const account = JSON.parse(json);
  return cert({
    projectId: account.project_id,
    clientEmail: account.client_email,
    privateKey: String(account.private_key).replace(/\\n/g, "\n"),
  });
}

function app(): App {
  return getApps()[0] ?? initializeApp({ credential: credentials() });
}

export const adminAuth = () => getAuth(app());

export type Provider = "google" | "password" | "email-code" | "guest" | "phone";

export type AppUser = {
  uid: string;
  email: string | null;
  name: string | null;
  photo: string | null;
  phone: string | null;
  provider: Provider;
  emailVerified: boolean;
  disabled: boolean;
  createdAt: string | null;
  lastSignIn: string | null;
  lastActive: string | null;
};

function provider(u: UserRecord): Provider {
  const ids = u.providerData.map((p) => p.providerId);
  if (ids.includes("google.com")) return "google";
  if (ids.includes("password")) return "password";
  if (ids.includes("phone")) return "phone";
  // Email-code accounts are made by the Femora server with a custom token, so they carry no provider.
  return u.email ? "email-code" : "guest";
}

const iso = (s?: string | null) => (s ? new Date(s).toISOString() : null);

export function toAppUser(u: UserRecord): AppUser {
  return {
    uid: u.uid,
    email: u.email ?? null,
    name: u.displayName ?? null,
    photo: u.photoURL ?? null,
    phone: u.phoneNumber ?? null,
    provider: provider(u),
    emailVerified: u.emailVerified,
    disabled: u.disabled,
    createdAt: iso(u.metadata.creationTime),
    lastSignIn: iso(u.metadata.lastSignInTime),
    lastActive: iso(u.metadata.lastRefreshTime),
  };
}

/** Every account in Firebase Authentication, newest first. */
export async function listAllUsers(): Promise<AppUser[]> {
  const auth = adminAuth();
  const users: AppUser[] = [];
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users.map(toAppUser));
    pageToken = page.pageToken;
  } while (pageToken && users.length < 50_000);
  return users.sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""));
}
