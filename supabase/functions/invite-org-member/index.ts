import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const APP_ORIGIN = "https://peeke-cmms-erp.pages.dev";

const ELEVATED = new Set([
  "owner",
  "system_admin",
  "admin",
  "general_manager",
]);

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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

/** Must match generateLink type so verifyOTP succeeds. */
function acceptInviteUrl(tokenHash: string, otpType: "invite" | "magiclink"): string {
  const q = new URLSearchParams({
    token_hash: tokenHash,
    type: otpType,
  });
  return `${APP_ORIGIN}/accept-invite?${q.toString()}`;
}

async function sendInviteEmailResend(opts: {
  to: string;
  acceptUrl: string;
}): Promise<{ ok: boolean; note: string | null }> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    return { ok: false, note: "RESEND_API_KEY not set on invite-org-member" };
  }
  const from =
    Deno.env.get("MAIL_FROM") || "Peeke Automation <onboarding@resend.dev>";
  const sky = "#D3EFFD";
  const navy = "#272A6D";
  const teal = "#55AAAC";
  const html = `<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:${sky};font-family:system-ui,-apple-system,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:${sky};padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" style="max-width:480px;background:${sky};border:1px solid ${teal};border-radius:16px;padding:28px;">
        <tr><td>
          <p style="margin:0 0 4px;font-size:13px;font-weight:600;color:${teal};">Peeke Automation</p>
          <h1 style="margin:0 0 16px;font-size:22px;color:${navy};">You're invited</h1>
          <p style="margin:0 0 16px;font-size:15px;line-height:1.5;color:${navy};">
            A team admin invited you to Peeke CMMS-ERP. Open the link to create your password and join the team.
            This is not organisation registration.
          </p>
          <p style="text-align:center;margin:28px 0;">
            <a href="${opts.acceptUrl}"
               style="background:${navy};color:${sky};padding:14px 28px;border-radius:10px;
                      text-decoration:none;font-weight:600;display:inline-block;">Accept invitation</a>
          </p>
          <p style="font-size:12px;color:${teal};word-break:break-all;">Or open:<br/>${opts.acceptUrl}</p>
          <p style="margin:24px 0 0;font-size:11px;color:${teal};">
            © Peeke Automation · Peeke CMMS-ERP · Do not forward this email
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [opts.to],
        subject: "You're invited to Peeke CMMS-ERP",
        html,
      }),
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      return { ok: false, note: `resend_status_${res.status}:${body.slice(0, 120)}` };
    }
    return { ok: true, note: null };
  } catch (e) {
    return { ok: false, note: String(e) };
  }
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
    const redirectTo = (body.redirect_to as string | undefined) ?? undefined;

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

    const residualCleared = await deleteResidualAuthUserIfSafe(admin, email, {
      allowIfOnlyPendingForOrg: organizationId,
    });

    const { error: delPendingErr2 } = await admin
      .from("organization_invites")
      .delete()
      .eq("organization_id", organizationId)
      .eq("email", email)
      .eq("status", "pending");
    if (delPendingErr2) {
      console.error(
        "invite-org-member: failed to clear pending after residual purge:",
        delPendingErr2.message,
      );
    }

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

    const siteRedirect = redirectTo ?? `${APP_ORIGIN}/accept-invite`;

    let actionLink: string | null = null;
    let mailOk = false;
    let mailNote: string | null = null;
    let linkType: "invite" | "magiclink" | null = null;
    let hashedToken: string | null = null;

    try {
      let otpType: "invite" | "magiclink" = "invite";
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
        otpType = "magiclink";
        gen = await admin.auth.admin.generateLink({
          type: "magiclink",
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
      }

      const props = gen.data?.properties as {
        action_link?: string;
        hashed_token?: string;
      } | undefined;

      const dataAny = gen.data as Record<string, unknown> | null;
      const hashed =
        props?.hashed_token ??
        (typeof dataAny?.hashed_token === "string"
          ? (dataAny.hashed_token as string)
          : null);

      hashedToken = hashed;
      linkType = otpType;

      if (hashedToken) {
        actionLink = acceptInviteUrl(hashedToken, otpType);
      } else if (props?.action_link) {
        actionLink = props.action_link;
      }

      if (actionLink && actionLink.includes("token_hash=")) {
        const sent = await sendInviteEmailResend({
          to: email,
          acceptUrl: actionLink,
        });
        mailOk = sent.ok;
        mailNote = sent.note;
      } else {
        mailNote =
          gen.error?.message ??
          (hashedToken ? "resend_skipped_bad_url" : "no_hashed_token");
      }
    } catch (e) {
      mailNote = String(e);
    }

    const status = mailOk ? "invite_emailed" : "invite_saved";
    const message = mailOk
      ? `Invite sent to ${email}`
      : residualCleared
      ? `Invite saved for ${email}. Residual account was cleared — use Copy invite link if email is delayed.`
      : `Invite saved for ${email}. Use Copy invite link if email is delayed or still the default Supabase template.`;

    return new Response(
      JSON.stringify({
        ok: true,
        status,
        message,
        invite_id: inviteRow?.id ?? null,
        email,
        residual_auth_cleared: residualCleared,
        mail_ok: mailOk,
        mail_note: mailNote,
        action_link: actionLink,
        link_type: linkType,
        link_has_token_hash: !!(actionLink && actionLink.includes("token_hash=")),
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
