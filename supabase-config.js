/* 22s — Supabase front-end config
 * Paste your project's two PUBLIC values below (Supabase dashboard → Settings → API).
 * Both are safe to ship in client-side code — Row Level Security protects your data.
 * Until these are filled in, the forms fall back to email/sample mode automatically.
 */
window.SUPA_URL  = "https://rfdfiuzepxdrfldbbsbo.supabase.co";   // 22s Agency project
window.SUPA_ANON = "sb_publishable_Of7Fz-LcWZkf14fgxu6UMg_XhtqWumj";   // publishable (public) key — safe to ship

(function () {
  window.supaClient = null;
  if (window.SUPA_URL && window.SUPA_ANON && window.supabase && window.supabase.createClient) {
    try { window.supaClient = window.supabase.createClient(window.SUPA_URL, window.SUPA_ANON); }
    catch (e) { window.supaClient = null; }
  }
  window.supaReady = function () { return !!window.supaClient; };

  // Insert a waitlist application
  window.supaWaitlist = function (row) {
    return window.supaClient.from('waitlist').insert(row);
  };
  // Subscribe to the newsletter (ignore duplicate-email errors)
  window.supaNewsletter = function (email) {
    return window.supaClient.from('newsletter').insert({ email: email });
  };
  // Load the live ranking board (highest Passion Score first)
  window.supaBoard = function () {
    return window.supaClient.from('rankings').select('*').order('passion_score', { ascending: false });
  };
})();
