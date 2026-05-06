import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function ok(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const log: string[] = [];

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return ok({ error: "Unauthorized" });

    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { dogId, email, role } = await req.json();
    if (!dogId || !email || !role) return ok({ error: "dogId, email, and role are required" });

    const normalizedEmail = email.trim().toLowerCase();

    // 1. Verify caller owns the dog AND has editor/owner permissions
    const { data: userResponse } = await callerClient.auth.getUser();
    const callerId = userResponse.user?.id;
    if (!callerId) return ok({ error: "Unauthorized: No user session", log });

    // Check if original owner
    const { data: dog, error: dogErr } = await callerClient
      .from("dogs")
      .select("id, name, owner_id")
      .eq("id", dogId)
      .single();

    if (dogErr || !dog) return ok({ error: `Dog not found: ${dogErr?.message}`, log });

    let isAuthorized = dog.owner_id === callerId;

    if (!isAuthorized) {
      // Fallback: check dog_owners table for editor/owner role
      const { data: ownership } = await callerClient
        .from("dog_owners")
        .select("role")
        .eq("dog_id", dogId)
        .eq("user_id", callerId)
        .eq("accepted", true)
        .single();
      
      if (ownership && (ownership.role === 'owner' || ownership.role === 'editor')) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      return ok({ error: "Unauthorized: Only owners and editors can invite family members.", log });
    }

    const appUrl = Deno.env.get("FRONTEND_URL") || "https://snoot-web-zeta.vercel.app";

    // 2. Try to invite the user. This triggers the email if they don't exist or are pending.
    const { data: inviteData, error: inviteErr } = await adminClient.auth.admin.inviteUserByEmail(
      normalizedEmail,
      { 
        data: { display_name: normalizedEmail.split("@")[0] }, 
        redirectTo: appUrl 
      }
    );

    let userId: string | null = null;

    if (inviteErr) {
      log.push(`Invite error: ${inviteErr.message}`);
      // If they already exist, we need to find their ID
      if (inviteErr.message.toLowerCase().includes("already")) {
        const { data: listData } = await adminClient.auth.admin.listUsers();
        const existing = listData?.users.find(u => u.email?.toLowerCase() === normalizedEmail);
        userId = existing?.id || null;
        log.push(userId ? `Found existing user ID: ${userId}` : "Could not find existing user ID");
      } else {
        return ok({ error: `Invite failed: ${inviteErr.message}`, log });
      }
    } else {
      userId = inviteData.user.id;
      log.push(`Invite sent, new user ID: ${userId}`);
    }

    // 3. Clean up and insert dog_owners record
    await adminClient
      .from("dog_owners")
      .delete()
      .eq("dog_id", dogId)
      .eq("invited_email", normalizedEmail);

    const { error: insertErr } = await adminClient
      .from("dog_owners")
      .insert({
        dog_id: dogId,
        user_id: userId,
        invited_email: normalizedEmail,
        role,
        accepted: false,
      });

    if (insertErr) return ok({ error: `Insert failed: ${insertErr.message}`, log });

    return ok({ success: true, log });

  } catch (err) {
    return ok({ error: String(err), log });
  }
});
