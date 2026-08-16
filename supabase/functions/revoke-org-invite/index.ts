import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

    // Caller identity
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
    const inviteId = body.invite_id as string | undefined;
    if (!inviteId) {
      return new Response(JSON.stringify({ error: "invite_id required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(supabaseUrl, serviceKey);

    // Load invite
    const { data: invite, error: invErr } = await admin
      .from("organization_invites")
      .select("id, email, organization_id, status")
      .eq("id", inviteId)
      .maybeSingle();

    if (invErr || !invite) {
      return new Response(JSON.stringify({ error: "Invite not found" }), {
        status: 404,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    if (invite.status !== "pending") {
      return new Response(JSON.stringify({ error: "Invite is not pending" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    // Caller must be elevated in this org
    const { data: mem } = await admin
      .from("organization_members")
      .select("role")
      .eq("organization_id", invite.organization_id)
      .eq("user_id", user.id)
      .maybeSingle();

    const role = ((mem?.role as string | undefined) ?? "").toLowerCase();
    const elevated = [
      "owner",
      "system_admin",
      "admin",
      "general_manager",
    ].includes(role);
    if (!elevated) {
      return new Response(JSON.stringify({ error: "Not allowed" }), {
        status: 403,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const email = String(invite.email).trim().toLowerCase();

    // 1. Delete invite row
    const { error: delInvErr } = await admin
      .from("organization_invites")
      .delete()
      .eq("id", inviteId);
    if (delInvErr) {
      return new Response(
        JSON.stringify({ error: delInvErr.message ?? "Failed to delete invite" }),
        {
          status: 500,
          headers: { ...cors, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Residual Auth cleanup — only if this email is not a member anywhere
    //    and has no other pending invites
    let authUserDeleted = false;

    // Resolve Auth user by email (paginate; projects are small)
    let targetId: string | null = null;
    let page = 1;
    const perPage = 200;
    while (page <= 10 && !targetId) {
      const { data: listed, error: listErr } = await admin.auth.admin.listUsers({
        page,
        perPage,
      });
      if (listErr || !listed?.users?.length) break;
      const hit = listed.users.find(
        (u) => (u.email ?? "").toLowerCase() === email,
      );
      if (hit) {
        targetId = hit.id;
        break;
      }
      if (listed.users.length < perPage) break;
      page += 1;
    }

    if (targetId) {
      const { data: memberships } = await admin
        .from("organization_members")
        .select("id")
        .eq("user_id", targetId)
        .limit(1);

      const { data: otherInvites } = await admin
        .from("organization_invites")
        .select("id")
        .eq("email", email)
        .eq("status", "pending")
        .limit(1);

      const isMember = (memberships?.length ?? 0) > 0;
      const hasOtherPending = (otherInvites?.length ?? 0) > 0;

      if (!isMember && !hasOtherPending) {
        const { error: delErr } = await admin.auth.admin.deleteUser(targetId);
        if (!delErr) authUserDeleted = true;
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        email,
        auth_user_deleted: authUserDeleted,
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
