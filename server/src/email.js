// Resend transactional email.
//
// MAIL_FROM starts as Resend's shared test sender (onboarding@resend.dev), which
// works with no DNS at all, and becomes no-reply@nellab.org once the domain is
// verified. Nothing else changes when it does — it is one var in wrangler.toml.

const RESEND_URL = 'https://api.resend.com/emails';

// Wording per purpose. A deletion code must never read like a routine
// login code: someone receiving one unexpectedly needs to understand
// immediately that an account is about to be destroyed.
const COPY = {
  claim: {
    subject: (code, app) => `${code} is your ${app} verification code`,
    lead: "Here is your verification code.",
    tail: "If you did not request this, you can ignore this email — nobody can access your account without the code.",
  },
  delete: {
    subject: (code, app) => `${code} — confirm deleting your ${app} account`,
    lead: "Use this code to permanently delete your account.",
    tail: "This will erase your profile, statistics, teams and friends, and it cannot be undone. If you did not ask to delete your account, ignore this email and change your password — nothing happens without the code.",
  },
};

function template(code, minutes, appName, purpose) {
  const spaced = code.split('').join(' ');
  const copy = COPY[purpose] || COPY.claim;
  return `<!doctype html>
<html><body style="margin:0;padding:0;background:#0C0F0A;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:#0C0F0A;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
             style="max-width:440px;background:#161A14;border:1px solid #252B21;border-radius:14px;">
        <tr><td style="padding:28px 28px 8px;">
          <div style="font-family:'Barlow Condensed',Arial,sans-serif;font-size:26px;
                      font-weight:800;letter-spacing:1px;color:#D4FF00;">${appName}</div>
        </td></tr>
        <tr><td style="padding:0 28px;">
          <p style="font-family:Barlow,Arial,sans-serif;font-size:15px;line-height:1.6;color:#F1F4F2;margin:12px 0 4px;">
            ${copy.lead}
          </p>
          <p style="font-family:Barlow,Arial,sans-serif;font-size:13px;line-height:1.6;color:#8B948F;margin:0 0 20px;">
            It expires in ${minutes} minutes and can be used once.
          </p>
        </td></tr>
        <tr><td style="padding:0 28px 8px;">
          <div style="background:#0C0F0A;border:1px solid #39412F;border-radius:10px;
                      padding:18px;text-align:center;font-family:'Courier New',monospace;
                      font-size:30px;font-weight:700;letter-spacing:8px;color:#D4FF00;">
            ${spaced}
          </div>
        </td></tr>
        <tr><td style="padding:16px 28px 28px;">
          <p style="font-family:Barlow,Arial,sans-serif;font-size:12px;line-height:1.6;color:#8B948F;margin:0;">
            ${copy.tail}
          </p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

export async function sendOtpEmail(env, to, code, minutes, purpose = 'claim') {
  const key = env.RESEND_API_KEY;
  if (!key) throw new Error('RESEND_API_KEY is not set');
  const appName = env.APP_NAME || 'YNO';
  const copy = COPY[purpose] || COPY.claim;
  const res = await fetch(RESEND_URL, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${key}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      from: env.MAIL_FROM || 'YNO <onboarding@resend.dev>',
      to: [to],
      subject: copy.subject(code, appName),
      html: template(code, minutes, appName, purpose),
      text: `${copy.lead} ${code}. ` +
            `It expires in ${minutes} minutes and can be used once.`,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`resend failed: ${res.status} ${body}`);
  }
  return res.json();
}
