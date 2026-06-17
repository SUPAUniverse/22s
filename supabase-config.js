/* twentytwo — Supabase front-end config
 * Both values below are PUBLIC (safe to ship). Row Level Security protects the data.
 */
window.SUPA_URL  = "https://rfdfiuzepxdrfldbbsbo.supabase.co";   // twentytwo Agency project
window.SUPA_ANON = "sb_publishable_Of7Fz-LcWZkf14fgxu6UMg_XhtqWumj";   // publishable (public) key — safe to ship

(function () {
  window.supaClient = null;
  if (window.SUPA_URL && window.SUPA_ANON && window.supabase && window.supabase.createClient) {
    try { window.supaClient = window.supabase.createClient(window.SUPA_URL, window.SUPA_ANON); }
    catch (e) { window.supaClient = null; }
  }
  window.supaReady = function () { return !!window.supaClient; };

  // ---- public forms ----
  window.supaWaitlist   = function (row)   { return window.supaClient.from('waitlist').insert(row); };
  window.supaNewsletter = function (email) { return window.supaClient.from('newsletter').insert({ email: email }); };
  window.supaBoard      = function ()      { return window.supaClient.from('rankings').select('*').order('passion_score', { ascending: false }); };

  // ---- auth (magic link / passwordless) ----
  window.supaAuth = {
    session:   async function () { return (await window.supaClient.auth.getSession()).data.session; },
    user:      async function () { return (await window.supaClient.auth.getUser()).data.user; },
    loginLink: function (email, data) {
      return window.supaClient.auth.signInWithOtp({
        email: email,
        options: { emailRedirectTo: window.location.origin + '/dashboard.html', data: data || {} }
      });
    },
    logout:    function () { return window.supaClient.auth.signOut(); }
  };

  // ---- brand domain logic ----
  window.supaDomainTaken  = function (domain) { return window.supaClient.rpc('domain_taken', { p_domain: domain }); };
  window.supaBrandRequest = function (row)    { return window.supaClient.from('brand_join_requests').insert(row); };

  // ---- profile tables (dashboard) ----
  window.supaMyCreator = async function () {
    var u = await window.supaAuth.user(); if (!u) return null;
    var r = await window.supaClient.from('creators').select('*').eq('user_id', u.id).maybeSingle();
    return r.data;
  };
  window.supaMyBrand = async function () {
    var u = await window.supaAuth.user(); if (!u) return null;
    var r = await window.supaClient.from('brands').select('*').eq('user_id', u.id).maybeSingle();
    return r.data;
  };
})();
