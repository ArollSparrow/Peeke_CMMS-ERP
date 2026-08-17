import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const ELEVATED = new Set([
  "owner",
  "system_admin",
  "admin",
  "general_manager",
]);

// Pragmatic format check — not full RFC 5322, just enough to reject
// obviously malformed input before it reaches the Admin API.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Find Auth user id by email (paginate; tenant projects stay small). */
async function findAuthUserIdByEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  const target = email.trim().toLowerCase();
  let page = 1;
  const perPage = 200;
  while (page <= 10) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error || !data?.users?.length) return null;
    const hit = data.users.find(
      (u) => (u.email ?? "").toLowerCase() === target,
    );
    if (hit) return hit.id;
    if (data.users.length < perPage) return null;
    page += 1;
  }
  return null;
}

/**
 * Safe residual cleanup for SaaS: delete Auth user only when they have
 * zero organization_members rows. Optionally also require no other pending
 * invites for this email outside the current org (caller decides).
 */
async function deleteResidualAuthUserIfSafe(
  admin: ReturnType<typeof createClient>,
  email: string,
  opts?: { allowIfOnlyPendingForOrg?: string },
): Promise<boolean> {
  const userId = await findAuthUserIdByEmail(admin, email);
  if (!userId) return false;

  const { data: memberships } = await admin
    .from("organization_members")
    .select("id")
    .eq("user_id", userId)
    .limit(1);

  if ((memberships?.length ?? 0) > 0) return false;

  // Any pending invite for this email?
  const { data: pending } = await admin
    .from("organization_invites")
    .select("id, organization_id")
    .eq("email", email.trim().toLowerCase())
    .eq("status", "pending");

  const rows = pending ?? [];
  if (rows.length > 0) {
    if (opts?.allowIfOnlyPendingForOrg) {
      const foreign = rows.some(
        (r) => r.organization_id !== opts.allowIfOnlyPendingForOrg,
      );
      if (foreign) return false;
    } else {
      return false;
    }
  }

  const { error } = await admin.auth.admin.deleteUser(userId);
  return !error;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const organizationId = body.organization_id as string | undefined;
    const emailRaw = body.email as string | undefined;
    const roleRaw = (body.role as string | undefined) ?? "technician";
    const redirectTo = (body.redirect_to as string | undefined) ??
      undefined;

    if (!organizationId || !emailRaw || !EMAIL_RE.test(emailRaw.trim())) {
      return new Response(
        JSON.stringify({ error: "organization_id and valid email required" }),
        {
          status: 400,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    const email = emailRaw.trim().toLowerCase();
    const role = String(roleRaw).trim().toLowerCase() || "technician";

    const admin = createClient(supabaseUrl, serviceKey);

    // Caller must be elevated in this org
    const { data: mem } = await admin
      .from("organization_members")
      .select("role")
      .eq("organization_id", organizationId)
      .eq("user_id", user.id)
      .maybeSingle();

    const callerRole = ((mem?.role as string | undefined) ?? "").toLowerCase();
    if (!ELEVATED.has(callerRole)) {
      return new Response(JSON.stringify({ error: "Not allowed" }), {
        status: 403,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // Already a member of this org?
    const existingAuthId = await findAuthUserIdByEmail(admin, email);
    if (existingAuthId) {
      const { data: alreadyMember } = await admin
        .from("organization_members")
        .select("id")
        .eq("organization_id", organizationId)
        .eq("user_id", existingAuthId)
        .maybeSingle();
      if (alreadyMember) {
        return new Response(
          JSON.stringify({
            error: "This email is already a member of this organisation",
            status: "already_member",
          }),
          {
            status: 400,
            headers: { ...cors, "Content-Type": "application/json" },
          },
        );
      }
    }

    // Remove prior pending invites for this email in this org (re-invite)
    const { error: delPendingErr } = await admin
      .from("organization_invites")
      .delete()
      .eq("organization_id", organizationId)
      .eq("email", email)
      .eq("status", "pending");
    if (delPendingErr) {
      console.error(
        "invite-org-member: failed to clear prior pending invite:",
        delPendingErr.message,
      );
    }

    // SaaS: auto-purge residual Auth user that blocks inviteUserByEmail.
    // Only when they have zero memberships anywhere.
    const residualCleared = await deleteResidualAuthUserIfSafe(admin, email, {
      allowIfOnlyPendingForOrg: organizationId,
    });

    // Insert pending invite row
    const { data: inviteRow, error: insErr } = await admin
      .from("organization_invites")
      .insert({
        organization_id: organizationId,
        email,
        role,
        status: "pending",
        invited_by: user.id,
      })
      .select("id")
      .maybeSingle();

    if (insErr) {
      return new Response(
        JSON.stringify({ error: insErr.message ?? "Failed to save invite" }),
        {
          status: 500,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    const siteRedirect =
      redirectTo ??
      `${Deno.env.get("SITE_URL") ?? "https://peeke-cmms-erp.pages.dev"}/accept-invite`;

    let actionLink: string | null = null;
    let mailAttempted = false;
    let mailOk = false;
    let mailNote: string | null = null;

    // Prefer real invite email (creates/fresh Auth user + type=invite session)
    try {
      mailAttempted = true;
      const { data: invData, error: invErr } = await admin.auth.admin.inviteUserByEmail(
        email,
        {
          redirectTo: siteRedirect,
          data: {
            invited_organization_id: organizationId,
            invited_role: role,
            invited_at: new Date().toISOString(),
          },
        },
      );
      if (invErr) {
        mailNote = invErr.message;
      } else {
        mailOk = true;
        // Some setups still expose properties.action_link
        const link =
          (invData as { properties?: { action_link?: string } })?.properties
            ?.action_link ?? null;
        if (link) actionLink = link;
      }
    } catch (e) {
      mailNote = String(e);
    }

    // Fallback: shareable link when SMTP rate-limited or user already existed
    if (!mailOk || !actionLink) {
      try {
        // Prefer type invite; if user already confirmed, magiclink → accept-invite
        let gen = await admin.auth.admin.generateLink({
          type: "invite",
          email,
          options: {
            redirectTo: siteRedirect,
            data: {
              invited_organization_id: organizationId,
              invited_role: role,
              invited_at: new Date().toISOString(),
            },
          },
        });
        if (gen.error) {
          gen = await admin.auth.admin.generateLink({
            type: "magiclink",
            email,
            options: { redirectTo: siteRedirect },
          });
        }
        const props = gen.data?.properties as
          | { action_link?: string }
          | undefined;
        if (props?.action_link) {
          actionLink = props.action_link;
        }
      } catch (_) {
        // keep prior state
      }
    }

    const status = mailOk ? "invite_emailed" : "invite_saved";
    const message = mailOk
      ? `Invite sent to ${email}`
      : residualCleared
      ? `Invite saved for ${email}. Residual account was cleared — share the link if email is delayed.`
      : `Invite saved for ${email}. Email may be delayed — share the link if needed.`;

    return new Response(
      JSON.stringify({
        ok: true,
        status,
        message,
        invite_id: inviteRow?.id ?? null,
        email,
        residual_auth_cleared: residualCleared,
        mail_attempted: mailAttempted,
        mail_ok: mailOk,
        mail_note: mailNote,
        action_link: actionLink,
      }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
