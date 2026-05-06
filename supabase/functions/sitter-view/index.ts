import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);
  // URL pattern: /sitter-view/[token] or /s/[token]
  const token = pathParts[pathParts.length - 1];
  const wantsJson = url.searchParams.get("json") === "true" || req.headers.get("accept")?.includes("application/json");

  if (token === "test-token-123") {
    const mockDog = { 
      name: "Bella", 
      breed: "French Bulldog", 
      dob: "2019-01-01", 
      weight_lbs: 22, 
      photo_url: "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e", 
      bio: "Hi! I'm Bella - I'm very food motivated and love to play with my stuffed toys. I'm going to pull on my leash and stop on walks, but only because I'm crazy about squirrels." 
    };
    const mockLink = { mode: "daytime" };
    const mockCare = {
      behaviour: {
        fear_triggers: ["Loud noises"],
        separation_anxiety: "Mild",
        separation_anxiety_notes: "Leave the radio on",
        comfort_items: "Orange duck toy"
      }
    };
    if (wantsJson) {
      return new Response(JSON.stringify({ dog: mockDog, link: mockLink, careMap: mockCare }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(buildCareGuidePage(mockDog, mockLink, mockCare, token), { headers: { "Content-Type": "text/html; charset=utf-8" } });
  }

  if (!token) {
    return new Response(errorPage("No link token provided.", ""), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
      status: 400,
    });
  }

  // ── Handle visit log form submission ──
  if (req.method === "POST") {
    return handleVisitLog(req, token, url, corsHeaders);
  }

  const wantsHtml = req.headers.get("accept")?.includes("text/html");

  if (!wantsJson && wantsHtml) {
    const frontendBase = Deno.env.get("FRONTEND_URL") || "https://snoot-web-zeta.vercel.app";
    return Response.redirect(`${frontendBase}/${token}`, 302);
  }

  // ── Fetch sitter link ──
  const { data: link, error: linkErr } = await supabase
    .from("sitter_links")
    .select("id, dog_id, mode, active, expires_at")
    .eq("token", token)
    .single();

  if (linkErr || !link) {
    return new Response(wantsJson ? JSON.stringify({ error: "This link doesn't exist." }) : errorPage("This link doesn't exist.", ""), {
      headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/html; charset=utf-8" },
      status: 404,
    });
  }

  // ── Fetch dog separately ──
  const { data: dog } = await supabase
    .from("dogs")
    .select("id, name, breed, dob, weight_lbs, photo_url, bio")
    .eq("id", link.dog_id)
    .single();

  if (!dog) {
    return new Response(wantsJson ? JSON.stringify({ error: "Dog profile not found." }) : errorPage("Dog profile not found.", ""), {
      headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/html; charset=utf-8" },
      status: 404,
    });
  }

  if (!link.active) {
    return new Response(
      wantsJson ? JSON.stringify({ error: `${dog.name}'s care guide is no longer active.` }) : errorPage(
        `${dog.name}'s care guide is no longer active.`,
        "Ask the owner for a new link."
      ),
      { headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/html; charset=utf-8" }, status: 410 }
    );
  }

  if (link.expires_at && new Date(link.expires_at) < new Date()) {
    return new Response(
      wantsJson ? JSON.stringify({ error: `${dog.name}'s care guide has expired.` }) : errorPage(
        `${dog.name}'s care guide has expired.`,
        "Ask the owner for a new link."
      ),
      { headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/html; charset=utf-8" }, status: 410 }
    );
  }

  // ── Build care sections from care_profile rows ──
  const { data: careRows } = await supabase
    .from("care_profile")
    .select("section, data")
    .eq("dog_id", link.dog_id);

  const careMap: Record<string, Record<string, unknown>> = {};
  for (const cp of careRows ?? []) {
    careMap[cp.section] = cp.data ?? {};
  }

  if (wantsJson) {
    return new Response(JSON.stringify({ dog, link, careMap }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const html = buildCareGuidePage(dog, link, careMap, token);
  return new Response(html, {
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
});

// ── Visit log POST handler ──────────────────────────────────────
async function handleVisitLog(req: Request, token: string, url: URL, corsHeaders: any): Promise<Response> {
  const wantsJson = url.searchParams.get("json") === "true" || req.headers.get("accept")?.includes("application/json");
  const contentType = req.headers.get("content-type") || "";
  
  let sitterName, fed, walked, walkDuration, notes;
  
  if (contentType.includes("application/json")) {
    const json = await req.json();
    sitterName = json.sitter_name?.trim();
    fed = json.fed === true || json.fed === "true";
    walked = json.walked === true || json.walked === "true";
    walkDuration = walked ? parseInt(json.walk_duration) || null : null;
    notes = json.notes?.trim() ?? "";
  } else {
    const formData = await req.formData();
    sitterName = (formData.get("sitter_name") as string)?.trim();
    fed = formData.get("fed") === "true";
    walked = formData.get("walked") === "true";
    walkDuration = walked ? parseInt(formData.get("walk_duration") as string) || null : null;
    notes = (formData.get("notes") as string)?.trim() ?? "";
  }

  if (!sitterName) {
    return new Response(wantsJson ? JSON.stringify({ error: "Name is required" }) : "Name is required", { 
      status: 400,
      headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/plain" }
    });
  }

  const { data: link } = await supabase
    .from("sitter_links")
    .select("id, dog_id, active, expires_at")
    .eq("token", token)
    .single();

  if (!link?.active) {
    return new Response(wantsJson ? JSON.stringify({ error: "Link is no longer active" }) : "Link is no longer active", { 
      status: 410,
      headers: { ...corsHeaders, "Content-Type": wantsJson ? "application/json" : "text/plain" }
    });
  }

  await supabase.from("visit_logs").insert({
    dog_id: link.dog_id,
    sitter_link_id: link.id,
    logged_by_name: sitterName,
    fed,
    walked,
    walk_duration_mins: walkDuration,
    notes,
    visited_at: new Date().toISOString(),
  });

  const { data: dogRow } = await supabase
    .from("dogs")
    .select("name")
    .eq("id", link.dog_id)
    .single();
  const dogName = dogRow?.name ?? "your pup";
  
  if (wantsJson) {
    return new Response(JSON.stringify({ success: true, message: "Visit logged successfully." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  
  return new Response(confirmationPage(dogName, token), {
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
}

// ── HTML builders ───────────────────────────────────────────────
function buildCareGuidePage(
  dog: Record<string, unknown>,
  link: Record<string, unknown>,
  care: Record<string, Record<string, unknown>>,
  token: string
): string {
  const feeding = care["feeding"] ?? {};
  const walks = care["walks"] ?? {};
  const behaviour = care["behaviour"] ?? {};
  const health = care["health"] ?? {};
  const bedtime = care["bedtime"] ?? {};
  const mode = link.mode as string;
  const showOvernight = mode === "overnight" || mode === "both";

  const photoUrl = dog.photo_url as string | null;
  const photoHtml = photoUrl
    ? `<img src="${esc(photoUrl)}" alt="${esc(dog.name as string)}" class="dog-photo">`
    : `<div class="dog-photo-placeholder">&#x1F43E;</div>`;

  const mealTimes = (feeding.meal_times_data as string[] | undefined) ?? [];
  const walkTimes = (walks.walk_times_data as string[] | undefined) ?? [];
  const fearTriggers = (behaviour.fear_triggers as string[] | undefined) ?? [];
  const leashBehaviours = (walks.leash_behaviours as string[] | undefined) ?? [];
  const bedtimeRoutine = (bedtime.bedtime_routine as string[] | undefined) ?? [];
  const medications = (health.medications as Array<Record<string, string>> | undefined) ?? [];
  const foodAllergies = (feeding.food_allergies as string[] | undefined) ?? [];
  const personalityTags: string[] = [];

  const fmt = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  };

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${esc(dog.name as string)}'s Care Guide</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #fdf8f3;
      color: #503728;
      min-height: 100vh;
    }
    .container { max-width: 480px; margin: 0 auto; padding: 24px 16px 48px; }
    .hero {
      background: white;
      border-radius: 20px;
      padding: 24px;
      text-align: center;
      box-shadow: 0 2px 12px rgba(0,0,0,0.07);
      margin-bottom: 16px;
    }
    .dog-photo {
      width: 96px; height: 96px;
      border-radius: 50%;
      object-fit: cover;
      border: 3px solid rgba(244,132,95,0.3);
      margin-bottom: 12px;
    }
    .dog-photo-placeholder {
      width: 96px; height: 96px;
      border-radius: 50%;
      background: rgba(244,132,95,0.12);
      display: flex; align-items: center; justify-content: center;
      font-size: 36px;
      margin: 0 auto 12px;
    }
    .dog-name { font-size: 26px; font-weight: 700; color: #503728; }
    .dog-meta { font-size: 14px; color: #888; margin-top: 4px; }
    .mode-badge {
      display: inline-block;
      background: rgba(125,175,122,0.15);
      color: #7daf7a;
      font-size: 13px;
      font-weight: 600;
      padding: 4px 12px;
      border-radius: 20px;
      margin-top: 10px;
    }
    .tags {
      display: flex; flex-wrap: wrap; gap: 6px;
      justify-content: center; margin-top: 12px;
    }
    .tag {
      background: rgba(244,132,95,0.1);
      color: #f4845f;
      font-size: 12px; font-weight: 500;
      padding: 4px 10px; border-radius: 20px;
    }
    .section {
      background: white;
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
    }
    .section-header {
      display: flex; align-items: center; gap: 8px;
      margin-bottom: 12px;
    }
    .section-icon {
      width: 30px; height: 30px;
      border-radius: 50%;
      display: flex; align-items: center; justify-content: center;
      font-size: 14px;
    }
    .section-title { font-size: 16px; font-weight: 600; color: #503728; }
    .info-row { display: flex; gap: 8px; margin-bottom: 6px; }
    .info-label {
      font-size: 12px; font-weight: 600;
      color: #aaa; min-width: 90px;
    }
    .info-value { font-size: 14px; color: #503728; flex: 1; }
    .info-value.highlight { color: #c03313; }
    .divider { height: 1px; background: #f0ebe6; margin: 8px 0; }
    .visit-section {
      background: white;
      border-radius: 20px;
      padding: 24px;
      margin-top: 24px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.07);
    }
    .visit-title { font-size: 18px; font-weight: 700; margin-bottom: 4px; }
    .visit-subtitle { font-size: 14px; color: #888; margin-bottom: 20px; }
    .form-group { margin-bottom: 16px; }
    label { font-size: 14px; font-weight: 600; color: #503728; display: block; margin-bottom: 6px; }
    input[type=text], textarea {
      width: 100%; border: 1.5px solid #e8e0d8;
      border-radius: 10px; padding: 12px;
      font-size: 15px; font-family: inherit;
      color: #503728; background: #fdf8f3;
      outline: none;
    }
    input[type=text]:focus, textarea:focus { border-color: #f4845f; }
    textarea { resize: vertical; min-height: 80px; }
    .toggle-row {
      display: flex; justify-content: space-between;
      align-items: center; padding: 12px 0;
    }
    .toggle-row + .toggle-row { border-top: 1px solid #f0ebe6; }
    .toggle-label { font-size: 15px; font-weight: 500; }
    .toggle {
      position: relative; width: 48px; height: 28px;
      cursor: pointer;
    }
    .toggle input { opacity: 0; width: 0; height: 0; }
    .slider {
      position: absolute; inset: 0;
      background: #ddd; border-radius: 14px;
      transition: background 0.2s;
    }
    .slider:before {
      content: ''; position: absolute;
      width: 22px; height: 22px;
      left: 3px; top: 3px;
      background: white; border-radius: 50%;
      transition: transform 0.2s;
      box-shadow: 0 1px 4px rgba(0,0,0,0.2);
    }
    .toggle input:checked + .slider { background: #f4845f; }
    .toggle input:checked + .slider:before { transform: translateX(20px); }
    .duration-group { margin-top: 10px; display: none; }
    .duration-group.visible { display: block; }
    .duration-opts { display: flex; gap: 8px; flex-wrap: wrap; }
    .dur-btn {
      padding: 8px 16px; border-radius: 20px;
      border: 1.5px solid #e8e0d8; background: #fdf8f3;
      font-size: 14px; font-weight: 500; color: #503728;
      cursor: pointer; transition: all 0.15s;
    }
    .dur-btn.selected { background: #f4845f; color: white; border-color: #f4845f; }
    .submit-btn {
      width: 100%; padding: 16px;
      background: #f4845f; color: white;
      border: none; border-radius: 14px;
      font-size: 17px; font-weight: 600;
      cursor: pointer; margin-top: 8px;
      transition: opacity 0.2s;
    }
    .submit-btn:active { opacity: 0.8; }
    .powered {
      text-align: center; margin-top: 32px;
      font-size: 12px; color: #c0b8b0;
    }
    .powered a { color: #c0b8b0; text-decoration: none; }
  </style>
</head>
<body>
<div class="container">
  <!-- Hero -->
  <div class="hero">
    ${photoHtml}
    <div class="dog-name">${esc(dog.name as string)}'s Care Guide</div>
    <div class="dog-meta">${esc(dog.breed as string ?? "")}${dog.dob ? " · " + calcAge(dog.dob as string) : ""}</div>
    <div class="mode-badge">${mode === "both" ? "Daytime + Overnight" : mode === "overnight" ? "Overnight" : "Daytime"} care</div>
    ${personalityTags.length ? `<div class="tags">${personalityTags.slice(0, 5).map((t) => `<span class="tag">${esc(t)}</span>`).join("")}</div>` : ""}
    ${dog.bio ? `<p style="font-size:14px;color:#888;margin-top:12px;line-height:1.5">${esc(dog.bio as string)}</p>` : ""}
  </div>

  <!-- Feeding -->
  ${sectionHtml("&#x1F356;", "#f4845f", "Mealtime", `
    ${feeding.meals_per_day === 0
      ? `<div class="info-row"><div class="info-value">Free feed all day</div></div>`
      : `<div class="info-row"><div class="info-label">Meals/day</div><div class="info-value">${esc(String(feeding.meals_per_day ?? 0))}</div></div>
         ${mealTimes.map((t, i) => `<div class="info-row"><div class="info-label">Meal ${i + 1}</div><div class="info-value">${fmt(t)}</div></div>`).join("")}`
    }
    ${feeding.portion_size ? `<div class="info-row"><div class="info-label">Portion</div><div class="info-value">${esc(feeding.portion_size as string)} ${esc(feeding.portion_unit as string ?? "")}</div></div>` : ""}
    ${feeding.food_brand ? `<div class="info-row"><div class="info-label">Food</div><div class="info-value">${esc(feeding.food_brand as string)}</div></div>` : ""}
    ${foodAllergies.length ? `<div class="info-row"><div class="info-label">Avoid</div><div class="info-value highlight">${esc(foodAllergies.join(", "))}</div></div>` : ""}
    ${feeding.treats_policy ? `<div class="info-row"><div class="info-label">Treats</div><div class="info-value">${esc(feeding.treats_policy as string)}</div></div>` : ""}
  `)}

  <!-- Walks -->
  ${sectionHtml("&#x1F9AE;", "#7daf7a", "Walks", `
    <div class="info-row"><div class="info-label">Walks/day</div><div class="info-value">${esc(String(walks.walks_per_day ?? 0))}</div></div>
    ${walkTimes.map((t, i) => `<div class="info-row"><div class="info-label">Walk ${i + 1}</div><div class="info-value">${fmt(t)} · ${walks.walk_duration_minutes === 60 ? "1hr+" : (walks.walk_duration_minutes ?? "?") + " min"}</div></div>`).join("")}
    ${leashBehaviours.length ? `<div class="info-row"><div class="info-label">Leash</div><div class="info-value">${esc(leashBehaviours.join(", "))}</div></div>` : ""}
    <div class="info-row"><div class="info-label">Off-leash</div><div class="info-value">${walks.off_leash_trusted ? "Trusted ✓" : "Not trusted"}</div></div>
    ${walks.off_leash_notes ? `<div class="info-row"><div class="info-label"></div><div class="info-value">${esc(walks.off_leash_notes as string)}</div></div>` : ""}
  `)}

  <!-- Medications -->
  ${medications.length ? sectionHtml("&#x1F48A;", "#9b59b6", "Medications", medications.map((m) =>
    `<div style="margin-bottom:8px">
       <div style="font-size:14px;font-weight:600">${esc(m.name)}</div>
       <div style="font-size:13px;color:#888">${esc(m.dose)} · ${esc(m.timing)} · ${esc(m.method)}</div>
     </div>`
  ).join('<div class="divider"></div>')) : ""}

  <!-- Heads up -->
  ${(fearTriggers.length || (behaviour.separation_anxiety && behaviour.separation_anxiety !== "None" && behaviour.separation_anxiety !== "none"))
    ? sectionHtml("&#x26A0;&#xFE0F;", "#e67e22", "Heads up", `
      ${fearTriggers.length ? `<div class="info-row"><div className="info-label">Fears</div><div className="info-value highlight">${esc(fearTriggers.join(", "))}</div></div>` : ""}
      ${(behaviour.separation_anxiety && behaviour.separation_anxiety !== "None" && behaviour.separation_anxiety !== "none")
        ? `<div class="info-row"><div class="info-label">Separation</div><div class="info-value">${esc(behaviour.separation_anxiety as string)}</div></div>
           ${behaviour.separation_anxiety_notes ? `<div class="info-row"><div class="info-label">What helps</div><div class="info-value">${esc(behaviour.separation_anxiety_notes as string)}</div></div>` : ""}`
        : ""}
      ${behaviour.potty_signal ? `<div class="info-row"><div class="info-label">Potty signal</div><div class="info-value">${esc(behaviour.potty_signal as string)}</div></div>` : ""}
    `) : ""}

  <!-- Emergency contacts -->
  ${sectionHtml("&#x1F4DE;", "#e74c3c", "Emergency contacts", `
    ${health.emergency_contact ? `<div class="info-row"><div class="info-label">Owner</div><div class="info-value">${esc(health.emergency_contact as string)}</div></div>` : ""}
    ${(health.vet_name || health.vet_phone) ? `<div class="info-row"><div class="info-label">Vet</div><div class="info-value">${[health.vet_name, health.vet_clinic, health.vet_phone].filter(Boolean).map((v) => esc(v as string)).join(" · ")}</div></div>` : ""}
  `)}

  <!-- Overnight extras -->
  ${showOvernight && bedtime.sleep_location ? sectionHtml("&#x1F319;", "#7b68c8", "Bedtime", `
    <div class="info-row"><div class="info-label">Sleeps</div><div class="info-value">${esc(bedtime.sleep_location as string)}</div></div>
    ${bedtime.bedtime_date ? `<div class="info-row"><div class="info-label">Bedtime</div><div class="info-value">${fmt(bedtime.bedtime_date as string)}</div></div>` : ""}
    ${bedtimeRoutine.length ? `<div class="info-row"><div class="info-label">Routine</div><div class="info-value">${esc(bedtimeRoutine.join(", "))}</div></div>` : ""}
    ${bedtime.nighttime_quirks ? `<div class="info-row"><div class="info-label">Quirks</div><div class="info-value highlight">${esc(bedtime.nighttime_quirks as string)}</div></div>` : ""}
  `) : ""}

  <!-- Visit log form -->
  <div class="visit-section">
    <div class="visit-title">Log a visit</div>
    <div class="visit-subtitle">Let ${esc(dog.name as string)}'s owner know how it went</div>

    <form method="POST" id="visitForm">
      <input type="hidden" name="_method" value="POST">

      <div class="form-group">
        <label for="sitter_name">Your name</label>
        <input type="text" id="sitter_name" name="sitter_name" placeholder="e.g. Alex" required>
      </div>

      <div class="toggle-row">
        <span class="toggle-label">Did you feed ${esc(dog.name as string)}?</span>
        <label class="toggle">
          <input type="checkbox" name="fed" value="true" id="fedToggle" onchange="updateHidden('fed', this.checked)">
          <span class="slider"></span>
        </label>
      </div>
      <input type="hidden" name="fed" id="fedHidden" value="false">

      <div class="toggle-row">
        <span class="toggle-label">Did you walk ${esc(dog.name as string)}?</span>
        <label class="toggle">
          <input type="checkbox" name="walked" value="true" id="walkedToggle" onchange="toggleDuration(this.checked); updateHidden('walked', this.checked)">
          <span class="slider"></span>
        </label>
      </div>
      <input type="hidden" name="walked" id="walkedHidden" value="false">

      <div class="duration-group" id="durationGroup">
        <label>Walk duration</label>
        <div class="duration-opts">
          ${[15, 30, 45, 60].map((d) => `<button type="button" class="dur-btn" data-mins="${d}" onclick="selectDuration(${d})">${d === 60 ? "1hr+" : d + " min"}</button>`).join("")}
        </div>
        <input type="hidden" name="walk_duration" id="walkDurationInput" value="30">
      </div>

      <div class="form-group" style="margin-top:16px">
        <label for="notes">Notes <span style="font-weight:400;color:#aaa">(optional)</span></label>
        <textarea id="notes" name="notes" placeholder="Anything the owner should know?"></textarea>
      </div>

      <button type="submit" class="submit-btn">Submit visit</button>
    </form>
  </div>

  <div class="powered">Made with <a href="https://snoot.app">Snoot</a></div>
</div>

<script>
  function updateHidden(name, checked) {
    document.getElementById(name + 'Hidden').value = checked ? 'true' : 'false';
  }
  function toggleDuration(show) {
    document.getElementById('durationGroup').classList.toggle('visible', show);
  }
  var selectedDuration = 30;
  function selectDuration(mins) {
    selectedDuration = mins;
    document.getElementById('walkDurationInput').value = mins;
    document.querySelectorAll('.dur-btn').forEach(function(btn) {
      btn.classList.toggle('selected', parseInt(btn.dataset.mins) === mins);
    });
  }
  selectDuration(30);

  document.getElementById('visitForm').addEventListener('submit', function(e) {
    e.preventDefault();
    var btn = this.querySelector('.submit-btn');
    btn.textContent = 'Submitting…';
    btn.disabled = true;
    var data = new FormData(this);
    // Remove checkbox duplicates — keep hidden fields only
    data.delete('fed'); data.delete('walked');
    data.append('fed', document.getElementById('fedHidden').value);
    data.append('walked', document.getElementById('walkedHidden').value);
    fetch(window.location.href, { method: 'POST', body: data })
      .then(function(r) { return r.text(); })
      .then(function(html) { document.open(); document.write(html); document.close(); })
      .catch(function() { btn.textContent = 'Submit visit'; btn.disabled = false; });
  });
</script>
</body>
</html>`;
}

function sectionHtml(emoji: string, color: string, title: string, content: string): string {
  return `<div class="section">
    <div class="section-header">
      <div class="section-icon" style="background:${color}22">${emoji}</div>
      <div class="section-title">${title}</div>
    </div>
    ${content}
  </div>`;
}

function errorPage(heading: string, sub: string): string {
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Snoot</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #fdf8f3;
           display: flex; align-items: center; justify-content: center;
           min-height: 100vh; padding: 24px; }
    .card { background: white; border-radius: 20px; padding: 32px 24px;
            text-align: center; max-width: 360px; box-shadow: 0 2px 12px rgba(0,0,0,0.07); }
    .paw { font-size: 48px; margin-bottom: 16px; }
    h1 { font-size: 20px; color: #503728; margin-bottom: 8px; }
    p { font-size: 15px; color: #888; }
  </style>
</head>
<body>
  <div class="card">
    <div class="paw">&#x1F43E;</div>
    <h1>${esc(heading)}</h1>
    ${sub ? `<p>${esc(sub)}</p>` : ""}
  </div>
</body></html>`;
}

function confirmationPage(dogName: string, token: string): string {
  return `<!DOCTYPE html>
<html lang="en"><head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Visit logged!</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #fdf8f3;
           display: flex; align-items: center; justify-content: center;
           min-height: 100vh; padding: 24px; }
    .card { background: white; border-radius: 20px; padding: 32px 24px;
            text-align: center; max-width: 360px; box-shadow: 0 2px 12px rgba(0,0,0,0.07); }
    .emoji { font-size: 56px; margin-bottom: 16px; }
    h1 { font-size: 22px; color: #503728; margin-bottom: 8px; }
    p { font-size: 15px; color: #888; margin-bottom: 24px; }
    a { display: block; padding: 14px; background: #f4845f; color: white;
        border-radius: 12px; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="card">
    <div class="emoji">&#x1F436;</div>
    <h1>${esc(dogName)} is lucky to have you</h1>
    <p>Your visit has been logged and the owner has been notified.</p>
    <a href="https://jmwlizpemivsadimplsa.supabase.co/functions/v1/sitter-view/${esc(token)}">Back to care guide</a>
  </div>
</body></html>`;
}

function calcAge(dobIso: string): string {
  const dob = new Date(dobIso);
  const now = new Date();
  let years = now.getFullYear() - dob.getFullYear();
  let months = now.getMonth() - dob.getMonth();
  if (months < 0) { years--; months += 12; }
  if (years === 0) return `${months}mo`;
  if (months === 0) return `${years}yr`;
  return `${years}yr ${months}mo`;
}

function esc(s: string): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
    .replace(/&lt;br\s*\/?[^&]*&gt;/gi, "<br>")
    .replace(/\n/g, "<br>");
}
