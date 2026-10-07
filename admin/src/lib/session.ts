import "server-only";
import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

const COOKIE = "femora_admin";
const MAX_AGE = 60 * 60 * 12; // 12 hours

function secret() {
  const s = process.env.SESSION_SECRET || process.env.ADMIN_PASSWORD;
  if (!s) throw new Error("ADMIN_PASSWORD is not set.");
  return s;
}

const sign = (payload: string) => createHmac("sha256", secret()).update(payload).digest("base64url");

function safeEqual(a: string, b: string) {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

export function checkCredentials(email: string, password: string) {
  const wantEmail = (process.env.ADMIN_EMAIL ?? "").trim().toLowerCase();
  const wantPassword = process.env.ADMIN_PASSWORD ?? "";
  if (!wantEmail || !wantPassword) return false;
  // Compare both, always, so the response time does not reveal which one was wrong.
  const okEmail = safeEqual(email.trim().toLowerCase(), wantEmail);
  const okPassword = safeEqual(password, wantPassword);
  return okEmail && okPassword;
}

export async function startSession() {
  const payload = `${Date.now() + MAX_AGE * 1000}`;
  (await cookies()).set(COOKIE, `${payload}.${sign(payload)}`, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: MAX_AGE,
  });
}

export async function endSession() {
  (await cookies()).delete(COOKIE);
}

export async function isSignedIn() {
  const value = (await cookies()).get(COOKIE)?.value;
  if (!value) return false;
  const [payload, sig] = value.split(".");
  if (!payload || !sig || !safeEqual(sig, sign(payload))) return false;
  return Number(payload) > Date.now();
}

/** For pages and actions: anyone without a valid session is sent to the sign-in page. */
export async function requireAdmin() {
  if (!(await isSignedIn())) redirect("/login");
}
