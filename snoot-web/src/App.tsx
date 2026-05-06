import React, { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';
import './index.css';

const supabase = createClient(
  'https://jmwlizpemivsadimplsa.supabase.co',
  'sb_publishable_F6P82ztNKJI8TErL565OgQ_tYK-cKcr'
);

interface DogData {
  name: string;
  breed?: string;
  dob?: string;
  weight_lbs?: number;
  photo_url?: string;
  bio?: string;
  personality_tags?: string[];
}

interface LinkData {
  mode: string;
  active: boolean;
}

interface CareMap {
  [key: string]: any;
}

interface SitterData {
  dog: DogData;
  link: LinkData;
  careMap: CareMap;
}

export default function App() {
  const [data, setData] = useState<SitterData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [isInvite, setIsInvite] = useState(false);
  const [passwordSet, setPasswordSet] = useState(false);

  // Visit log state
  const [sitterName, setSitterName] = useState('');
  const [fed, setFed] = useState(false);
  const [walked, setWalked] = useState(false);
  const [walkDuration, setWalkDuration] = useState(30);
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [password, setPassword] = useState('');
  const [updating, setUpdating] = useState(false);

  const urlParams = new URLSearchParams(window.location.search);
  const pathToken = window.location.pathname.replace(/^\/|\/$/g, '');
  const token = urlParams.get('token') || (pathToken ? pathToken : null);

  // Supabase Edge Function URL
  const apiUrl = `https://jmwlizpemivsadimplsa.supabase.co/functions/v1/sitter-view/${token}?json=true`;

  useEffect(() => {
    // Handle Supabase Auth (Invite/Confirmation)
    const hash = window.location.hash;
    if (hash && (hash.includes('access_token=') || hash.includes('type=invite') || hash.includes('type=recovery'))) {
      setIsInvite(true);
      setLoading(false);
      
      // Just track that we are in invite mode; the user will set password via form
      return;
    }

    if (!token) {
      setError('No link token provided.');
      setLoading(false);
      return;
    }

    fetch(apiUrl, {
      headers: {
        'Accept': 'application/json',
        'apikey': 'sb_publishable_F6P82ztNKJI8TErL565OgQ_tYK-cKcr'
      }
    })
      .then(res => res.json())
      .then(json => {
        if (json.error) {
          setError(json.error);
        } else {
          setData(json);
        }
      })
      .catch(err => {
        console.error(err);
        setError('Failed to load care guide. Please try again.');
      })
      .finally(() => setLoading(false));
  }, [token, apiUrl]);

  const handleLogVisit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!sitterName.trim()) return;

    setSubmitting(true);
    try {
      const res = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': 'sb_publishable_F6P82ztNKJI8TErL565OgQ_tYK-cKcr'
        },
        body: JSON.stringify({
          sitter_name: sitterName,
          fed,
          walked,
          walk_duration: walked ? walkDuration : null,
          notes
        })
      });

      const json = await res.json();
      if (json.error) {
        alert(json.error);
      } else {
        setSubmitted(true);
      }
    } catch (err) {
      alert('Failed to log visit. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const calcAge = (dobIso: string) => {
    const dob = new Date(dobIso);
    const now = new Date();
    let years = now.getFullYear() - dob.getFullYear();
    let months = now.getMonth() - dob.getMonth();
    if (months < 0) { years--; months += 12; }
    if (years === 0) return `${months}mo`;
    if (months === 0) return `${years}yr`;
    return `${years}yr ${months}mo`;
  };

  const fmtTime = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  };

  if (loading) {
    return <div className="loading-state">Loading care guide...</div>;
  }


  if (isInvite) {
    const handleSetPassword = async (e: React.FormEvent) => {
      e.preventDefault();
      if (password.length < 6) {
        alert('Password must be at least 6 characters.');
        return;
      }
      setUpdating(true);
      const { error } = await supabase.auth.updateUser({ password });
      if (error) {
        setUpdating(false);
        alert(error.message);
        return;
      }
      // Accept all pending family invites — the RPC matches on both user_id and
      // invited_email, so it works even if the invite was created before sign-up.
      await supabase.rpc('accept_pending_invites_for_me');
      setUpdating(false);
      setPasswordSet(true);
    };

    return (
      <div className="container">
        <div className="card text-center">
          <div className="paw-icon">👋</div>
          {passwordSet ? (
            <>
              <h1>You're all set!</h1>
              <p className="subtitle">Your account is confirmed and your family access is active.</p>
              <div className="mt-8 p-6 bg-orange-50 rounded-2xl border-2 border-orange-100">
                <p className="text-orange-900 font-bold mb-2">Next Step:</p>
                <p className="text-orange-800 text-sm leading-relaxed">
                  Open the <strong>Snoot app</strong> on your iPhone and sign in with your email to see your shared dog profiles.
                </p>
              </div>
            </>
          ) : (
            <>
              <h1>Welcome to the Family!</h1>
              <p className="subtitle">Set a password to access your shared dog profiles in the Snoot app.</p>
              
              <form onSubmit={handleSetPassword} className="mt-6 text-left">
                <div className="form-group">
                  <label htmlFor="password">Choose a password</label>
                  <input 
                    type="password" 
                    id="password" 
                    placeholder="Min 6 characters" 
                    required 
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </div>
                <button type="submit" className="btn-primary w-full mt-2" disabled={updating}>
                  {updating ? 'Setting password...' : 'Set password & finish'}
                </button>
              </form>
            </>
          )}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container">
        <div className="card text-center">
          <div className="paw-icon">🐾</div>
          <h1>{error}</h1>
        </div>
      </div>
    );
  }

  if (!data) return null;

  const { dog, link, careMap } = data;
  const { feeding = {}, walks = {}, behaviour = {}, health = {}, bedtime = {} } = careMap;

  const mode = link.mode;
  const showOvernight = mode === "overnight" || mode === "both";
  
  const mealTimes = feeding.meal_times_data || [];
  const walkTimes = walks.walk_times_data || [];
  const fearTriggers = behaviour.fear_triggers || [];
  const leashBehaviours = walks.leash_behaviours || [];
  const bedtimeRoutine = bedtime.bedtime_routine || [];
  const medications = health.medications || [];
  const foodAllergies = feeding.food_allergies || [];
  const personalityTags = (dog.personality_tags as string[] | undefined) ?? [];

  if (submitted) {
    return (
      <div className="container">
        <div className="card text-center">
          <div className="paw-icon">🐶</div>
          <h1>{dog.name} is lucky to have you</h1>
          <p className="subtitle">Your visit has been logged and the owner has been notified.</p>
          <button className="btn-primary" onClick={() => setSubmitted(false)}>Back to care guide</button>
        </div>
      </div>
    );
  }

  return (
    <div className="container">
      {/* Hero */}
      <div className="hero">
        {dog.photo_url ? (
          <img src={dog.photo_url} alt={dog.name} className="dog-photo" />
        ) : (
          <div className="dog-photo-placeholder">🐾</div>
        )}
        <h1 className="dog-name">{dog.name}'s Care Guide</h1>
        <div className="dog-meta">
          {dog.breed || ''}{dog.dob ? ` · ${calcAge(dog.dob)}` : ''}
        </div>
        <div className="mode-badge">
          {mode === "both" ? "Daytime + Overnight" : mode === "overnight" ? "Overnight" : "Daytime"} care
        </div>
        
        {personalityTags.length > 0 && (
          <div className="tags">
            {personalityTags.slice(0, 5).map((t, i) => (
              <span key={i} className="tag">{t}</span>
            ))}
          </div>
        )}
        
        {dog.bio && <p className="dog-bio">{dog.bio}</p>}
      </div>

      {/* Feeding */}
      <div className="section">
        <div className="section-header">
          <div className="section-icon icon-orange">🍖</div>
          <h2 className="section-title">Mealtime</h2>
        </div>
        
        {feeding.meals_per_day === 0 ? (
          <div className="info-row"><div className="info-value">Free feed all day</div></div>
        ) : (
          <>
            <div className="info-row"><div className="info-label">Meals/day</div><div className="info-value">{feeding.meals_per_day || 0}</div></div>
            {mealTimes.map((t: string, i: number) => (
              <div key={i} className="info-row"><div className="info-label">Meal {i + 1}</div><div className="info-value">{fmtTime(t)}</div></div>
            ))}
          </>
        )}
        
        {feeding.portion_size && <div className="info-row"><div className="info-label">Portion</div><div className="info-value">{feeding.portion_size} {feeding.portion_unit || ''}</div></div>}
        {feeding.food_brand && <div className="info-row"><div className="info-label">Food</div><div className="info-value">{feeding.food_brand}</div></div>}
        {foodAllergies.length > 0 && <div className="info-row"><div className="info-label">Avoid</div><div className="info-value highlight">{foodAllergies.join(", ")}</div></div>}
        {feeding.treats_policy && <div className="info-row"><div className="info-label">Treats</div><div className="info-value">{feeding.treats_policy}</div></div>}
      </div>

      {/* Walks */}
      <div className="section">
        <div className="section-header">
          <div className="section-icon icon-green">🦮</div>
          <h2 className="section-title">Walks</h2>
        </div>
        
        <div className="info-row"><div className="info-label">Walks/day</div><div className="info-value">{walks.walks_per_day || 0}</div></div>
        {walkTimes.map((t: string, i: number) => (
          <div key={i} className="info-row">
            <div className="info-label">Walk {i + 1}</div>
            <div className="info-value">{fmtTime(t)} · {walks.walk_duration_minutes === 60 ? "1hr+" : (walks.walk_duration_minutes || "?") + " min"}</div>
          </div>
        ))}
        {leashBehaviours.length > 0 && <div className="info-row"><div className="info-label">Leash</div><div className="info-value">{leashBehaviours.join(", ")}</div></div>}
        <div className="info-row"><div className="info-label">Off-leash</div><div className="info-value">{walks.off_leash_trusted ? "Trusted ✓" : "Not trusted"}</div></div>
        {walks.off_leash_notes && <div className="info-row"><div className="info-label"></div><div className="info-value">{walks.off_leash_notes}</div></div>}
      </div>

      {/* Medications */}
      {medications.length > 0 && (
        <div className="section">
          <div className="section-header">
            <div className="section-icon icon-purple">💊</div>
            <h2 className="section-title">Medications</h2>
          </div>
          {medications.map((m: any, i: number) => (
            <div key={i} className={i > 0 ? "med-item med-divider" : "med-item"}>
              <div className="med-name">{m.name}</div>
              <div className="med-details">{m.dose} · {m.timing} · {m.method}</div>
            </div>
          ))}
        </div>
      )}

      {/* Heads up */}
      {(fearTriggers.length > 0 || (behaviour.separation_anxiety && behaviour.separation_anxiety !== "None" && behaviour.separation_anxiety !== "none") || behaviour.separation_anxiety_notes || behaviour.potty_signal) && (
        <div className="section">
          <div className="section-header">
            <div className="section-icon icon-yellow">⚠️</div>
            <h2 className="section-title">Heads up</h2>
          </div>
          {fearTriggers.length > 0 && <div className="info-row"><div className="info-label">Fears</div><div className="info-value highlight">{fearTriggers.join(", ")}</div></div>}
          {((behaviour.separation_anxiety && behaviour.separation_anxiety !== "None" && behaviour.separation_anxiety !== "none") || behaviour.separation_anxiety_notes) && (
            <>
              <div className="info-row"><div className="info-label">Separation</div><div className="info-value">{behaviour.separation_anxiety}</div></div>
              {behaviour.separation_anxiety_notes && <div className="info-row"><div className="info-label">What helps</div><div className="info-value">{behaviour.separation_anxiety_notes}</div></div>}
            </>
          )}
          {behaviour.potty_signal && <div className="info-row"><div className="info-label">Potty signal</div><div className="info-value">{behaviour.potty_signal}</div></div>}
        </div>
      )}

      {/* Emergency contacts */}
      <div className="section">
        <div className="section-header">
          <div className="section-icon icon-red">📞</div>
          <h2 className="section-title">Emergency contacts</h2>
        </div>
        {health.emergency_contact && <div className="info-row"><div className="info-label">Owner</div><div className="info-value">{health.emergency_contact}</div></div>}
        {(health.vet_name || health.vet_phone) && (
          <div className="info-row">
            <div className="info-label">Vet</div>
            <div className="info-value">
              {[health.vet_name, health.vet_clinic, health.vet_phone].filter(Boolean).join(" · ")}
            </div>
          </div>
        )}
      </div>

      {/* Overnight extras */}
      {showOvernight && bedtime.sleep_location && (
        <div className="section">
          <div className="section-header">
            <div className="section-icon icon-indigo">🌙</div>
            <h2 className="section-title">Bedtime</h2>
          </div>
          <div className="info-row"><div className="info-label">Sleeps</div><div className="info-value">{bedtime.sleep_location}</div></div>
          {bedtime.bedtime_date && <div className="info-row"><div className="info-label">Bedtime</div><div className="info-value">{fmtTime(bedtime.bedtime_date)}</div></div>}
          {bedtimeRoutine.length > 0 && <div className="info-row"><div className="info-label">Routine</div><div className="info-value">{bedtimeRoutine.join(", ")}</div></div>}
          {bedtime.nighttime_quirks && <div className="info-row"><div className="info-label">Quirks</div><div className="info-value highlight">{bedtime.nighttime_quirks}</div></div>}
        </div>
      )}

      {/* Visit log form */}
      <div className="visit-section">
        <h2 className="visit-title">Log a visit</h2>
        <p className="visit-subtitle">Please fill this out at the end of your visit or overnight stay.</p>

        <form onSubmit={handleLogVisit}>
          <div className="form-group">
            <label htmlFor="sitter_name">Your name</label>
            <input 
              type="text" 
              id="sitter_name" 
              placeholder="e.g. Alex" 
              required 
              value={sitterName}
              onChange={(e) => setSitterName(e.target.value)}
            />
          </div>

          <div className="toggle-row">
            <span className="toggle-label">Did you feed {dog.name} their scheduled meals?</span>
            <label className="toggle">
              <input type="checkbox" checked={fed} onChange={(e) => setFed(e.target.checked)} />
              <span className="slider"></span>
            </label>
          </div>

          <div className="toggle-row">
            <span className="toggle-label">Did you take {dog.name} on their scheduled walks?</span>
            <label className="toggle">
              <input type="checkbox" checked={walked} onChange={(e) => setWalked(e.target.checked)} />
              <span className="slider"></span>
            </label>
          </div>

          {walked && (
            <div className="duration-group slide-down">
              <label>Walk duration</label>
              <div className="duration-opts">
                {[15, 30, 45, 60].map(d => (
                  <button 
                    key={d}
                    type="button" 
                    className={`dur-btn ${walkDuration === d ? 'selected' : ''}`}
                    onClick={() => setWalkDuration(d)}
                  >
                    {d === 60 ? "1hr+" : d + " min"}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="form-group mt-4">
            <label htmlFor="notes">Notes <span className="font-normal text-gray">(optional)</span></label>
            <textarea 
              id="notes" 
              placeholder="Anything the owner should know?"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <button type="submit" className="btn-primary mt-2" disabled={submitting}>
            {submitting ? 'Submitting…' : 'Submit visit'}
          </button>
        </form>
      </div>

      <div className="powered">
        Made with <a href="https://snoot.app">Snoot</a>
      </div>
    </div>
  );
}
